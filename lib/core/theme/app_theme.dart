import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  system
}

class AppThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  static const String _themePrefKey = 'theme_pref';

  AppThemeProvider() {
    _loadTheme();
  }

  AppThemeMode get themeMode => _themeMode;

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  void setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, mode.toString());
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePrefKey);
    if (savedTheme != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (e) => e.toString() == savedTheme,
        orElse: () => AppThemeMode.system,
      );
      notifyListeners();
    }
  }
}

// ─── Theme Palettes ──────────────────────────────────────────────────────────

class AppThemes {
  // Dark Theme Colors
  static const darkBg = Color(0xFF0A0A0F);
  static const darkSurface = Color(0xFF13131A);
  static const darkSurfaceAlt = Color(0xFF1C1C27);
  static const darkBorder = Color(0xFF2A2A3D);
  static const darkTextPrimary = Color(0xFFF0F0FF);
  static const darkTextSecondary = Color(0xFF8888AA);
  static const darkTextMuted = Color(0xFF44445A);

  // Light Theme Colors
  static const lightBg = Color(0xFFF5F5FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF0F0F5);
  static const lightBorder = Color(0xFFE0E0E8);
  static const lightTextPrimary = Color(0xFF1A1A2E);
  static const lightTextSecondary = Color(0xFF6B6B8A);
  static const lightTextMuted = Color(0xFF9999B3);

  // Shared Brand Colors
  static const primary = Color(0xFF7C5CFC);
  static const primaryGlow = Color(0x557C5CFC);
  static const accent = Color(0xFF00E5FF);
  static const accentGlow = Color(0x3300E5FF);
  static const gold = Color(0xFFFFD700);
  static const red = Color(0xFFFF4757);

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: darkBg,
    fontFamily: 'Poppins',
    extensions: const <ThemeExtension<dynamic>>[
      AppColorsExtension(
        bg: darkBg,
        surface: darkSurface,
        surfaceAlt: darkSurfaceAlt,
        border: darkBorder,
        primary: primary,
        primaryGlow: primaryGlow,
        accent: accent,
        accentGlow: accentGlow,
        gold: gold,
        red: red,
        textPrimary: darkTextPrimary,
        textSecondary: darkTextSecondary,
        textMuted: darkTextMuted,
      ),
    ],
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: lightBg,
    fontFamily: 'Poppins',
    extensions: const <ThemeExtension<dynamic>>[
      AppColorsExtension(
        bg: lightBg,
        surface: lightSurface,
        surfaceAlt: lightSurfaceAlt,
        border: lightBorder,
        primary: primary,
        primaryGlow: primaryGlow,
        accent: accent,
        accentGlow: accentGlow,
        gold: gold,
        red: red,
        textPrimary: lightTextPrimary,
        textSecondary: lightTextSecondary,
        textMuted: lightTextMuted,
      ),
    ],
  );
}

// ─── Theme Extension ─────────────────────────────────────────────────────────

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color primary;
  final Color primaryGlow;
  final Color accent;
  final Color accentGlow;
  final Color gold;
  final Color red;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const AppColorsExtension({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.primary,
    required this.primaryGlow,
    required this.accent,
    required this.accentGlow,
    required this.gold,
    required this.red,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? primary,
    Color? primaryGlow,
    Color? accent,
    Color? accentGlow,
    Color? gold,
    Color? red,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return AppColorsExtension(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryGlow: primaryGlow ?? this.primaryGlow,
      accent: accent ?? this.accent,
      accentGlow: accentGlow ?? this.accentGlow,
      gold: gold ?? this.gold,
      red: red ?? this.red,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryGlow: Color.lerp(primaryGlow, other.primaryGlow, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      red: Color.lerp(red, other.red, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

// ─── BuildContext Helper ─────────────────────────────────────────────────────

extension AppThemeContext on BuildContext {
  AppColorsExtension get colors => Theme.of(this).extension<AppColorsExtension>()!;
}
