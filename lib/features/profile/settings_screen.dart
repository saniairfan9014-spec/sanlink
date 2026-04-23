import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionTitle(title: 'App Appearance'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                _ThemeOption(
                  title: 'System Default',
                  icon: Icons.brightness_auto_rounded,
                  mode: AppThemeMode.system,
                ),
                Divider(color: colors.border, height: 1),
                _ThemeOption(
                  title: 'Light Mode',
                  icon: Icons.light_mode_rounded,
                  mode: AppThemeMode.light,
                ),
                Divider(color: colors.border, height: 1),
                _ThemeOption(
                  title: 'Dark Mode',
                  icon: Icons.dark_mode_rounded,
                  mode: AppThemeMode.dark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final AppThemeMode mode;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.watch<AppThemeProvider>();
    final isSelected = provider.themeMode == mode;

    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<AppThemeProvider>().setThemeMode(mode);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withOpacity(0.1) : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? colors.primary : colors.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? colors.primary : colors.textPrimary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: colors.primary, size: 22)
          : null,
    );
  }
}
