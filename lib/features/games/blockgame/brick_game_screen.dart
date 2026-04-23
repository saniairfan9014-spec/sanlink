import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/game_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const int _kCols = 7;
const int _kRows = 6;
const double _kPaddleH = 14;
const double _kBallR = 8;
const double _kBrickPadH = 4;
const double _kBrickPadV = 3;
const double _kBrickTop = 130; // space above first brick row
const double _kBrickRowH = 28;
const int _kTickMs = 14; // ~71fps

// ─── Colors ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0A0F);
const _primary = Color(0xFF7C5CFC);
const _accent = Color(0xFF00E5FF);
const _textP = Color(0xFFF0F0FF);
const _textM = Color(0xFF44445A);

const _rowColors = [
  Color(0xFFFF4757), // row 0 – red
  Color(0xFFFF6B35), // row 1 – orange
  Color(0xFFFFD200), // row 2 – yellow
  Color(0xFF2ED573), // row 3 – green
  Color(0xFF1E90FF), // row 4 – blue
  Color(0xFFB44FFF), // row 5 – purple
];

// ─── Brick model ─────────────────────────────────────────────────────────────
class _Brick {
  bool alive = true;
  final int row;
  final int col;
  int hp; // 1 = normal, 2 = tough (darker), 3 = super (even darker)

  _Brick({required this.row, required this.col, required this.hp});

  Color get color {
    final base = _rowColors[row % _rowColors.length];
    if (hp == 3) return Color.lerp(base, Colors.black, 0.55)!;
    if (hp == 2) return Color.lerp(base, Colors.black, 0.3)!;
    return base;
  }
}

// ─── Game states ─────────────────────────────────────────────────────────────
enum _State { idle, playing, paused, won, lost }

// ──────────────────────────────────────────────────────────────────────────────
class BrickGameScreen extends StatefulWidget {
  const BrickGameScreen({super.key});

  @override
  State<BrickGameScreen> createState() => _BrickGameScreenState();
}

