import 'dart:io';

void main() {
  final file = File('lib/features/home/home_screen.dart');
  String content = file.readAsStringSync();

  // Remove the ContextColors extension since we import app_theme.dart which has it
  content = content.replaceAll(RegExp(r'extension ContextColors on BuildContext \{[\s\S]*?\}'), '');

  file.writeAsStringSync(content);
}
