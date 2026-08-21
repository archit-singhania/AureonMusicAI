import re

filepath = 'flutter_app/aureon/lib/screens/player_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

if 'glass_card.dart' not in content:
    content = "import '../widgets/glass_card.dart';\n" + content
if "import '../theme/premium_theme.dart';" not in content:
    content = "import '../theme/premium_theme.dart';\n" + content

# Replace background color inside Scaffold if there is one
content = content.replace('backgroundColor: const Color(0xFF0B0A1A),', 'backgroundColor: Colors.transparent,')

# Add radial gradient to Scaffold body
body_replacement = '''
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 1.2,
            colors: [PremiumTheme.deepSpace, PremiumTheme.abyssalBackground],
          ),
        ),
        child: SafeArea(
'''
content = content.replace('      body: SafeArea(', body_replacement)
content = content.replace('          ), // End of SafeArea', '          ),\n        ), // End of SafeArea\n      ), // End of Container')

# Make the player tabs GlassCards
content = re.sub(r'Container\(\s*padding: const EdgeInsets\.all\(14\),\s*decoration: BoxDecoration\(\s*color: const Color\(0xFF11111E\),\s*borderRadius: BorderRadius\.circular\(16\),\s*border: Border\.all\(color: const Color\(0xFF222238\)\),\s*\),', 
                 'GlassCard(\n                  borderRadius: 16,\n                  padding: const EdgeInsets.all(14),', content)

content = re.sub(r'Container\(\s*padding: const EdgeInsets\.all\(28\),\s*decoration: BoxDecoration\(\s*color: const Color\(0xFF11111E\),\s*borderRadius: BorderRadius\.circular\(20\),\s*border: Border\.all\(color: const Color\(0xFF222238\)\),\s*\),', 
                 'GlassCard(\n                    borderRadius: 20,\n                    padding: const EdgeInsets.all(28),', content)

content = content.replace('Color(0xFF6C63FF)', 'PremiumTheme.neonCyan')
content = content.replace('Color(0xFFFF6584)', 'PremiumTheme.neonMagenta')
content = content.replace('Color(0xFF38F9D7)', 'PremiumTheme.neonCyan')

with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