class _BrickGameScreenState extends State<BrickGameScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  // layout (set after first layout)
  double _sw = 0, _sh = 0;

  // game objects
  double _padX = 0;
  final double _padW = 90;
  double _bx = 0, _by = 0; // ball position (centre)
  double _dx = 0, _dy = 0; // ball velocity (px/tick)
  List<_Brick> _bricks = [];
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  int _level = 1;

  _State _state = _State.idle;
  Timer? _timer;
  int _combo = 0;

  // animations
  late AnimationController _titlePulse;
  late AnimationController _levelUp;

  @override
  void initState() {
    super.initState();
    _titlePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _levelUp = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _titlePulse.dispose();
    _levelUp.dispose();
    super.dispose();
  }

  // ─── Layout helpers ──────────────────────────────────────────────────────
  double get _padY => _sh - 100;
  double get _brickW =>
      (_sw - (_kBrickPadH * (_kCols + 1))) / _kCols;

  Rect _brickRect(_Brick b) {
    final x = _kBrickPadH + b.col * (_brickW + _kBrickPadH);
    final y = _kBrickTop + b.row * (_kBrickRowH + _kBrickPadV);
    return Rect.fromLTWH(x, y, _brickW, _kBrickRowH);
  }

  // ─── Init game ───────────────────────────────────────────────────────────
  void _initGame({bool nextLevel = false}) {
    if (_sw == 0) return;
    if (!nextLevel) {
      _score = 0;
      _lives = 3;
      _level = 1;
    }
    _padX = (_sw - _padW) / 2;
    _resetBall();
    _buildBricks();
    _combo = 0;
    setState(() => _state = _State.idle);
  }

  void _resetBall() {
    _bx = _sw / 2;
    _by = _padY - _kBallR - 2;
    final angle = (Random().nextDouble() * 60 + 60) * pi / 180;
    final speed = 5.0 + _level * 0.5;
    _dx = cos(angle) * speed * (Random().nextBool() ? 1 : -1);
    _dy = -sin(angle).abs() * speed;
  }

  void _buildBricks() {
    _bricks = [];
    for (int r = 0; r < _kRows; r++) {
      for (int c = 0; c < _kCols; c++) {
        // higher levels introduce tougher bricks
        int hp = 1;
        if (_level >= 3 && r < 2) hp = 2;
        if (_level >= 5 && r == 0) hp = 3;
        _bricks.add(_Brick(row: r, col: c, hp: hp));
      }
    }
  }

  // ─── Game loop ───────────────────────────────────────────────────────────
  void _startLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: _kTickMs),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (_state != _State.playing) return;
    setState(() {
      _bx += _dx;
      _by += _dy;
      _wallBounce();
      _paddleBounce();
      _brickCollision();
      _checkDeath();
      _checkWin();
    });
  }

  void _wallBounce() {
    if (_bx - _kBallR <= 0) {
      _bx = _kBallR;
      _dx = _dx.abs();
    } else if (_bx + _kBallR >= _sw) {
      _bx = _sw - _kBallR;
      _dx = -_dx.abs();
    }
    if (_by - _kBallR <= 0) {
      _by = _kBallR;
      _dy = _dy.abs();
    }
  }

  void _paddleBounce() {
    final padRect = Rect.fromLTWH(_padX, _padY, _padW, _kPaddleH);
    if (_by + _kBallR >= padRect.top &&
        _by + _kBallR <= padRect.bottom + 10 &&
        _bx >= padRect.left - _kBallR &&
        _bx <= padRect.right + _kBallR &&
        _dy > 0) {
      // angle based on hit position
      final hitPos = (_bx - padRect.left) / padRect.width; // 0..1
      final angle = pi / 6 + hitPos * (pi * 2 / 3); // 30°..150°
      final speed = sqrt(_dx * _dx + _dy * _dy);
      _dx = cos(angle) * speed * (hitPos < 0.5 ? -1 : 1);
      _dy = -sin(angle).abs() * speed;
      _by = padRect.top - _kBallR;
      _combo = 0;
      HapticFeedback.selectionClick();
    }
  }

  void _brickCollision() {
    for (final b in _bricks) {
      if (!b.alive) continue;
      final r = _brickRect(b);
      if (_bx + _kBallR < r.left ||
          _bx - _kBallR > r.right ||
          _by + _kBallR < r.top ||
          _by - _kBallR > r.bottom) continue;

      // Determine which edge was hit
      final overlapL = (_bx + _kBallR) - r.left;
      final overlapR = r.right - (_bx - _kBallR);
      final overlapT = (_by + _kBallR) - r.top;
      final overlapB = r.bottom - (_by - _kBallR);
      final minH = min(overlapL, overlapR);
      final minV = min(overlapT, overlapB);

      if (minH < minV) {
        _dx = -_dx;
      } else {
        _dy = -_dy;
      }

      b.hp--;
      if (b.hp <= 0) {
        b.alive = false;
        _combo++;
        final pts = (10 + (_combo > 1 ? _combo * 5 : 0)) * _level;
        _score += pts;
        if (_score > _highScore) _highScore = _score;
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
      break; // one brick per tick
    }
  }

  void _checkDeath() {
    if (_by - _kBallR > _sh) {
      _lives--;
      HapticFeedback.heavyImpact();
      if (_lives <= 0) {
        _timer?.cancel();
        _state = _State.lost;
        _gameService.addGameResult('brickbreaker', false);
      } else {
        _resetBall();
        _state = _State.idle;
        _combo = 0;
      }
    }
  }

  void _checkWin() {
    if (_bricks.every((b) => !b.alive)) {
      _timer?.cancel();
      _state = _State.won;
      _gameService.addGameResult('brickbreaker', true);
      HapticFeedback.heavyImpact();
    }
  }

  // ─── Controls ────────────────────────────────────────────────────────────
  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _padX = (_padX + d.delta.dx).clamp(0, _sw - _padW);
      // drag ball with paddle when idle
      if (_state == _State.idle) {
        _bx = _padX + _padW / 2;
        _by = _padY - _kBallR - 2;
      }
    });
  }

  void _onTap() {
    if (_state == _State.idle) {
      setState(() => _state = _State.playing);
      _startLoop();
    } else if (_state == _State.playing) {
      setState(() => _state = _State.paused);
      _timer?.cancel();
    } else if (_state == _State.paused) {
      setState(() => _state = _State.playing);
      _startLoop();
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_sw == 0) {
            _sw = constraints.maxWidth;
            _sh = constraints.maxHeight;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _initGame());
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            onPanUpdate: _onPanUpdate,
            child: Stack(
              children: [
                // ─── Background grid lines ───────────────────────────────
                CustomPaint(
                  size: Size(_sw, _sh),
                  painter: _GridPainter(),
                ),

                // ─── HUD ─────────────────────────────────────────────────
                _HUD(
                  score: _score,
                  highScore: _highScore,
                  lives: _lives,
                  level: _level,
                  combo: _combo,
                  onBack: () => Navigator.pop(context),
                  onPause: () {
                    if (_state == _State.playing) {
                      setState(() => _state = _State.paused);
                      _timer?.cancel();
                    } else if (_state == _State.paused) {
                      setState(() => _state = _State.playing);
                      _startLoop();
                    }
                  },
                  isPaused: _state == _State.paused,
                ),

                // ─── Bricks ──────────────────────────────────────────────
                ..._bricks.where((b) => b.alive).map((b) {
                  final r = _brickRect(b);
                  return Positioned(
                    left: r.left,
                    top: r.top,
                    width: r.width,
                    height: r.height,
                    child: _BrickWidget(brick: b),
                  );
                }),

                // ─── Ball ────────────────────────────────────────────────
                if (_sw > 0)
                  Positioned(
                    left: _bx - _kBallR,
                    top: _by - _kBallR,
                    child: _BallWidget(state: _state),
                  ),

                // ─── Paddle ──────────────────────────────────────────────
                if (_sw > 0)
                  Positioned(
                    left: _padX,
                    top: _padY,
                    width: _padW,
                    height: _kPaddleH,
                    child: const _PaddleWidget(),
                  ),

                // ─── Overlays ────────────────────────────────────────────
                if (_state == _State.idle)
                  _IdleOverlay(titlePulse: _titlePulse),
                if (_state == _State.paused) const _PausedOverlay(),
                if (_state == _State.won)
                  _WonOverlay(
                    score: _score,
                    level: _level,
                    onNext: () {
                      setState(() {
                        _level++;
                        _initGame(nextLevel: true);
                      });
                    },
                  ),
                if (_state == _State.lost)
                  _LostOverlay(
                    score: _score,
                    highScore: _highScore,
                    onRestart: () => _initGame(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PAINTERS & WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A28)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Brick ───────────────────────────────────────────────────────────────────
class _BrickWidget extends StatelessWidget {
  final _Brick brick;
  const _BrickWidget({required this.brick});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: brick.color,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: brick.color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: brick.hp > 1
          ? Center(
              child: Text(
                '×${brick.hp}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}

// ─── Ball ────────────────────────────────────────────────────────────────────
class _BallWidget extends StatelessWidget {
  final _State state;
  const _BallWidget({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kBallR * 2,
      height: _kBallR * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Colors.white, _accent],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.7),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

// ─── Paddle ──────────────────────────────────────────────────────────────────
class _PaddleWidget extends StatelessWidget {
  const _PaddleWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          const BoxShadow(
              color: Color(0x557C5CFC), blurRadius: 14, spreadRadius: 2),
          const BoxShadow(
              color: Color(0x3300E5FF), blurRadius: 20, spreadRadius: 4),
        ],
      ),
    );
  }
}

// ─── HUD ─────────────────────────────────────────────────────────────────────
class _HUD extends StatelessWidget {
  final int score, highScore, lives, level, combo;
  final VoidCallback onBack;
  final VoidCallback onPause;
  final bool isPaused;

  const _HUD({
    required this.score,
    required this.highScore,
    required this.lives,
    required this.level,
    required this.combo,
    required this.onBack,
    required this.onPause,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textP),
                  onPressed: onBack,
                ),
                IconButton(
                  icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: _textP, size: 28),
                  onPressed: onPause,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Lives
            Row(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: i < lives ? const Color(0xFFFF4757) : _textM,
                    size: 18,
                  ),
                ),
              ),
            ),
            // Score
            Column(
              children: [
                Text('$score',
                    style: const TextStyle(
                        color: _textP,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                Text('BEST $highScore',
                    style: const TextStyle(color: _textM, fontSize: 10)),
              ],
            ),
            // Level + Combo
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _primary.withValues(alpha: 0.4)),
                  ),
                  child: Text('LVL $level',
                      style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
                if (combo > 1)
                  Text('×$combo COMBO!',
                      style: const TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }
}

// ─── Overlays ────────────────────────────────────────────────────────────────
class _IdleOverlay extends StatelessWidget {
  final AnimationController titlePulse;
  const _IdleOverlay({required this.titlePulse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween(begin: 0.95, end: 1.05).animate(
              CurvedAnimation(parent: titlePulse, curve: Curves.easeInOut),
            ),
            child: ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [_primary, _accent],
              ).createShader(b),
              child: const Text('BRICK\nBREAKER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 4)),
            ),
          ),
          const SizedBox(height: 24),
          _GlowButton(
            label: 'TAP TO LAUNCH',
            onTap: null, // handled by GestureDetector
          ),
          const SizedBox(height: 12),
          const Text('Drag to move paddle',
              style: TextStyle(color: _textM, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_filled_rounded,
                color: _primary, size: 64),
            SizedBox(height: 12),
            Text('PAUSED',
                style: TextStyle(
                    color: _textP,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4)),
            SizedBox(height: 8),
            Text('Tap anywhere to resume',
                style: TextStyle(color: _textM, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _WonOverlay extends StatelessWidget {
  final int score, level;
  final VoidCallback onNext;
  const _WonOverlay(
      {required this.score, required this.level, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('LEVEL CLEAR!',
                style: TextStyle(
                    color: _textP,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
            const SizedBox(height: 8),
            Text('Score: $score',
                style: const TextStyle(
                    color: _accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 28),
            _GlowButton(label: 'NEXT LEVEL', onTap: onNext),
          ],
        ),
      ),
    );
  }
}

class _LostOverlay extends StatelessWidget {
  final int score, highScore;
  final VoidCallback onRestart;
  const _LostOverlay(
      {required this.score,
      required this.highScore,
      required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💀', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('GAME OVER',
                style: TextStyle(
                    color: Color(0xFFFF4757),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
            const SizedBox(height: 8),
            Text('Score: $score',
                style: const TextStyle(
                    color: _textP,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            if (score >= highScore && score > 0)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('🎉 New High Score!',
                    style: TextStyle(color: _accent, fontSize: 14)),
              ),
            const SizedBox(height: 28),
            _GlowButton(label: 'PLAY AGAIN', onTap: onRestart),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Menu',
                  style: TextStyle(color: _textM)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glow Button ─────────────────────────────────────────────────────────────
class _GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _GlowButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [
            BoxShadow(
                color: Color(0x667C5CFC), blurRadius: 20, spreadRadius: 2),
            BoxShadow(
                color: Color(0x3300E5FF), blurRadius: 30, spreadRadius: 4),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2),
        ),
      ),
    );
  }
}