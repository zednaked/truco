import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'theme.dart';

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
  List<PlayingCard> myCards = [];
  late IO.Socket socket;
  bool isWaiting = true; // Começa aguardando
  Map<String, PlayingCard> playedCards = {};
  List<Map<String, PlayingCard>> previousRoundCards = []; // Cartas das rodadas anteriores
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

    socket.on('connect', (_) {
      print('Connected to server');
      isConnected = true;
      myId = socket.id;
      isWaiting = true; // Garante que está aguardando após conectar
      socket.emit('joinGame');
      notifyListeners();
    });

    socket.on('waitingForPlayer', (_) {
      print('Waiting for other player...');
      isWaiting = true;
      notifyListeners();
    });

    socket.on('gameStart', (data) {
      print('Game starting with data: $data');
      isWaiting = false;
      myId = socket.id;
      isMyTurn = data['firstPlayer'] == socket.id;
      
      try {
        myCards = (data['cards'] as List)
            .map((card) => PlayingCard(
                  suit: card['suit'],
                  value: card['value'],
                ))
            .toList();
        
        scores = Map<String, int>.from(data['scores'] ?? {});
        roundWins = Map<String, int>.from(data['roundWins'] ?? {});
        playedCards.clear();
        previousRoundCards.clear();
        
        print('Game started. Is my turn? $isMyTurn');
        print('My ID: $myId');
        print('First player: ${data['firstPlayer']}');
        print('My cards: $myCards');
      } catch (e) {
        print('Error processing game start data: $e');
        print('Raw data received: $data');
      }
      
      notifyListeners();
    });

    socket.on('error', (data) {
      print('Socket error: $data');
      isWaiting = true;
      notifyListeners();
    });

    socket.on('disconnect', (_) {
      print('Disconnected from server');
      isConnected = false;
      isWaiting = true;
      notifyListeners();
    });

    socket.on('changeTurn', (data) {
      isMyTurn = data['currentPlayer'] == socket.id;
      print('Turn changed. Is my turn? $isMyTurn');
      print('Current player: ${data['currentPlayer']}');
      print('My ID: $myId');
      notifyListeners();
    });

    socket.on('cardPlayed', (data) {
      playedCards[data['playerId']] = PlayingCard.fromJson(data['card']);
      notifyListeners();
    });

    socket.on('roundResult', (data) {
      roundWinner = data['winner'];
      roundWins = Map<String, int>.from(data['roundWins']);
      _handleRoundEnd();
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
      myCards.clear();
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
    
    myCards.removeWhere((c) => c.suit == card.suit && c.value == card.value);
    notifyListeners();
  }

  void _handleRoundEnd() {
    if (playedCards.isNotEmpty) {
      previousRoundCards.add(Map.from(playedCards));
      playedCards.clear();
    }
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
      theme: TrucoTheme.theme,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TrucoTheme.backgroundColor,
              TrucoTheme.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'TRUCO',
                    textStyle: Theme.of(context).textTheme.displayLarge!.copyWith(
                      fontSize: 48,
                      color: TrucoTheme.secondaryColor,
                    ),
                    speed: const Duration(milliseconds: 200),
                  ),
                ],
                totalRepeatCount: 1,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  context.read<GameState>().connect();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GameScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TrucoTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: TrucoTheme.secondaryColor, width: 2),
                  ),
                ),
                child: Text(
                  'JOGAR',
                  style: Theme.of(context).textTheme.displayMedium,
                ).animate()
                  .scale(duration: 200.ms)
                  .then()
                  .shimmer(duration: 1000.ms, delay: 200.ms),
              ),
            ],
          ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TrucoTheme.backgroundColor,
              TrucoTheme.primaryColor,
            ],
          ),
        ),
        child: !context.watch<GameState>().isConnected
            ? const Center(child: CircularProgressIndicator())
            : context.watch<GameState>().isWaiting
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        DefaultTextStyle(
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                          child: AnimatedTextKit(
                            animatedTexts: [
                              WavyAnimatedText(
                                'Aguardando outro jogador...',
                                speed: const Duration(milliseconds: 100),
                              ),
                            ],
                            isRepeatingAnimation: true,
                          ),
                        ),
                      ],
                    ),
                  )
                : GameTable(gameState: context.watch<GameState>()),
      ),
    );
  }
}

