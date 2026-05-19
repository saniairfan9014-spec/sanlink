import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_animations.dart';
import 'tic_tac_toe/tictactoe_category_screen.dart';
import 'quiz/quiz_category_screen.dart';
import 'snackgame/snake_category_screen.dart';
import 'blockgame/brick_category_screen.dart';
import 'services/game_service.dart';

// ─── Game card data ────────────────────────────────────────────────────────────
class _GameData {
  final String title;
  final String subtitle;
  final String xp;
  final String difficulty;
  final Color color;
  final IconData icon;
  final Widget Function(BuildContext) screenBuilder;

  const _GameData({
    required this.title,
    required this.subtitle,
    required this.xp,
    required this.difficulty,
    required this.color,
    required this.icon,
    required this.screenBuilder,
  });
}

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  static final _games = [
    _GameData(
      title: 'Tic Tac Toe',
      subtitle: 'Classic 3×3 strategy battle',
      xp: '+80 XP',
      difficulty: 'Easy',
      color: AppThemes.primary,
      icon: Icons.grid_3x3_rounded,
      screenBuilder: _buildTicTacToe,
    ),
    _GameData(
      title: 'Quiz Master',
      subtitle: 'Test your knowledge across topics',
      xp: '+120 XP',
      difficulty: 'Medium',
      color: AppThemes.accent,
      icon: Icons.psychology_rounded,
      screenBuilder: _buildQuiz,
    ),
    _GameData(
      title: 'Brick Breaker',
      subtitle: 'Smash bricks, score big',
      xp: '+150 XP',
      difficulty: 'Hard',
      color: AppThemes.orange,
      icon: Icons.view_module_rounded,
      screenBuilder: _buildBrick,
    ),
    _GameData(
      title: 'Snake Game',
      subtitle: 'Grow longer, survive longer',
      xp: '+100 XP',
      difficulty: 'Medium',
      color: AppThemes.green,
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
    Navigator.push(context, AppAnimations.fadeSlideRoute(game.screenBuilder(context)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => AppGradients.primaryAccent.createShader(b),
                    child: Text(
                      'BATTLE ARENA',
                      style: context.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(Icons.notifications_none_rounded, color: colors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),

            // XP Status
            _isLoading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: colors.primary)),
                  )
                : _XPStatusSection(levelInfo: _levelInfo!, colors: colors),

            const SizedBox(height: 16),

            // Section Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'DISCOVER GAMES',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Divider(color: colors.border, thickness: 1)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Game Cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                itemCount: GamesScreen._games.length,
                itemBuilder: (context, index) => _PremiumGameCard(
                  index: index,
                  game: GamesScreen._games[index],
                  colors: colors,
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

// ─── XP Status Section ────────────────────────────────────────────────────────
class _XPStatusSection extends StatelessWidget {
  final LevelInfo levelInfo;
  final AppColorsExtension colors;
  const _XPStatusSection({required this.levelInfo, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Radii.xxl),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(color: colors.primaryGlow.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: AppGradients.primaryAccent,
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: [BoxShadow(color: colors.primaryGlow, blurRadius: 10, spreadRadius: 1)],
            ),
            child: const Center(child: Icon(Icons.bolt_rounded, color: Colors.white, size: 30)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("PRO GAMER", style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text("LEVEL ${levelInfo.level}", style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: levelInfo.progress, minHeight: 8,
                    backgroundColor: colors.bg,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${levelInfo.currentXp} / ${levelInfo.nextLevelXp} XP to Level ${levelInfo.level + 1}",
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
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
  final AppColorsExtension colors;
  final VoidCallback onTap;

  const _PremiumGameCard({required this.index, required this.game, required this.colors, required this.onTap});

  @override
  State<_PremiumGameCard> createState() => _PremiumGameCardState();
}

class _PremiumGameCardState extends State<_PremiumGameCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: 500 + widget.index * 100))..forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final colors = widget.colors;

    return FadeTransition(
      opacity: _ctrl,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart)),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 110,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(Radii.xxl),
                border: Border.all(color: _pressed ? game.color : colors.border, width: 1.5),
                boxShadow: _pressed ? [BoxShadow(color: game.color.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)] : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.xxl),
                child: Stack(
                  children: [
                    Positioned(right: -30, top: -30, child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(color: game.color.withOpacity(0.06), shape: BoxShape.circle),
                    )),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: game.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(Radii.xl),
                            ),
                            child: Icon(game.icon, color: game.color, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(game.title, style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                                Text(game.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                                const SizedBox(height: 8),
                                Row(children: [
                                  _MiniTag(label: game.difficulty, color: game.color, bgColor: colors.surfaceAlt),
                                  const SizedBox(width: 8),
                                  _MiniTag(label: game.xp, color: colors.gold, bgColor: colors.surfaceAlt),
                                ]),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: colors.textMuted),
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
  final Color bgColor;
  const _MiniTag({required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(Radii.xs),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}