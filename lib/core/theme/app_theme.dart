import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Theme Mode Provider ──────────────────────────────────────────────────────

enum AppThemeMode { light, dark, system }

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

// ─── Spacing Constants (8pt Grid) ─────────────────────────────────────────────

class Spacing {
  Spacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;
}

// ─── Border Radii Constants ───────────────────────────────────────────────────

class Radii {
  Radii._();
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 100;
}

// ─── Gradient Presets ─────────────────────────────────────────────────────────

class AppGradients {
  AppGradients._();

  static const primary = LinearGradient(
    colors: [Color(0xFF7C5CFC), Color(0xFF9B7BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryAccent = LinearGradient(
    colors: [Color(0xFF7C5CFC), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accent = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warm = LinearGradient(
    colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const success = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF69F0AE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient darkSurface(Color borderColor) => LinearGradient(
    colors: [borderColor.withOpacity(0.1), Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ─── Theme Palettes ───────────────────────────────────────────────────────────

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
  static const primaryLight = Color(0xFF9B7BFF);
  static const primaryGlow = Color(0x557C5CFC);
  static const accent = Color(0xFF00E5FF);
  static const accentGlow = Color(0x3300E5FF);
  static const gold = Color(0xFFFFD700);
  static const red = Color(0xFFFF4757);
  static const green = Color(0xFF00E676);
  static const orange = Color(0xFFFF6D00);

  // ─── Text Theme ─────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Color textPrimary, Color textSecondary) {
    return TextTheme(
      // Display
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: textPrimary,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.3,
      ),
      // Headlines
      headlineLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: 0.2,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      // Titles
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      // Body
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.4,
      ),
      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.3,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }

  // ─── Input Decoration Theme ─────────────────────────────────────────────────

  static InputDecorationTheme _inputTheme({
    required Color fillColor,
    required Color borderColor,
    required Color focusedBorderColor,
    required Color textColor,
    required Color hintColor,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      borderSide: BorderSide(color: borderColor, width: 1),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: red, width: 1),
      ),
      hintStyle: GoogleFonts.inter(
        color: hintColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: GoogleFonts.inter(
        color: hintColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ─── Dark Theme ─────────────────────────────────────────────────────────────

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: darkBg,
    textTheme: _buildTextTheme(darkTextPrimary, darkTextSecondary),
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: darkSurface,
      error: red,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkTextPrimary,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        color: darkTextPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: darkTextPrimary, size: 22),
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: primary,
      unselectedItemColor: darkTextMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkSurface,
      contentTextStyle: GoogleFonts.inter(
        color: darkTextPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: const BorderSide(color: darkBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkBorder,
      thickness: 0.5,
      space: 0,
    ),
    inputDecorationTheme: _inputTheme(
      fillColor: darkSurfaceAlt,
      borderColor: darkBorder,
      focusedBorderColor: primary,
      textColor: darkTextPrimary,
      hintColor: darkTextMuted,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: darkBorder),
      ),
      textStyle: GoogleFonts.inter(
        color: darkTextPrimary,
        fontSize: 14,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xxl),
        side: const BorderSide(color: darkBorder),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: darkTextPrimary,
      unselectedLabelColor: darkTextSecondary,
      indicatorColor: primary,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle:
          GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      dividerColor: Colors.transparent,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppColorsExtension(
        bg: darkBg,
        surface: darkSurface,
        surfaceAlt: darkSurfaceAlt,
        border: darkBorder,
        primary: primary,
        primaryLight: primaryLight,
        primaryGlow: primaryGlow,
        accent: accent,
        accentGlow: accentGlow,
        gold: gold,
        red: red,
        green: green,
        orange: orange,
        textPrimary: darkTextPrimary,
        textSecondary: darkTextSecondary,
        textMuted: darkTextMuted,
        shimmerBase: Color(0xFF1C1C27),
        shimmerHighlight: Color(0xFF2A2A3D),
      ),
    ],
  );

  // ─── Light Theme ────────────────────────────────────────────────────────────

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: lightBg,
    textTheme: _buildTextTheme(lightTextPrimary, lightTextSecondary),
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: lightSurface,
      error: red,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightTextPrimary,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: lightSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        color: lightTextPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: lightTextPrimary, size: 22),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: primary,
      unselectedItemColor: lightTextMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightSurface,
      contentTextStyle: GoogleFonts.inter(
        color: lightTextPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: const BorderSide(color: lightBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: lightBorder,
      thickness: 0.5,
      space: 0,
    ),
    inputDecorationTheme: _inputTheme(
      fillColor: lightSurfaceAlt,
      borderColor: lightBorder,
      focusedBorderColor: primary,
      textColor: lightTextPrimary,
      hintColor: lightTextMuted,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: lightBorder),
      ),
      textStyle: GoogleFonts.inter(
        color: lightTextPrimary,
        fontSize: 14,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xxl),
        side: const BorderSide(color: lightBorder),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: lightTextPrimary,
      unselectedLabelColor: lightTextSecondary,
      indicatorColor: primary,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle:
          GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      dividerColor: Colors.transparent,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppColorsExtension(
        bg: lightBg,
        surface: lightSurface,
        surfaceAlt: lightSurfaceAlt,
        border: lightBorder,
        primary: primary,
        primaryLight: primaryLight,
        primaryGlow: primaryGlow,
        accent: accent,
        accentGlow: accentGlow,
        gold: gold,
        red: red,
        green: green,
        orange: orange,
        textPrimary: lightTextPrimary,
        textSecondary: lightTextSecondary,
        textMuted: lightTextMuted,
        shimmerBase: Color(0xFFE8E8F0),
        shimmerHighlight: Color(0xFFF5F5FA),
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
  final Color primaryLight;
  final Color primaryGlow;
  final Color accent;
  final Color accentGlow;
  final Color gold;
  final Color red;
  final Color green;
  final Color orange;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppColorsExtension({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.primary,
    required this.primaryLight,
    required this.primaryGlow,
    required this.accent,
    required this.accentGlow,
    required this.gold,
    required this.red,
    required this.green,
    required this.orange,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? primary,
    Color? primaryLight,
    Color? primaryGlow,
    Color? accent,
    Color? accentGlow,
    Color? gold,
    Color? red,
    Color? green,
    Color? orange,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppColorsExtension(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryGlow: primaryGlow ?? this.primaryGlow,
      accent: accent ?? this.accent,
      accentGlow: accentGlow ?? this.accentGlow,
      gold: gold ?? this.gold,
      red: red ?? this.red,
      green: green ?? this.green,
      orange: orange ?? this.orange,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
      ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryGlow: Color.lerp(primaryGlow, other.primaryGlow, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      red: Color.lerp(red, other.red, t)!,
      green: Color.lerp(green, other.green, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }
}

// ─── BuildContext Helpers ─────────────────────────────────────────────────────

extension AppThemeContext on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
