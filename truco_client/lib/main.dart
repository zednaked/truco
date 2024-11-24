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
                ).animate()
                  .scale(duration: 200.ms)
                  .then()
                  .shimmer(duration: 1000.ms, delay: 200.ms),
                child: Text(
                  'JOGAR',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
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
              TrucoTheme.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Consumer<GameState>(
          builder: (context, gameState, child) {
            if (gameState.isWaiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: TrucoTheme.secondaryColor,
                    ).animate()
                      .scale(duration: 500.ms)
                      .then()
                      .fadeOut(duration: 500.ms)
                      .then()
                      .fadeIn(duration: 500.ms)
                      .repeat(),
                    const SizedBox(height: 20),
                    Text(
                      'Aguardando outro jogador...',
                      style: Theme.of(context).textTheme.displayMedium,
                    ).animate()
                      .fadeIn(duration: 500.ms)
                      .then()
                      .shimmer(duration: 1000.ms)
                      .repeat(),
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
                  ).animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.2, end: 0),

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
                            ).animate()
                              .fadeIn(duration: 300.ms)
                              .scale()
                              .then()
                              .shimmer(),
                          if (gameState.handWinner != null)
                            Text(
                              gameState.handWinner == gameState.myId
                                  ? 'Você venceu a mão!'
                                  : 'Oponente venceu a mão!',
                              style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                color: TrucoTheme.secondaryColor,
                              ),
                            ).animate()
                              .fadeIn(duration: 500.ms)
                              .scale()
                              .then()
                              .shimmer(),
                        ],
                      ),
                    ),

                  // Game table
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: GameStyles.cardTableDecoration,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Opponent's played card
                          SizedBox(
                            height: 120,
                            child: Center(
                              child: gameState.playedCards.entries
                                  .where((entry) => entry.key != gameState.myId)
                                  .isEmpty
                                      ? Container(
                                          decoration: GameStyles.playedCardDecoration,
                                          width: 70,
                                          height: 100,
                                          child: const Center(
                                            child: Text('🂠', style: TextStyle(fontSize: 40)),
                                          ),
                                        )
                                      : Container(
                                          decoration: GameStyles.playedCardDecoration,
                                          width: 70,
                                          height: 100,
                                          child: Center(
                                            child: Text(
                                              '${gameState.playedCards.entries.firstWhere((entry) => entry.key != gameState.myId).value.value}'
                                              '${gameState.playedCards.entries.firstWhere((entry) => entry.key != gameState.myId).value.suit}',
                                              style: const TextStyle(fontSize: 32),
                                            ),
                                          ),
                                        ).animate()
                                          .scale(duration: 300.ms)
                                          .then()
                                          .shake(duration: 200.ms),
                            ),
                          ),

                          // Turn indicator
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: TrucoTheme.backgroundColor.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              gameState.isMyTurn ? 'Seu turno!' : 'Turno do oponente',
                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                color: gameState.isMyTurn ? TrucoTheme.secondaryColor : Colors.white,
                              ),
                            ),
                          ).animate(target: gameState.isMyTurn ? 1 : 0)
                            .scale(duration: 300.ms)
                            .then()
                            .shimmer(duration: 1000.ms)
                            .repeat(),

                          // Player's played card
                          SizedBox(
                            height: 120,
                            child: Center(
                              child: gameState.playedCards[gameState.myId] == null
                                  ? Container(
                                      decoration: GameStyles.playedCardDecoration,
                                      width: 70,
                                      height: 100,
                                      child: const Center(
                                        child: Text('🂠', style: TextStyle(fontSize: 40)),
                                      ),
                                    )
                                  : Container(
                                      decoration: GameStyles.playedCardDecoration,
                                      width: 70,
                                      height: 100,
                                      child: Center(
                                        child: Text(
                                          '${gameState.playedCards[gameState.myId]!.value}'
                                          '${gameState.playedCards[gameState.myId]!.suit}',
                                          style: const TextStyle(fontSize: 32),
                                        ),
                                      ),
                                    ).animate()
                                      .scale(duration: 300.ms)
                                      .then()
                                      .shake(duration: 200.ms),
                            ),
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
                      children: gameState.cards.isEmpty
                          ? [
                              for (int i = 0; i < 3; i++)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    decoration: GameStyles.playedCardDecoration,
                                    width: 70,
                                    height: 100,
                                    child: const Center(
                                      child: Text('🂠', style: TextStyle(fontSize: 40)),
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
                                  child: Container(
                                    decoration: GameStyles.playedCardDecoration.copyWith(
                                      color: gameState.isMyTurn
                                          ? TrucoTheme.cardColor
                                          : TrucoTheme.cardColor.withOpacity(0.7),
                                    ),
                                    width: 70,
                                    height: 100,
                                    child: Center(
                                      child: Text(
                                        '${card.value}${card.suit}',
                                        style: TextStyle(
                                          fontSize: 32,
                                          color: gameState.isMyTurn
                                              ? Colors.black
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ).animate()
                                  .scale(duration: 300.ms)
                                  .then()
                                  .shimmer(
                                    duration: 1000.ms,
                                    enabled: gameState.isMyTurn,
                                  ),
                              );
                            }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
