import os
import codecs

def remove_bom_and_fix(filepath):
    with open(filepath, 'rb') as f:
        raw = f.read()
    if raw.startswith(codecs.BOM_UTF8):
        raw = raw[len(codecs.BOM_UTF8):]
    
    content = raw.decode('utf-8')
    
    if 'player_screen.dart' in filepath:
        content = content.replace('Spectrogram3D(audioPath: widget.audioPath, ', 'Spectrogram3D(')
    if 'premium_theme.dart' in filepath:
        content = content.replace('cardTheme: CardTheme(', 'cardTheme: const CardThemeData(')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

remove_bom_and_fix('flutter_app/aureon/lib/screens/home_screen.dart')
remove_bom_and_fix('flutter_app/aureon/lib/screens/player_screen.dart')
remove_bom_and_fix('flutter_app/aureon/lib/theme/premium_theme.dart')

