import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => GameState(),
      child: const TrucoApp(),
    ),
  );
}

class PlayingCard {
  final String suit;
  final String value;

  PlayingCard({required this.suit, required this.value});

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      suit: json['suit'],
      value: json['value'],
    );
  }
}

class GameState extends ChangeNotifier {
  bool isConnected = false;
  bool isMyTurn = false;
  List<PlayingCard> cards = [];
  late IO.Socket socket;
  bool isWaiting = false;
  Map<String, PlayingCard> playedCards = {};
  String? myId;
  Map<String, int> scores = {};
  Map<String, int> roundWins = {};
  String? roundWinner;
  String? handWinner;

  void connect() {
    socket = IO.io('http://localhost:3001', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();
    
    socket.onConnect((_) {
      print('Connected to server');
      isConnected = true;
      myId = socket.id;
      socket.emit('joinGame');
      notifyListeners();
    });

    socket.on('waitingForPlayer', (_) {
      isWaiting = true;
      notifyListeners();
    });

    socket.on('gameStart', (data) {
      isWaiting = false;
      isMyTurn = data['firstTurn'] == socket.id;
      playedCards.clear();
      roundWinner = null;
      handWinner = null;
      notifyListeners();
    });

    socket.on('dealCards', (data) {
      cards = (data['cards'] as List)
          .map((card) => PlayingCard.fromJson(card))
          .toList();
      notifyListeners();
    });

    socket.on('changeTurn', (data) {
      isMyTurn = data['nextPlayer'] == socket.id;
      notifyListeners();
    });

    socket.on('cardPlayed', (data) {
      playedCards[data['playerId']] = PlayingCard.fromJson(data['card']);
      notifyListeners();
    });

    socket.on('roundResult', (data) {
      roundWinner = data['winner'];
      roundWins = Map<String, int>.from(data['roundWins']);
      notifyListeners();
    });

    socket.on('handComplete', (data) {
      handWinner = data['winner'];
      scores = Map<String, int>.from(data['scores']);
      notifyListeners();
    });

    socket.on('playerLeft', (_) {
      isConnected = false;
      isMyTurn = false;
      cards.clear();
      playedCards.clear();
      scores.clear();
      roundWins.clear();
      notifyListeners();
    });
  }

  void playCard(PlayingCard card) {
    if (!isMyTurn) return;
    
    socket.emit('playCard', {
      'card': {'suit': card.suit, 'value': card.value}
    });
    
    cards.removeWhere((c) => c.suit == card.suit && c.value == card.value);
    notifyListeners();
  }

  String getScoreText() {
    if (scores.isEmpty) return '';
    return 'Placar: Você ${scores[myId] ?? 0} x ${scores.entries.firstWhere((entry) => entry.key != myId).value} Oponente';
  }

  String getRoundWinsText() {
    if (roundWins.isEmpty) return '';
    return 'Rodadas: Você ${roundWins[myId] ?? 0} x ${roundWins.entries.firstWhere((entry) => entry.key != myId).value} Oponente';
  }
}

class TrucoApp extends StatelessWidget {
  const TrucoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Truco Game',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truco Game'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
                Provider.of<GameState>(context, listen: false).connect();
              },
              child: const Text('Conectar ao Jogo'),
            ),
          ],
        ),
      ),
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truco - Em Jogo'),
      ),
      body: Consumer<GameState>(
        builder: (context, gameState, child) {
          if (gameState.isWaiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Aguardando outro jogador...'),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Score display
                Column(
                  children: [
                    Text(
                      gameState.getScoreText(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      gameState.getRoundWinsText(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),

                // Round winner display
                if (gameState.roundWinner != null)
                  Text(
                    gameState.roundWinner == gameState.myId
                        ? 'Você venceu a rodada!'
                        : 'Oponente venceu a rodada!',
                    style: const TextStyle(fontSize: 18, color: Colors.green),
                  ),

                // Hand winner display
                if (gameState.handWinner != null)
                  Text(
                    gameState.handWinner == gameState.myId
                        ? 'Você venceu a mão!'
                        : 'Oponente venceu a mão!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),

                // Opponent's played card
                SizedBox(
                  height: 120,
                  child: Center(
                    child: gameState.playedCards.entries
                        .where((entry) => entry.key != gameState.myId)
                        .isEmpty
                            ? const Card(
                                child: SizedBox(
                                  width: 70,
                                  height: 100,
                                  child: Center(
                                    child: Text('Aguardando...'),
                                  ),
                                ),
                              )
                            : Card(
                                child: SizedBox(
                                  width: 70,
                                  height: 100,
                                  child: Center(
                                    child: Text(
                                      '${gameState.playedCards.entries.firstWhere((entry) => entry.key != gameState.myId).value.value}'
                                      '${gameState.playedCards.entries.firstWhere((entry) => entry.key != gameState.myId).value.suit}',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ),

                // Turn indicator
                Text(
                  gameState.isMyTurn ? 'Seu turno!' : 'Turno do oponente',
                  style: const TextStyle(fontSize: 24),
                ),

                // Player's played card
                SizedBox(
                  height: 120,
                  child: Center(
                    child: gameState.playedCards[gameState.myId] == null
                        ? const Card(
                            child: SizedBox(
                              width: 70,
                              height: 100,
                              child: Center(
                                child: Text('Sua jogada'),
                              ),
                            ),
                          )
                        : Card(
                            child: SizedBox(
                              width: 70,
                              height: 100,
                              child: Center(
                                child: Text(
                                  '${gameState.playedCards[gameState.myId]!.value}'
                                  '${gameState.playedCards[gameState.myId]!.suit}',
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                // Player's hand
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: gameState.cards.isEmpty
                      ? [
                          for (int i = 0; i < 3; i++)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Card(
                                child: SizedBox(
                                  width: 70,
                                  height: 100,
                                  child: Center(child: Text('🂠')),
                                ),
                              ),
                            ),
                        ]
                      : gameState.cards.map((card) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: GestureDetector(
                              onTap: gameState.isMyTurn
                                  ? () => gameState.playCard(card)
                                  : null,
                              child: Card(
                                child: SizedBox(
                                  width: 70,
                                  height: 100,
                                  child: Center(
                                    child: Text(
                                      '${card.value}${card.suit}',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
