import os

filepath = 'flutter_app/aureon/lib/screens/home_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

bad_block = '''              const SizedBox(height: 60), // Extra space for floating mic button\n\n            ],\n\n          ),\n\n        ),\n\n      ),\n\n    );\n\n  }\n\n}'''
good_block = '''              const SizedBox(height: 60), // Extra space for floating mic button\n\n            ],\n\n          ),\n\n        ),\n\n      ),\n\n      ),\n\n    );\n\n  }\n\n}'''

content = content.replace(bad_block, good_block)

with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
