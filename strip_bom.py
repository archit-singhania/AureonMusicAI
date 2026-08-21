import os

def strip_bom(filepath):
    with open(filepath, 'rb') as f:
        content_bytes = f.read()
    if content_bytes.startswith(b'\xef\xbb\xbf'):
        content_bytes = content_bytes[3:]
    try:
        content = content_bytes.decode('utf-8')
    except:
        content = content_bytes.decode('latin1')
    with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)

strip_bom('flutter_app/aureon/lib/services/api_service.dart')
strip_bom('flutter_app/aureon/lib/services/signalr_service.dart')
strip_bom('flutter_app/aureon/lib/theme/premium_theme.dart')
