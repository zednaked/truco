const express = require('express');
const app = express();
const http = require('http').createServer(app);
const io = require('socket.io')(http, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const PORT = 3001;

// Game room state
class Room {
    constructor() {
        this.players = [];
        this.deck = [];
        this.scores = {};
        this.roundWins = {};
        this.playedCards = {};
        this.currentRound = 1;
        this.currentHandValue = 1; // Valor atual da mão (1, 3, 6, 9, 12)
        this.trucoState = {
            isActive: false,
            lastValue: 0,
            waitingResponse: false,
            requestedBy: null
        };
    }

    resetRound() {
        this.playedCards = {};
        this.currentRound = 1;
        this.currentHandValue = 1;
        this.trucoState = {
            isActive: false,
            lastValue: 0,
            waitingResponse: false,
            requestedBy: null
        };
    }
}

// Card values for comparison (Truco order)
const cardValues = {
    '3': 10,
    '2': 9,
    'A': 8,
    'K': 7,
    'J': 6,
    'Q': 5,
    '7': 4,
    '6': 3,
    '5': 2,
    '4': 1
};

// Card deck
const createDeck = () => {
    const suits = ['♠', '♥', '♣', '♦'];
    const values = ['4', '5', '6', '7', 'Q', 'J', 'K', 'A', '2', '3'];
    let deck = [];
    
    for (let suit of suits) {
        for (let value of values) {
            deck.push({ suit, value });
        }
    }
    
    return shuffle(deck);
};

// Fisher-Yates shuffle
const shuffle = (array) => {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [array[i], array[j]] = [array[j], array[i]];
    }
    return array;
};

// Compare cards to determine winner
const compareCards = (card1, card2) => {
    return cardValues[card1.value] - cardValues[card2.value];
};

let rooms = {};

