import os

filepath = 'flutter_app/aureon/lib/screens/player_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

bad_bottom = '''          ],\n\n        ),\n\n      ),\n\n      ),\n\n    );\n\n  }\n\n}'''
good_bottom = '''          ],\n\n        ),\n\n      ),\n\n    );\n\n  }\n\n}'''

content = content.replace(bad_bottom, good_bottom)

with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
