# Truco Multiplayer Game

A real-time multiplayer implementation of the classic Truco card game using Flutter for the web client and Node.js for the server.

## Features

- Real-time two-player gameplay
- Complete round mechanics with scoring system
- Turn-based card playing
- Automatic round and hand winner determination
- Live game state synchronization
- Responsive web interface

## Game Rules

1. Each player receives 3 cards per hand
2. Players take turns playing one card at a time
3. Card ranking (from highest to lowest):
   - 3
   - 2
   - A (Ace)
   - K (King)
   - J (Jack)
   - Q (Queen)
   - 7
   - 6
   - 5
   - 4

4. Round Winner:
   - The player who plays the highest card wins the round
   - First to win 2 rounds wins the hand
   - Winning a hand awards 1 point

## Project Structure

```
truco-nov/
├── truco_client/         # Flutter web client
│   ├── lib/
│   │   └── main.dart     # Client implementation
│   └── pubspec.yaml      # Flutter dependencies
└── truco_server/
    └── server.js         # Node.js server implementation
```

## Setup Instructions

### Server Setup
1. Navigate to the server directory:
   ```bash
   cd truco_server
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the server:
   ```bash
   node server.js
   ```
   The server will run on port 3001.

### Client Setup
1. Navigate to the client directory:
   ```bash
   cd truco_client
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Run the web client:
   ```bash
   flutter run -d chrome
   ```

## Technical Details

### Server (Node.js)
- Built with Express and Socket.IO
- Handles game state management
- Implements card dealing and comparison logic
- Manages room-based multiplayer system
- Tracks scores and round wins

### Client (Flutter Web)
- Real-time WebSocket communication
- State management using Provider
- Responsive game UI
- Score and round tracking display
- Turn-based interaction system

## Dependencies

### Server
- express: ^4.18.2
- socket.io: ^4.7.2
- cors: ^2.8.5

### Client
- socket_io_client: ^2.0.3+1
- provider: ^6.1.1

## Game Flow

1. Player connects to server
2. Waits for second player
3. Game starts automatically when two players join
4. Each player receives 3 cards
5. Players take turns playing cards
6. Round winner is determined after both players play
7. Hand winner is determined after all cards are played
8. New hand starts automatically
9. Score is updated for the winner
