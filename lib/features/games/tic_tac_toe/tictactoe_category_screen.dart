import 'package:flutter/material.dart';
import 'tictoe_screen.dart';

class TicTacToeCategoryScreen extends StatelessWidget {
  const TicTacToeCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F), // Deep space background
      appBar: AppBar(
        title: const Text(
          "Tic Tac Toe Royale",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Challenge Mode",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Battle against the AI or challenge a friend",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 48),
            _buildModeCard(
              context,
              title: "AI Battle",
              description: "Face our advanced Minimax algorithm",
              icon: Icons.smart_toy_rounded,
              color: const Color(0xFF00E5FF),
              mode: 'pvai',
            ),
            const SizedBox(height: 20),
            _buildModeCard(
              context,
              title: "Local PvP",
              description: "Two players, one device",
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF7C5CFC),
              mode: 'pvp',
            ),
            const SizedBox(height: 40),
            const Text(
              "Redesigned for a Premium Experience",
              style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String mode,
  }) {
    return GestureDetector(
      onTap: () {
        if (mode == 'pvai') {
          _showDifficultySelector(context);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicTacToeScreen(initialMode: mode),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showDifficultySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF13131A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: Color(0xFF2A2A3D), width: 2)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "AI Difficulty",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Higher difficulty earns more XP",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 32),
                _DifficultyButton(
                  title: "Easy",
                  subtitle: "AI makes random moves",
                  icon: Icons.face_retouching_natural_rounded,
                  color: Colors.greenAccent,
                  onTap: () => _startTicTacToe(context, 'Easy'),
                ),
                const SizedBox(height: 16),
                _DifficultyButton(
                  title: "Medium",
                  subtitle: "A balanced challenge",
                  icon: Icons.smart_toy_rounded,
                  color: Colors.orangeAccent,
                  onTap: () => _startTicTacToe(context, 'Medium'),
                ),
                const SizedBox(height: 16),
                _DifficultyButton(
                  title: "Hard",
                  subtitle: "Unbeatable Minimax AI",
                  icon: Icons.psychology_rounded,
                  color: Colors.redAccent,
                  onTap: () => _startTicTacToe(context, 'Hard'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startTicTacToe(BuildContext context, String difficulty) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicTacToeScreen(
          initialMode: 'pvai',
          difficulty: difficulty,
        ),
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
