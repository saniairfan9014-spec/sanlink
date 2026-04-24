import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tic_tac_toe/tictactoe_category_screen.dart';
import 'quiz/quiz_category_screen.dart';
import 'snackgame/snake_category_screen.dart';
import 'blockgame/brick_category_screen.dart';
import 'services/game_service.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surfaceAlt = Color(0xFF1C1C27);
  static const border = Color(0xFF2A2A3D);
  static const primary = Color(0xFF7C5CFC);
  static const primaryGlow = Color(0x557C5CFC);
  static const accent = Color(0xFF00E5FF);
  static const accentGlow = Color(0x3300E5FF);
  static const gold = Color(0xFFFFD700);
  static const green = Color(0xFF00E676);
  static const orange = Color(0xFFFF6D00);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF44445A);
}

// ─── Game card data ────────────────────────────────────────────────────────────
class _GameData {
  final String title;
  final String subtitle;
  final String xp;
  final String difficulty;
  final Color color;
  final Color glowColor;
  final IconData icon;
  final Widget Function(BuildContext) screenBuilder;

  const _GameData({
    required this.title,
    required this.subtitle,
    required this.xp,
    required this.difficulty,
    required this.color,
    required this.glowColor,
    required this.icon,
    required this.screenBuilder,
  });
}

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  static const _games = [
    _GameData(
      title: 'Tic Tac Toe',
      subtitle: 'Classic 3×3 strategy battle',
      xp: '+80 XP',
      difficulty: 'Easy',
      color: _C.primary,
      glowColor: _C.primaryGlow,
      icon: Icons.grid_3x3_rounded,
      screenBuilder: _buildTicTacToe,
    ),
    _GameData(
      title: 'Quiz Master',
      subtitle: 'Test your knowledge across topics',
      xp: '+120 XP',
      difficulty: 'Medium',
      color: _C.accent,
      glowColor: _C.accentGlow,
      icon: Icons.psychology_rounded,
      screenBuilder: _buildQuiz,
    ),
    _GameData(
      title: 'Brick Breaker',
      subtitle: 'Smash bricks, score big',
      xp: '+150 XP',
      difficulty: 'Hard',
      color: _C.orange,
      glowColor: Color(0x55FF6D00),
      icon: Icons.view_module_rounded,
      screenBuilder: _buildBrick,
    ),
    _GameData(
      title: 'Snake Game',
      subtitle: 'Grow longer, survive longer',
      xp: '+100 XP',
      difficulty: 'Medium',
      color: _C.green,
      glowColor: Color(0x5500E676),
      icon: Icons.timeline_rounded,
      screenBuilder: _buildSnake,
    ),
  ];

  static Widget _buildTicTacToe(BuildContext _) => const TicTacToeCategoryScreen();
  static Widget _buildQuiz(BuildContext _) => const QuizCategoryScreen();
  static Widget _buildBrick(BuildContext _) => const BrickCategoryScreen();
  static Widget _buildSnake(BuildContext _) => const SnakeCategoryScreen();

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final GameService _gameService = GameService();
  LevelInfo? _levelInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLevelInfo();
  }

  Future<void> _loadLevelInfo() async {
    final info = await _gameService.getUserLevelInfo();
    if (mounted) {
      setState(() {
        _levelInfo = info;
        _isLoading = false;
      });
    }
  }


  void _navigate(BuildContext context, _GameData game) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => game.screenBuilder(context),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            _isLoading 
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: _C.primary)),
                  )
                : _XPStatusSection(levelInfo: _levelInfo!),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'DISCOVER GAMES',
                    style: TextStyle(
                      color: _C.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Divider(color: _C.border, thickness: 1)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                itemCount: GamesScreen._games.length,
                itemBuilder: (context, index) => _PremiumGameCard(
                  index: index,
                  game: GamesScreen._games[index],
                  onTap: () => _navigate(context, GamesScreen._games[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [_C.primary, _C.accent],
                ).createShader(b),
                child: const Text(
                  'BATTLE ARENA',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.surface,
              shape: BoxShape.circle,
              border: Border.all(color: _C.border),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─── XP Status Section ────────────────────────────────────────────────────────
class _XPStatusSection extends StatelessWidget {
  final LevelInfo levelInfo;
  const _XPStatusSection({required this.levelInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Level Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _C.primaryGlow, blurRadius: 10, spreadRadius: 1)
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "PRO GAMER",
                          style: TextStyle(color: _C.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                        Text(
                          "LEVEL ${levelInfo.level}",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: levelInfo.progress,
                        minHeight: 8,
                        backgroundColor: _C.bg,
                        valueColor: const AlwaysStoppedAnimation<Color>(_C.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${levelInfo.currentXp} / ${levelInfo.nextLevelXp} XP to Level ${levelInfo.level + 1}",
                      style: const TextStyle(color: _C.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Premium Game Card ────────────────────────────────────────────────────────
class _PremiumGameCard extends StatefulWidget {
  final int index;
  final _GameData game;
  final VoidCallback onTap;

  const _PremiumGameCard({
    required this.index,
    required this.game,
    required this.onTap,
  });

  @override
  State<_PremiumGameCard> createState() => _PremiumGameCardState();
}

class _PremiumGameCardState extends State<_PremiumGameCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500 + widget.index * 100),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return FadeTransition(
      opacity: _ctrl,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart)),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 100,
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _pressed ? game.color : _C.border, width: 1.5),
                boxShadow: [
                  if (_pressed)
                    BoxShadow(color: game.color.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Background Glow Accent
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: game.color.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: game.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(game.icon, color: game.color, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  game.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  game.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: _C.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _MiniTag(label: game.difficulty, color: game.color),
                                    const SizedBox(width: 8),
                                    _MiniTag(label: game.xp, color: _C.gold),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: _C.textMuted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}