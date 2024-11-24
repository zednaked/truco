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

// Game state
let rooms = {};

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
            rooms[roomId] = {
                players: [],
                deck: createDeck(),
                currentTurn: 0,
                gameStarted: false,
                roundNumber: 1,
                cardsInRound: {},
                scores: {},
                roundWins: {}
            };
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
        room.cardsInRound[socket.id] = data.card;

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
        if (Object.keys(room.cardsInRound).length === 2) {
            const player1 = room.players[0].id;
            const player2 = room.players[1].id;
            const card1 = room.cardsInRound[player1];
            const card2 = room.cardsInRound[player2];

            const comparison = compareCards(card1, card2);
            const roundWinner = comparison > 0 ? player1 : player2;

            // Update round wins
            room.roundWins[roundWinner]++;

            // Clear cards for next round
            room.cardsInRound = {};

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

    room.gameStarted = true;
    room.deck = createDeck();
    room.roundNumber++;
    room.cardsInRound = {};
    room.roundWins = {
        [room.players[0].id]: 0,
        [room.players[1].id]: 0
    };
    
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
