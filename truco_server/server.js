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

// Card deck
const createDeck = () => {
    const suits = ['♠', '♥', '♣', '♦'];
    const values = ['A', '2', '3', '4', '5', '6', '7', 'J', 'Q', 'K'];
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
                gameStarted: false
            };
        }

        // Add player to room
        rooms[roomId].players.push({
            id: socket.id,
            cards: []
        });

        socket.join(roomId);
        socket.roomId = roomId;

        // If room is full, start the game
        if (rooms[roomId].players.length === 2) {
            rooms[roomId].gameStarted = true;
            
            // Deal 3 cards to each player
            rooms[roomId].players.forEach(player => {
                player.cards = rooms[roomId].deck.splice(0, 3);
            });

            // Notify players
            io.to(roomId).emit('gameStart', {
                firstTurn: rooms[roomId].players[0].id
            });

            // Send cards to each player
            rooms[roomId].players.forEach(player => {
                io.to(player.id).emit('dealCards', {
                    cards: player.cards
                });
            });
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

        // Change turn
        io.to(socket.roomId).emit('changeTurn', {
            nextPlayer: room.players[nextPlayerIndex].id
        });
    });

    // Handle disconnection
    socket.on('disconnect', () => {
        if (socket.roomId && rooms[socket.roomId]) {
            io.to(socket.roomId).emit('playerLeft');
            delete rooms[socket.roomId];
        }
    });
});

http.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
