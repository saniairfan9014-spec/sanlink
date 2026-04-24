import 'dart:async';
import 'package:flutter/material.dart';
import 'quiz_data.dart';
import 'quiz_model.dart';
import '../services/game_service.dart';

class QuizScreen extends StatefulWidget {
  final String selectedCategory;
  final int timerDuration;
  final String difficultyName;

  const QuizScreen({
    super.key,
    required this.selectedCategory,
    required this.timerDuration,
    required this.difficultyName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  final GameService _gameService = GameService();
  late List<Question> questions;
  int currentIndex = 0;
  int score = 0;
  int? selectedOptionIndex;
  bool answered = false;

  // Timer
  late Timer _timer;
  late int _timeLeft;

  // Animation
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    questions = QuizData.getQuestionsForCategory(widget.selectedCategory);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(
        parent: _slideController, curve: Curves.easeIn);

    _slideController.forward();
    _timeLeft = widget.timerDuration;
    _startTimer();
  }

  void _startTimer() {
    _timeLeft = widget.timerDuration;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_timeLeft == 0) {
        t.cancel();
        if (!answered) _autoSkip();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _autoSkip() {
    setState(() {
      answered = true;
      selectedOptionIndex = -1; // no selection, time ran out
    });
    Future.delayed(const Duration(seconds: 1), _nextQuestion);
  }

  void _answerQuestion(int index) {
    if (answered) return;
    _timer.cancel();

    setState(() {
      answered = true;
      selectedOptionIndex = index;
      if (index == questions[currentIndex].correctAnswerIndex) {
        score++;
      }
    });

    Future.delayed(const Duration(milliseconds: 800), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (currentIndex < questions.length - 1) {
      _slideController.reset();
      setState(() {
        currentIndex++;
        answered = false;
        selectedOptionIndex = null;
      });
      _slideController.forward();
      _startTimer();
    } else {
      _showResult();
    }
  }

  void _showResult() {
    // LOG GAME RESULT
    final isWin = score / questions.length >= 0.7;
    _gameService.addGameResult('quiz', isWin, score: score, difficulty: widget.difficultyName);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _ResultScreen(
            score: score,
            total: questions.length,
            category: widget.selectedCategory,
            onRestart: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizScreen(
                    selectedCategory: widget.selectedCategory,
                    timerDuration: widget.timerDuration,
                    difficultyName: widget.difficultyName,
                  ),
                ),
              );
            },
          ),
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _slideController.dispose();
    super.dispose();
  }

  Color _optionColor(int index) {
    if (!answered) return const Color(0xFF1E1E2E);
    final correct = questions[currentIndex].correctAnswerIndex;
    if (index == correct) return Colors.green.shade700;
    if (index == selectedOptionIndex && index != correct) {
      return Colors.red.shade700;
    }
    return const Color(0xFF1E1E2E);
  }

  Color _optionBorder(int index) {
    if (!answered) return const Color(0xFF3A3A5C);
    final correct = questions[currentIndex].correctAnswerIndex;
    if (index == correct) return Colors.greenAccent;
    if (index == selectedOptionIndex && index != correct) return Colors.redAccent;
    return const Color(0xFF3A3A5C);
  }

  Icon? _trailingIcon(int index) {
    if (!answered) return null;
    final correct = questions[currentIndex].correctAnswerIndex;
    if (index == correct) {
      return const Icon(Icons.check_circle, color: Colors.greenAccent);
    }
    if (index == selectedOptionIndex && index != correct) {
      return const Icon(Icons.cancel, color: Colors.redAccent);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz, color: Colors.white38, size: 60),
              const SizedBox(height: 16),
              Text("No questions in ${widget.selectedCategory}",
                  style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    final q = questions[currentIndex];
    final progress = (currentIndex + 1) / questions.length;
    final timerColor = _timeLeft > (widget.timerDuration * 0.5)
        ? Colors.greenAccent
        : _timeLeft > (widget.timerDuration * 0.2)
            ? Colors.orangeAccent
            : Colors.redAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Bar ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.selectedCategory,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFF2A2A3E),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF7C6FFF)),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Timer Circle
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: _timeLeft / widget.timerDuration,
                          backgroundColor: const Color(0xFF2A2A3E),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(timerColor),
                          strokeWidth: 3,
                        ),
                        Center(
                          child: Text(
                            "$_timeLeft",
                            style: TextStyle(
                                color: timerColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Question Counter ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Question ${currentIndex + 1}/${questions.length}",
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C6FFF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star,
                            color: Color(0xFF7C6FFF), size: 14),
                        const SizedBox(width: 4),
                        Text("Score: $score",
                            style: const TextStyle(
                                color: Color(0xFF7C6FFF),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Question Card ───
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Question Text
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E1E3F), Color(0xFF2A2A50)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: const Color(0xFF3A3A6A), width: 1),
                          ),
                          child: Text(
                            q.questionText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ─── Options ───
                        ...List.generate(q.options.length, (i) {
                          return _OptionTile(
                            label: q.options[i],
                            optionLetter:
                                ["A", "B", "C", "D"][i],
                            bgColor: _optionColor(i),
                            borderColor: _optionBorder(i),
                            trailingIcon: _trailingIcon(i),
                            onTap: () => _answerQuestion(i),
                            answered: answered,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ─── Skip Button ───
            if (!answered)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: TextButton(
                  onPressed: _autoSkip,
                  child: const Text("Skip →",
                      style: TextStyle(color: Colors.white38)),
                ),
              )
            else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ──────────── Option Tile ────────────
class _OptionTile extends StatelessWidget {
  final String label;
  final String optionLetter;
  final Color bgColor;
  final Color borderColor;
  final Icon? trailingIcon;
  final VoidCallback onTap;
  final bool answered;

  const _OptionTile({
    required this.label,
    required this.optionLetter,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
    required this.answered,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: answered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  optionLetter,
                  style: TextStyle(
                      color: borderColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            if (trailingIcon != null) trailingIcon!,
          ],
        ),
      ),
    );
  }
}

// ──────────── Result Screen ────────────
class _ResultScreen extends StatelessWidget {
  final int score;
  final int total;
  final String category;
  final VoidCallback onRestart;

  const _ResultScreen({
    required this.score,
    required this.total,
    required this.category,
    required this.onRestart,
  });

  String get _emoji {
    final pct = score / total;
    if (pct == 1.0) return "🏆";
    if (pct >= 0.7) return "🎉";
    if (pct >= 0.5) return "👍";
    return "💪";
  }

  String get _message {
    final pct = score / total;
    if (pct == 1.0) return "Perfect Score!";
    if (pct >= 0.7) return "Great Job!";
    if (pct >= 0.5) return "Good Effort!";
    return "Keep Practicing!";
  }

  @override
  Widget build(BuildContext context) {
    final pct = score / total;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_emoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  _message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  category,
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 40),

                // Score Ring
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFF2A2A3E),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct >= 0.7
                              ? Colors.greenAccent
                              : pct >= 0.5
                                  ? Colors.orangeAccent
                                  : Colors.redAccent,
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$score",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "/ $total",
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Retry button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRestart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C6FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: const Color(0xFF7C6FFF).withOpacity(0.5),
                    ),
                    child: const Text("Play Again",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Color(0xFF3A3A5C)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Back to Categories",
                        style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}