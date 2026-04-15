import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_logic.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0A0F);
const _surface = Color(0xFF13131A);
const _surfaceAlt = Color(0xFF1C1C27);
const _border = Color(0xFF2A2A3D);
const _primary = Color(0xFF7C5CFC);
const _accent = Color(0xFF00E5FF);
const _xColor = Color(0xFF7C5CFC);
const _oColor = Color(0xFF00E5FF);
const _textP = Color(0xFFF0F0FF);
const _textM = Color(0xFF44445A);
const _winGlow = Color(0xFF00E676);

class TicTacToeScreen extends StatefulWidget {
  final String initialMode;

  const TicTacToeScreen({super.key, required this.initialMode});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> with TickerProviderStateMixin {
  // ─── Game State ────────────────────────────────────────────────────────────
  List<String> board = List.filled(9, '');
  String winner = '';
  bool aiThinking = false;
  List<int>? winLine;

  int playerWins = 0;
  int aiWins = 0;
  int draws = 0;

  late String mode;
  String currentPlayer = 'X';

  // ─── Animations ────────────────────────────────────────────────────────────
  late List<AnimationController> _cellControllers;
  late List<Animation<double>> _cellScales;
  late AnimationController _glowController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    mode = widget.initialMode;
    _cellControllers = List.generate(
      9,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _cellScales = _cellControllers.map((c) => CurvedAnimation(parent: c, curve: Curves.elasticOut)).toList();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    for (final c in _cellControllers) {
      c.dispose();
    }
    _glowController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _onCellTap(int index) async {
    if (board[index] != '' || winner != '' || aiThinking) return;

    if (mode == 'pvai') {
      _playMove(index, 'X');
      if (winner != '') return;

      setState(() => aiThinking = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      final aiMove = GameLogic.bestMove(List.from(board), 'O');
      _playMove(aiMove, 'O');
      setState(() => aiThinking = false);
    } else {
      _playMove(index, currentPlayer);
      if (winner == '') {
        setState(() => currentPlayer = currentPlayer == 'X' ? 'O' : 'X');
      }
    }
  }

  void _playMove(int index, String player) {
    setState(() => board[index] = player);
    _cellControllers[index].forward(from: 0);
    HapticFeedback.mediumImpact();

    final w = GameLogic.checkWinner(board);
    if (w != '') {
      setState(() {
        winner = w;
        winLine = GameLogic.winningPattern(board);
      });
      if (w == 'Draw') {
        _shakeController.forward(from: 0);
      } else {
        if (w == 'X') playerWins++; else aiWins++;
        HapticFeedback.vibrate();
      }
    }
  }

  void _resetBoard() {
    setState(() {
      board = List.filled(9, '');
      winner = '';
      winLine = null;
      aiThinking = false;
      currentPlayer = 'X';
    });
    for (final c in _cellControllers) {
      c.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boardSize = (size.width - 64).clamp(0.0, 360.0);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          mode == 'pvai' ? "AI Challenge" : "PvP Battle",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildScoreBoard(),
          const SizedBox(height: 32),
          _buildStatusBanner(),
          const Spacer(),
          _buildGameBoard(boardSize),
          const Spacer(),
          _buildActionButtons(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildScoreItem(mode == 'pvai' ? "YOU" : "PLAYER X", playerWins, _xColor),
            _buildScoreItem("DRAWS", draws, Colors.amber),
            _buildScoreItem(mode == 'pvai' ? "AI" : "PLAYER O", aiWins, _oColor),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: _textM, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value.toString(), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildStatusBanner() {
    String text;
    Color color;
    if (winner != '') {
      text = winner == 'Draw' ? "IT'S A DRAW!" : "$winner WINS!";
      color = winner == 'Draw' ? Colors.amber : (winner == 'X' ? _xColor : _oColor);
    } else if (aiThinking) {
      text = "AI IS THINKING...";
      color = _oColor;
    } else {
      text = mode == 'pvai' ? "YOUR TURN" : "PLAYER $currentPlayer'S TURN";
      color = currentPlayer == 'X' ? _xColor : _oColor;
    }

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3 + (_glowController.value * 0.2))),
          ),
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        );
      },
    );
  }

  Widget _buildGameBoard(double boardSize) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final offset = _shakeController.isAnimating ? (_shakeController.value < 0.5 ? _shakeAnim.value : -_shakeAnim.value) : 0.0;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Center(
        child: Container(
          width: boardSize,
          height: boardSize,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              bool isWinCell = winLine?.contains(index) ?? false;
              return GestureDetector(
                onTap: () => _onCellTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isWinCell ? _winGlow.withOpacity(0.1) : _surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isWinCell ? _winGlow : _border,
                      width: isWinCell ? 2 : 1,
                    ),
                  ),
                  child: ScaleTransition(
                    scale: _cellScales[index].value == 0 && board[index].isNotEmpty ? const AlwaysStoppedAnimation(1.0) : _cellScales[index],
                    child: Center(
                      child: board[index] == ''
                          ? null
                          : Text(
                              board[index],
                              style: TextStyle(
                                color: board[index] == 'X' ? _xColor : _oColor,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(color: (board[index] == 'X' ? _xColor : _oColor).withOpacity(0.5), blurRadius: 10)
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _resetBoard,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("RESET ROUND"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.exit_to_app_rounded, color: _textM),
            style: IconButton.styleFrom(
              backgroundColor: _surfaceAlt,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _border),
              ),
            ),
          )
        ],
      ),
    );
  }
}