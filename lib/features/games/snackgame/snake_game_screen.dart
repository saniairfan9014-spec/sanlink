import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

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

class _SnakeGameScreenState extends State<SnakeGameScreen> {
  static const int rowCount = 20;
  static const int colCount = 20;

  List<Point<int>> snake = [const Point(10, 10)];
  Point<int> food = const Point(5, 5);
  String direction = 'up';
  Timer? timer;
  int score = 0;
  bool isPlaying = false;
  String currentFoodEmoji = '🍎';

  final List<String> foodEmojis = ['🍎', '🍌', '🍇', '🍓', '🍑', '🍒', '🍕', '🍔', '🍩', '🍪'];

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      snake = [const Point(10, 10)];
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
      showGameOverDialog();
      return;
    }

    snake.insert(0, newHead);

    if (newHead == food) {
      score++;
      food = generateFood();
      currentFoodEmoji = foodEmojis[Random().nextInt(foodEmojis.length)];
    } else {
      snake.removeLast();
    }
  }

  Point<int> getNextHead() {
    Point<int> current = snake.first;
    switch (direction) {
      case 'up':
        return Point(current.x, current.y - 1);
      case 'down':
        return Point(current.x, current.y + 1);
      case 'left':
        return Point(current.x - 1, current.y);
      case 'right':
        return Point(current.x + 1, current.y);
      default:
        return current;
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
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: anim1,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: const Text(
              "GAME OVER",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 64),
                const SizedBox(height: 16),
                Text(
                  "Score: $score",
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Level: ${widget.difficultyName}",
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to category screen
                },
                child: const Text("EXIT", style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetGame();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("RETRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          "Snake: ${widget.difficultyName}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0 && direction != 'up') {
            direction = 'down';
          } else if (details.delta.dy < 0 && direction != 'down') {
            direction = 'up';
          }
        },
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 0 && direction != 'left') {
            direction = 'right';
          } else if (details.delta.dx < 0 && direction != 'right') {
            direction = 'left';
          }
        },
        child: Column(
          children: [
            // Professional Scoreboard
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScoreItem("SCORE", score.toString(), const Color(0xFF10B981)),
                    _buildScoreItem("MODE", widget.difficultyName.toUpperCase(), Colors.amber),
                  ],
                ),
              ),
            ),

            // Game Grid
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: colCount,
                          ),
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
                                child: Text(
                                  currentFoodEmoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            }

                            return Container(
                              margin: const EdgeInsets.all(0.5),
                              decoration: BoxDecoration(
                                color: isHead
                                    ? const Color(0xFF10B981)
                                    : isBody
                                        ? const Color(0xFF10B981).withOpacity(0.5)
                                        : Colors.transparent,
                                borderRadius: isHead
                                    ? BorderRadius.circular(4)
                                    : isBody
                                        ? BorderRadius.circular(2)
                                        : null,
                              ),
                            );
                          },
                        ),
                        if (!isPlaying)
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: startGame,
                              icon: const Icon(Icons.play_arrow_rounded, size: 32),
                              label: const Text("START GAME", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Control Instructions
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Opacity(
                opacity: 0.5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swipe_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "Swipe to control the snake",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}