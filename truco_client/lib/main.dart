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

  Widget buildWidget() {
    return Container(
      width: 80,
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black54,
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
          '${value}${suit}',
          style: const TextStyle(
            fontSize: 32,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class GameState extends ChangeNotifier {
  bool isConnected = false;
  bool isWaiting = true;
  bool isMyTurn = false;
  String? myId;
  List<PlayingCard> myCards = [];
  Map<String, PlayingCard> playedCards = {};
  Map<String, PlayingCard> previousRoundCards = {};
  Map<String, int> scores = {};
  Map<String, int> roundWins = {};

  // Truco state
  bool isTrucoRequested = false;
  String? trucoRequestedBy;
  int currentHandValue = 1;
  bool canRequestTruco = true;

  void resetTrucoState() {
    isTrucoRequested = false;
    trucoRequestedBy = null;
    currentHandValue = 1;
    canRequestTruco = true;
    notifyListeners();
  }

  late IO.Socket socket;

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
        playedCards = {};
        previousRoundCards = {};

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
      print('Card played: $data');
      playedCards[data['playerId']] = PlayingCard.fromJson(data['card']);
      notifyListeners();
    });

    socket.on('roundResult', (data) {
      print('Round result: $data');
      roundWins = Map<String, int>.from(data['roundWins']);
      _handleRoundEnd();
    });

    socket.on('handComplete', (data) {
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

    socket.on('trucoRequested', (data) {
      isTrucoRequested = true;
      trucoRequestedBy = data['requestedBy'];
      canRequestTruco = false;
      notifyListeners();
    });

    socket.on('trucoAccepted', (data) {
      isTrucoRequested = false;
      currentHandValue = data['value'];
      canRequestTruco = true;
      notifyListeners();
    });

    socket.on('trucoRaised', (data) {
      isTrucoRequested = true;
      trucoRequestedBy = data['raisedBy'];
      canRequestTruco = false;
      notifyListeners();
    });

    socket.on('trucoQuit', (data) {
      isTrucoRequested = false;
      scores = Map<String, int>.from(data['scores']);
      canRequestTruco = true;
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
      previousRoundCards = Map.from(playedCards);
      playedCards = {};
      notifyListeners();
    }
  }

  String getScoreText() {
    if (scores.isEmpty) return '';
    return 'Placar: Você ${scores[myId] ?? 0} x ${scores.entries.firstWhere((entry) => entry.key != myId).value} Oponente';
  }

  String getRoundWinsText() {
    if (roundWins.isEmpty) return '';
    return 'Rodadas: Você ${roundWins[myId] ?? 0} x ${roundWins.entries.firstWhere((entry) => entry.key != myId).value} Oponente';
  }

  void requestTruco() {
    if (!canRequestTruco || !isMyTurn) return;
    socket.emit('requestTruco');
  }

  void respondTruco(String response) {
    if (!isTrucoRequested) return;
    socket.emit('respondTruco', response);
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
        mainAxisAlignment: MainAxisAlignment.center,
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

          const SizedBox(height: 20),

          // Mesa de jogo (área das cartas jogadas)
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cartas da rodada anterior (mais escuras)
                ...gameState.previousRoundCards.entries.map((entry) {
                  final isMyCard = entry.key == gameState.myId;
                  return Positioned(
                    top: isMyCard ? 100 : 50,
                    left: isMyCard ? 
                      MediaQuery.of(context).size.width / 2 - 40 : 
                      MediaQuery.of(context).size.width / 2 - 120,
                    child: Transform.rotate(
                      angle: isMyCard ? -0.2 : 0.2,
                      child: Opacity(
                        opacity: 0.5,
                        child: entry.value.buildWidget(),
                      ),
                    ),
                  );
                }),

                // Cartas da rodada atual
                ...gameState.playedCards.entries.map((entry) {
                  final isMyCard = entry.key == gameState.myId;
                  return Positioned(
                    top: isMyCard ? 80 : 30,
                    left: isMyCard ? 
                      MediaQuery.of(context).size.width / 2 : 
                      MediaQuery.of(context).size.width / 2 - 80,
                    child: Transform.rotate(
                      angle: isMyCard ? -0.3 : 0.3,
                      child: entry.value.buildWidget(),
                    ),
                  ).animate()
                   .scale(
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                   )
                   .slideY(
                    begin: isMyCard ? 1 : -1,
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                   );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Game info area
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Pontos: ${gameState.scores[gameState.myId] ?? 0} x '
                   '${gameState.scores.values.firstWhere((score) => score != gameState.scores[gameState.myId], orElse: () => 0)}'),
              const SizedBox(width: 20),
              if (gameState.currentHandValue > 1)
                Text('Valor da mão: ${gameState.currentHandValue}'),
            ],
          ),

          // Truco request area
          if (gameState.isTrucoRequested && gameState.trucoRequestedBy != gameState.myId)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Truco! Valor: ${gameState.currentHandValue == 1 ? 3 : 
                                    gameState.currentHandValue == 3 ? 6 :
                                    gameState.currentHandValue == 6 ? 9 : 12}'),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => gameState.respondTruco('accept'),
                  child: const Text('Aceitar'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => gameState.respondTruco('raise'),
                  child: const Text('Aumentar'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => gameState.respondTruco('quit'),
                  child: const Text('Correr'),
                ),
              ],
            ),

          // Player cards area - Implementa um efeito de leque 3D para as cartas na mão
          // As cartas são dispostas em um arco com rotação suave e perspectiva
          // para simular como as cartas aparecem quando seguradas por um jogador
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...gameState.myCards.asMap().entries.map((entry) {
                final index = entry.key;
                final card = entry.value;
                // Calcula o centro do leque para distribuir as rotações uniformemente
                final centerIndex = (gameState.myCards.length - 1) / 2;
                // Define o ângulo de rotação baseado na distância do centro
                final angle = (index - centerIndex) * 0.1; // 0.1 rad ≈ 5.7 graus

                return Transform(
                  // Configuração da matriz de transformação 3D
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Adiciona perspectiva sutil
                    ..rotateX(-0.3) // Inclina as cartas para frente (~17 graus)
                    ..rotateZ(angle), // Aplica a rotação em leque
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: gameState.isMyTurn ? () => gameState.playCard(card) : null,
                      child: card.buildWidget(),
                    ),
                  ),
                );
              }),
              
              // Botão de TRUCO animado com ícone de fogo
              // Aparece apenas quando é permitido pedir truco
              if (gameState.isMyTurn && gameState.canRequestTruco && !gameState.isTrucoRequested)
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: ElevatedButton.icon(
                    onPressed: gameState.requestTruco,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.local_fire_department, size: 24),
                    label: const Text(
                      'TRUCO!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).animate()
                    .shimmer(duration: 1000.ms, delay: 500.ms) // Efeito de brilho
                    .shake(duration: 500.ms, curve: Curves.easeInOut), // Efeito de tremor
                ),
            ],
          ),
        ],
      ),
    );
  }
}
