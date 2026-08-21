import os

filepath = 'flutter_app/aureon/lib/screens/player_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

bad_block = '''      body: TabBarView(\n\n        controller: _tabController,'''
good_block = '''      body: Container(\n        decoration: const BoxDecoration(\n          gradient: RadialGradient(\n            center: Alignment(0.0, -0.2),\n            radius: 1.2,\n            colors: [PremiumTheme.deepSpace, PremiumTheme.abyssalBackground],\n          ),\n        ),\n        child: TabBarView(\n\n        controller: _tabController,'''

content = content.replace(bad_block, good_block)

bad_bottom = '''          ],\n\n        ),\n\n      ),\n\n    );\n\n  }\n\n}'''
good_bottom = '''          ],\n\n        ),\n\n      ),\n\n      ),\n\n    );\n\n  }\n\n}'''

content = content.replace(bad_bottom, good_bottom)

with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
