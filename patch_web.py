import os
import re

def patch_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'package:flutter/foundation.dart' not in content:
        content = "import 'package:flutter/foundation.dart';\n" + content

    content = content.replace("Platform.isAndroid", "(kIsWeb ? false : Platform.isAndroid)")
    content = content.replace("Platform.pathSeparator", "('/')") # Safe fallback for string splits

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

patch_file('flutter_app/aureon/lib/services/api_service.dart')
patch_file('flutter_app/aureon/lib/services/signalr_service.dart')
patch_file('flutter_app/aureon/lib/screens/home_screen.dart')
