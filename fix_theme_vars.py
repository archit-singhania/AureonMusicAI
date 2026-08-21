import os

filepath = 'flutter_app/aureon/lib/theme/premium_theme.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

old_colors = '''
  static const Color abyssalBackground = Color(0xFF030308);
  static const Color deepSpace = Color(0xFF0B0A1A);
  static const Color neonCyan = Color(0xFF00FFD1);
  static const Color neonMagenta = Color(0xFFFF007F);
  static const Color glassWhite = Color(0x1AFFFFFF);
  
  // Legacy colors to prevent breaking other widgets
  static const Color backgroundBlack = Color(0xFF09090E);
  static const Color surfaceDark = Color(0xFF151522);
  static const Color surfaceElevated = Color(0xFF1E1E2E);
  static const Color accentNeonPurple = Color(0xFFB983FF);
  static const Color accentNeonGreen = Color(0xFF00FFC2);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFA0A0B0);
'''
content = content.replace('  static const Color abyssalBackground = Color(0xFF030308);\n  static const Color deepSpace = Color(0xFF0B0A1A);\n  static const Color neonCyan = Color(0xFF00FFD1);\n  static const Color neonMagenta = Color(0xFFFF007F);\n  static const Color glassWhite = Color(0x1AFFFFFF);', old_colors)

with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
