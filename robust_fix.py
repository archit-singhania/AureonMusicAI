import os
import re

def fix_file(filepath, replacements):
    with open(filepath, 'rb') as f:
        content_bytes = f.read()
    
    # Strip any BOMs
    if content_bytes.startswith(b'\xef\xbb\xbf'):
        content_bytes = content_bytes[3:]
    elif content_bytes.startswith(b'\xff\xfe'):
        content_bytes = content_bytes[2:]
        content = content_bytes.decode('utf-16')
    elif content_bytes.startswith(b'\xfe\xff'):
        content_bytes = content_bytes[2:]
        content = content_bytes.decode('utf-16-be')
    else:
        try:
            content = content_bytes.decode('utf-8')
        except UnicodeDecodeError:
            content = content_bytes.decode('latin1')
            
    for old, new in replacements:
        if isinstance(old, re.Pattern):
            content = old.sub(new, content)
        else:
            content = content.replace(old, new)
            
    # Write back strictly as utf-8 without BOM
    with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)

fix_file('flutter_app/aureon/lib/screens/home_screen.dart', [])
fix_file('flutter_app/aureon/lib/screens/player_screen.dart', [
    (re.compile(r'Spectrogram3D\([^)]*\)'), 'Spectrogram3D()')
])

