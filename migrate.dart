import 'dart:io';

void main() {
  final file = File('lib/features/home/home_screen.dart');
  String content = file.readAsStringSync();

  // Replace AppColors. with context.colors.
  content = content.replaceAll('AppColors.', 'context.colors.');
  
  // Remove class AppColors { ... }
  content = content.replaceAll(RegExp(r'class AppColors \{[\s\S]*?\}'), '''
extension ContextColors on BuildContext {
  AppColorsExtension get colors => Theme.of(this).extension<AppColorsExtension>()!;
}''');

  // Add the theme import if missing
  if (!content.contains('core/theme/app_theme.dart')) {
    content = content.replaceFirst('import \'package:flutter/material.dart\';', 
    'import \'package:flutter/material.dart\';\nimport \'../../core/theme/app_theme.dart\';');
  }

  // A simple regex to remove const from widgets that now have context.colors inside them
  // This is risky but we'll run flutter analyze after and fix remaining errors
  
  // Just remove ALL 'const ' before widgets/Text/Icon/BoxDecoration/Border/BorderSide/etc that we know have colors
  content = content.replaceAll(RegExp(r'const\s+(Text|Icon|BoxDecoration|Border|BorderSide|Container|Row|Column|SizedBox|Padding|LinearGradient|BoxShadow|TextStyle)'), r'\1');
  
  // also handle cases like const [ ... context.colors ... ]
  content = content.replaceAll('const [', '[');

  file.writeAsStringSync(content);
  print('Migration script ran.');
}