class GameTable extends StatelessWidget {
  final GameState gameState;

  const GameTable({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Score display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TrucoTheme.primaryColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: TrucoTheme.secondaryColor, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  gameState.getScoreText(),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  gameState.getRoundWinsText(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),

          // Game messages
          if (gameState.roundWinner != null || gameState.handWinner != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: TrucoTheme.primaryColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TrucoTheme.secondaryColor),
              ),
              child: Column(
                children: [
                  if (gameState.roundWinner != null)
                    Text(
                      gameState.roundWinner == gameState.myId
                          ? 'Você venceu a rodada!'
                          : 'Oponente venceu a rodada!',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: TrucoTheme.secondaryColor,
                      ),
                    ).animate().fadeIn(duration: 300.ms).scale().then().shimmer(),
                  if (gameState.handWinner != null)
                    Text(
                      gameState.handWinner == gameState.myId
                          ? 'Você venceu a mão!'
                          : 'Oponente venceu a mão!',
                      style: Theme.of(context).textTheme.displayMedium!.copyWith(
                        color: TrucoTheme.secondaryColor,
                      ),
                    ).animate().fadeIn(duration: 500.ms).scale().then().shimmer(),
                ],
              ),
            ),

          // Game table
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TrucoTheme.primaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous rounds' cards
                  if (gameState.previousRoundCards.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: gameState.previousRoundCards.map((roundCards) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              // Opponent's card
                              Container(
                                width: 60,
                                height: 90,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black26,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${roundCards.entries.firstWhere((entry) => entry.key != gameState.myId).value.value}'
                                    '${roundCards.entries.firstWhere((entry) => entry.key != gameState.myId).value.suit}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.black38,
                                    ),
                                  ),
                                ),
                              ),
                              // Player's card
                              Container(
                                width: 60,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black26,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${roundCards[gameState.myId]!.value}'
                                    '${roundCards[gameState.myId]!.suit}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.black38,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  // Current round cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Opponent's played card
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: Center(
                          child: gameState.playedCards.entries
                                  .any((entry) => entry.key != gameState.myId)
                              ? Container(
                                  width: 80,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: TrucoTheme.secondaryColor,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${gameState.playedCards.entries.firstWhere((entry) => entry.key != gameState.myId).value.value}'
                                      '${gameState.playedCards.entries.firstWhere((entry) => entry.key != gameState.myId).value.suit}',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ).animate()
                                  .scale(duration: 300.ms)
                                  .then()
                                  .shake(duration: 200.ms)
                              : const SizedBox(),
                        ),
                      ),

                      // Player's played card
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: Center(
                          child: gameState.playedCards.containsKey(gameState.myId)
                              ? Container(
                                  width: 80,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: TrucoTheme.secondaryColor,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${gameState.playedCards[gameState.myId]!.value}'
                                      '${gameState.playedCards[gameState.myId]!.suit}',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ).animate()
                                  .scale(duration: 300.ms)
                                  .then()
                                  .shake(duration: 200.ms)
                              : const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Player's hand
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: TrucoTheme.primaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: gameState.myCards.map((card) {
                final bool canPlay = gameState.isMyTurn && 
                    !gameState.playedCards.containsKey(gameState.myId);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: canPlay
                        ? () => gameState.playCard(card)
                        : null,
                    child: Container(
                      width: 80,
                      height: 120,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: canPlay
                              ? TrucoTheme.secondaryColor
                              : Colors.black54,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${card.value}${card.suit}',
                          style: TextStyle(
                            fontSize: 32,
                            color: canPlay
                                ? Colors.black
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
