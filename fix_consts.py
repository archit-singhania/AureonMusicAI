import os

def fix_const_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove invalid const before static variables
    content = content.replace('const PremiumTheme.neonCyan', 'PremiumTheme.neonCyan')
    content = content.replace('const PremiumTheme.neonMagenta', 'PremiumTheme.neonMagenta')
    content = content.replace('const PremiumTheme.deepSpace', 'PremiumTheme.deepSpace')
    content = content.replace('const PremiumTheme.abyssalBackground', 'PremiumTheme.abyssalBackground')

    with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)

fix_const_in_file('flutter_app/aureon/lib/screens/home_screen.dart')
fix_const_in_file('flutter_app/aureon/lib/screens/player_screen.dart')
