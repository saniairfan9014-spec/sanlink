import 'dart:io';

void main() {
  final file = File('lib/features/home/home_screen.dart');
  String content = file.readAsStringSync();

  // 1. Replace AppColors with Context colors
  content = content.replaceAll('AppColors.', 'context.colors.');
  
  // 2. Remove the old AppColors class
  content = content.replaceAll(RegExp(r'class AppColors \{[\s\S]*?\}'), '''
extension ContextColors on BuildContext {
  AppColorsExtension get colors => Theme.of(this).extension<AppColorsExtension>()!;
}''');

  // 3. Add imports
  if (!content.contains('core/theme/app_theme.dart')) {
    content = content.replaceFirst('import \'package:flutter/material.dart\';', 
    'import \'package:flutter/material.dart\';\nimport \'../../core/theme/app_theme.dart\';');
  }
  
  if (!content.contains('dart:io')) {
    content = content.replaceFirst('import \'package:flutter/material.dart\';', 
    'import \'dart:io\';\nimport \'package:flutter/material.dart\';');
  }

  // 4. Very carefully remove `const` only where `context.colors` is present.
  // Instead of simple replace, let's use a regex that matches `const` followed by a block of code
  // This is too hard. Let's just remove `const` keywords from the build methods entirely.
  // Actually, we can just replace `const ` with ` ` for all occurrences inside the widget classes, 
  // but keep it for things that don't depend on colors.
  
  // Let's just do a blanket replace of `const ` with ` ` except in standard places like `const Duration`, `const SizedBox`
  // Actually, let's just remove ALL `const ` and `const [` in the file! It's safe in Dart unless it's a default parameter.
  // Let's check if there are default parameters with `const`.
  // Looking at the file, default parameters are `this.initialCaption = ''`, `this.chatUnreadCount = 0` which don't use `const`.
  
  content = content.replaceAll(RegExp(r'\bconst\s+'), '');
  content = content.replaceAll(RegExp(r'\bconst\['), '[');
  content = content.replaceAll(RegExp(r'\bconst\('), '(');

  file.writeAsStringSync(content);
}