io.on('connection', (socket) => {
    console.log('User connected:', socket.id);

    // Handle player joining
    socket.on('joinGame', () => {
        let roomId = null;
        
        // Find an available room or create new one
        for (let id in rooms) {
            if (rooms[id].players.length === 1) {
                roomId = id;
                break;
            }
        }

        if (!roomId) {
            roomId = Date.now().toString();
            rooms[roomId] = new Room();
        }

        // Add player to room
        rooms[roomId].players.push({
            id: socket.id,
            cards: []
        });
        rooms[roomId].scores[socket.id] = 0;
        rooms[roomId].roundWins[socket.id] = 0;

        socket.join(roomId);
        socket.roomId = roomId;

        // If room is full, start the game
        if (rooms[roomId].players.length === 2) {
            startNewRound(roomId);
        } else {
            socket.emit('waitingForPlayer');
        }
    });

    // Handle card played
    socket.on('playCard', (data) => {
        const room = rooms[socket.roomId];
        if (!room) return;

        const playerIndex = room.players.findIndex(p => p.id === socket.id);
        const nextPlayerIndex = (playerIndex + 1) % 2;

        // Store played card
        room.playedCards[socket.id] = data.card;

        // Remove played card from player's hand
        const playerCards = room.players[playerIndex].cards;
        const cardIndex = playerCards.findIndex(card => 
            card.suit === data.card.suit && card.value === data.card.value
        );
        
        if (cardIndex !== -1) {
            playerCards.splice(cardIndex, 1);
        }

        // Broadcast the played card to both players
        io.to(socket.roomId).emit('cardPlayed', {
            playerId: socket.id,
            card: data.card
        });

        // If both players have played their cards, determine round winner
        if (Object.keys(room.playedCards).length === 2) {
            const player1 = room.players[0].id;
            const player2 = room.players[1].id;
            const card1 = room.playedCards[player1];
            const card2 = room.playedCards[player2];

            const comparison = compareCards(card1, card2);
            const roundWinner = comparison > 0 ? player1 : player2;

            // Update round wins
            room.roundWins[roundWinner]++;

            // Clear cards for next round
            room.playedCards = {};

            // Emit round result
            io.to(socket.roomId).emit('roundResult', {
                winner: roundWinner,
                roundWins: room.roundWins
            });

            // Check if all cards have been played
            if (room.players[0].cards.length === 0) {
                // Determine hand winner
                const handWinner = room.roundWins[player1] > room.roundWins[player2] ? player1 : player2;
                room.scores[handWinner]++;

                // Emit hand result
                io.to(socket.roomId).emit('handComplete', {
                    winner: handWinner,
                    scores: room.scores
                });

                // Start new round after a delay
                setTimeout(() => startNewRound(socket.roomId), 2000);
            } else {
                // Continue with next turn
                io.to(socket.roomId).emit('changeTurn', {
                    currentPlayer: room.players[nextPlayerIndex].id
                });
            }
        } else {
            // Continue with next turn
            io.to(socket.roomId).emit('changeTurn', {
                currentPlayer: room.players[nextPlayerIndex].id
            });
        }
    });

    // Handle truco request
    socket.on('requestTruco', () => {
        const room = rooms[socket.roomId];
        if (!room || room.trucoState.waitingResponse) return;

        const nextValue = room.trucoState.lastValue === 0 ? 3 : 
                         room.trucoState.lastValue === 3 ? 6 :
                         room.trucoState.lastValue === 6 ? 9 :
                         room.trucoState.lastValue === 9 ? 12 : 0;

        if (nextValue === 0) return; // Valor máximo já atingido

        room.trucoState = {
            isActive: true,
            lastValue: room.trucoState.lastValue,
            waitingResponse: true,
            requestedBy: socket.id
        };

        // Notifica todos na sala sobre o pedido de truco
        io.to(socket.roomId).emit('trucoRequested', {
            requestedBy: socket.id,
            value: nextValue
        });
    });

    // Handle truco response
    socket.on('respondTruco', (response) => {
        const room = rooms[socket.roomId];
        if (!room || !room.trucoState.waitingResponse) return;

        room.trucoState.waitingResponse = false;

        if (response === 'accept') {
            // Aceita o truco
            const newValue = room.trucoState.lastValue === 0 ? 3 : 
                           room.trucoState.lastValue === 3 ? 6 :
                           room.trucoState.lastValue === 6 ? 9 :
                           room.trucoState.lastValue === 9 ? 12 : 12;
            
            room.currentHandValue = newValue;
            room.trucoState.lastValue = newValue;

            io.to(socket.roomId).emit('trucoAccepted', {
                value: newValue
            });
        } 
        else if (response === 'raise') {
            // Aumenta o valor
            const nextValue = room.trucoState.lastValue === 3 ? 6 :
                            room.trucoState.lastValue === 6 ? 9 :
                            room.trucoState.lastValue === 9 ? 12 : 0;

            if (nextValue === 0) return; // Não pode aumentar mais

            room.trucoState = {
                isActive: true,
                lastValue: room.trucoState.lastValue,
                waitingResponse: true,
                requestedBy: socket.id
            };

            io.to(socket.roomId).emit('trucoRaised', {
                raisedBy: socket.id,
                value: nextValue
            });
        }
        else if (response === 'quit') {
            // Foge do truco
            const points = room.trucoState.lastValue === 0 ? 1 :
                         room.trucoState.lastValue === 3 ? 3 :
                         room.trucoState.lastValue === 6 ? 6 :
                         room.trucoState.lastValue === 9 ? 9 : 1;

            // Dá os pontos para quem pediu
            room.scores[room.trucoState.requestedBy] = 
                (room.scores[room.trucoState.requestedBy] || 0) + points;

            io.to(socket.roomId).emit('trucoQuit', {
                quitBy: socket.id,
                points: points,
                scores: room.scores
            });

            // Inicia nova rodada
            startNewRound(socket.roomId);
        }
    });

    // Handle disconnection
    socket.on('disconnect', () => {
        if (socket.roomId && rooms[socket.roomId]) {
            io.to(socket.roomId).emit('playerLeft');
            delete rooms[socket.roomId];
        }
    });
});

function startNewRound(roomId) {
    const room = rooms[roomId];
    if (!room) return;

    room.resetRound();
    room.deck = createDeck();
    
    // Deal 3 cards to each player
    room.players.forEach(player => {
        player.cards = room.deck.splice(0, 3);
    });

    // Notify players with all necessary data
    room.players.forEach(player => {
        io.to(player.id).emit('gameStart', {
            firstPlayer: room.players[0].id,
            cards: player.cards,
            scores: room.scores,
            roundWins: room.roundWins
        });
    });
}

http.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
