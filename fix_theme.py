filepath = 'flutter_app/aureon/lib/theme/premium_theme.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('cardTheme: const CardThemeData(', 'cardTheme: CardThemeData(')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
