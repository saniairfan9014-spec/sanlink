import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/game_service.dart';

class _SnakeC {
  static const primary = Color(0xFF00FF88);
  static const primaryGlow = Color(0x6600FF88);
  static const accent = Color(0xFF00D1FF);
  static const accentGlow = Color(0x6600D1FF);
  static const bg = Color(0xFF020617);
  static const surface = Color(0xFF0F172A);
  static const glass = Color(0x0DFFFFFF);
  static const border = Color(0x1AFFFFFF);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
}

class SnakeGameScreen extends StatefulWidget {
  final int difficultySpeed;
  final String difficultyName;

  const SnakeGameScreen({
    super.key,
    required this.difficultySpeed,
    required this.difficultyName,
  });

  @override
  State<SnakeGameScreen> createState() => _SnakeGameScreenState();
}

class _SnakeGameScreenState extends State<SnakeGameScreen> with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  static const int rowCount = 20;
  static const int colCount = 20;

  List<Point<int>> snake = [const Point(10, 10), const Point(10, 11)];
  Point<int> food = const Point(5, 5);
  String direction = 'up';
  Timer? timer;
  int score = 0;
  bool isPlaying = false;
  String currentFoodEmoji = '🍎';

  final List<String> foodEmojis = ['🍎', '🍓', '🍇', '🍒', '🍉', '🍕', '🍔', '🍦'];

  late AnimationController _foodPulseCtrl;
  late Animation<double> _foodPulse;

  @override
  void initState() {
    super.initState();
    _foodPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _foodPulse = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _foodPulseCtrl, curve: Curves.easeInOut),
    );
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      snake = [const Point(10, 10), const Point(10, 11), const Point(10, 12)];
      food = generateFood();
      direction = 'up';
      score = 0;
      isPlaying = false;
      currentFoodEmoji = foodEmojis[Random().nextInt(foodEmojis.length)];
    });
    timer?.cancel();
  }

  void startGame() {
    if (isPlaying) return;
    HapticFeedback.mediumImpact();
    setState(() {
      isPlaying = true;
    });
    timer = Timer.periodic(Duration(milliseconds: widget.difficultySpeed), (_) {
      setState(moveSnake);
    });
  }

  void moveSnake() {
    if (!isPlaying) return;

    Point<int> newHead = getNextHead();

    // Collision check
    if (newHead.x < 0 ||
        newHead.y < 0 ||
        newHead.x >= colCount ||
        newHead.y >= rowCount ||
        snake.contains(newHead)) {
      timer?.cancel();
      isPlaying = false;
      HapticFeedback.vibrate();
      
      final isWin = score >= 15;
      _gameService.addGameResult('snake', isWin, score: score, difficulty: widget.difficultyName);
      
      showGameOverDialog();
      return;
    }

    snake.insert(0, newHead);

    if (newHead == food) {
      score++;
      HapticFeedback.lightImpact();
      food = generateFood();
      currentFoodEmoji = foodEmojis[Random().nextInt(foodEmojis.length)];
    } else {
      snake.removeLast();
    }
  }

  Point<int> getNextHead() {
    Point<int> current = snake.first;
    switch (direction) {
      case 'up': return Point(current.x, current.y - 1);
      case 'down': return Point(current.x, current.y + 1);
      case 'left': return Point(current.x - 1, current.y);
      case 'right': return Point(current.x + 1, current.y);
      default: return current;
    }
  }

  Point<int> generateFood() {
    Random rnd = Random();
    Point<int> newFood;
    do {
      newFood = Point(rnd.nextInt(colCount), rnd.nextInt(rowCount));
    } while (snake.contains(newFood));
    return newFood;
  }

  void showGameOverDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Game Over",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: AlertDialog(
            backgroundColor: _SnakeC.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: const BorderSide(color: _SnakeC.primary, width: 2),
            ),
            title: const Text(
              "GAME OVER",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _SnakeC.primary,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                letterSpacing: 4,
                shadows: [Shadow(color: _SnakeC.primaryGlow, blurRadius: 10)],
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 80),
                const SizedBox(height: 16),
                Text(
                  "SCORE: $score",
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Difficulty: ${widget.difficultyName}",
                  style: const TextStyle(color: _SnakeC.textSecondary, fontSize: 16),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("EXIT", style: TextStyle(color: _SnakeC.textSecondary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetGame();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _SnakeC.primary,
                  foregroundColor: _SnakeC.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: _SnakeC.primaryGlow,
                ),
                child: const Text("RETRY", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      },
    );
  }

  void changeDirection(String newDirection) {
    if ((direction == 'up' && newDirection == 'down') ||
        (direction == 'down' && newDirection == 'up') ||
        (direction == 'left' && newDirection == 'right') ||
        (direction == 'right' && newDirection == 'left')) return;

    direction = newDirection;
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SnakeC.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.difficultyName.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [_SnakeC.surface, _SnakeC.bg],
          ),
        ),
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.delta.dy > 5 && direction != 'up') changeDirection('down');
            else if (details.delta.dy < -5 && direction != 'down') changeDirection('up');
          },
          onHorizontalDragUpdate: (details) {
            if (details.delta.dx > 5 && direction != 'left') changeDirection('right');
            else if (details.delta.dx < -5 && direction != 'right') changeDirection('left');
          },
          child: Column(
            children: [
              const SizedBox(height: 110),
              
              // SHINING SCOREBOARD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _SnakeC.glass,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _SnakeC.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: -5),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildScoreItem("POINTS", score.toString(), _SnakeC.primary),
                      Container(width: 1, height: 40, color: _SnakeC.border, margin: const EdgeInsets.symmetric(horizontal: 20)),
                      _buildScoreItem("LENGTH", snake.length.toString(), _SnakeC.accent),
                      const Spacer(),
                      Icon(Icons.emoji_events_rounded, color: Colors.amber.withOpacity(0.8), size: 32),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // NEON GAME GRID
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _SnakeC.primary.withOpacity(0.3), width: 2),
                          boxShadow: [
                            BoxShadow(color: _SnakeC.primaryGlow.withOpacity(0.1), blurRadius: 40, spreadRadius: 5),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Grid Lines (Subtle)
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: colCount),
                              itemCount: rowCount * colCount,
                              itemBuilder: (context, index) => Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.02), width: 0.5)),
                              ),
                            ),
                            
                            // Game Elements
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: colCount),
                              itemCount: rowCount * colCount,
                              itemBuilder: (context, index) {
                                int x = index % colCount;
                                int y = index ~/ colCount;
                                Point<int> point = Point(x, y);

                                bool isHead = snake.isNotEmpty && snake.first == point;
                                bool isBody = snake.contains(point) && !isHead;
                                bool isFood = point == food;

                                if (isFood) {
                                  return Center(
                                    child: ScaleTransition(
                                      scale: _foodPulse,
                                      child: Text(currentFoodEmoji, style: const TextStyle(fontSize: 18)),
                                    ),
                                  );
                                }

                                if (isHead) {
                                  return _buildSnakeHead();
                                }

                                if (isBody) {
                                  return _buildSnakeBody(point);
                                }

                                return const SizedBox();
                              },
                            ),

                            if (!isPlaying)
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                                    child: ElevatedButton(
                                      onPressed: startGame,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _SnakeC.primary,
                                        foregroundColor: _SnakeC.bg,
                                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        elevation: 20,
                                        shadowColor: _SnakeC.primaryGlow,
                                      ),
                                      child: const Text(
                                        "START ARENA",
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // SWIPE HINT
              Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _SnakeC.glass,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe_rounded, color: _SnakeC.primary, size: 18),
                      SizedBox(width: 10),
                      Text(
                        "SWIPE TO NAVIGATE",
                        style: TextStyle(color: _SnakeC.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnakeHead() {
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_SnakeC.primary, _SnakeC.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: _SnakeC.primaryGlow, blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Stack(
        children: [
          // Eyes
          if (direction == 'up' || direction == 'down')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildEye(),
                _buildEye(),
              ],
            )
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildEye(),
                _buildEye(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEye() {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }

  Widget _buildSnakeBody(Point<int> point) {
    int index = snake.indexOf(point);
    double opacity = 1.0 - (index / snake.length * 0.7);
    
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _SnakeC.primary.withOpacity(opacity),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          if (index < 5) BoxShadow(color: _SnakeC.primaryGlow.withOpacity(0.2), blurRadius: 4),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _SnakeC.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold, shadows: [
            Shadow(color: color.withOpacity(0.5), blurRadius: 10),
          ]),
        ),
      ],
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _foodPulseCtrl.dispose();
    super.dispose();
  }
}