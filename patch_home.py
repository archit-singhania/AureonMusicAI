import re

filepath = 'flutter_app/aureon/lib/screens/home_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

if 'glass_card.dart' not in content:
    content = "import '../widgets/glass_card.dart';\n" + content
if "import '../theme/premium_theme.dart';" not in content:
    content = "import '../theme/premium_theme.dart';\n" + content

body_replacement = '''
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.6),
            radius: 1.5,
            colors: [PremiumTheme.deepSpace, PremiumTheme.abyssalBackground],
          ),
        ),
        child: SafeArea(
'''
content = content.replace('      body: SafeArea(', body_replacement)
content = content.replace('          ), // End of SafeArea', '          ),\n        ), // End of SafeArea\n      ), // End of Container')

content = re.sub(r'Container\(\s*padding: const EdgeInsets\.all\(20\),\s*decoration: BoxDecoration\(\s*color: const Color\(0xFF11111E\),\s*borderRadius: BorderRadius\.circular\(24\),\s*border: Border\.all\(color: const Color\(0xFF222238\)\),\s*\),', 
                 'GlassCard(\n                padding: const EdgeInsets.all(20),', content)

content = content.replace('Color(0xFF6C63FF)', 'PremiumTheme.neonCyan')
content = content.replace('Color(0xFFFF6584)', 'PremiumTheme.neonMagenta')
content = content.replace('Color(0xFF38F9D7)', 'PremiumTheme.neonCyan')
content = content.replace('Color(0xFF11111E)', 'PremiumTheme.deepSpace')

with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
