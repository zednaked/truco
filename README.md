# Truco Game

A simple multiplayer Truco card game implementation using Flutter for the frontend and Node.js for the backend.

## Project Structure

- `truco_client/` - Flutter frontend application
- `truco_server/` - Node.js backend server

## Getting Started

### Running the Server

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

The server will start on port 3001.

### Running the Client

1. Navigate to the client directory:
```bash
cd truco_client
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run -d chrome
```

## Current Features

- Real-time multiplayer gameplay
- WebSocket communication
- Turn-based card playing
- Basic game state management
- Player connection handling
- Waiting room for players

## Game Rules

1. Two players can connect to a game
2. Each player receives 3 cards
3. Players take turns playing cards
4. Basic turn management implemented

## Technical Stack

- Frontend: Flutter (Web)
- Backend: Node.js
- Real-time Communication: Socket.IO
- State Management: Provider
