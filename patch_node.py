import re

filepath = 'flutter_app/aureon/lib/widgets/node_graph_editor.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'glass_card.dart';" not in content:
    content = "import 'glass_card.dart';\n" + content

# Replace container of the whole graph with GlassCard
content = re.sub(r'Container\(\s*width: double\.infinity,\s*height: 300,\s*decoration: BoxDecoration\([\s\S]*?border: Border\.all[^\)]+\),\s*\),',
                 '''GlassCard(
      width: double.infinity,
      height: 300,
      borderRadius: 16,''', content)

# Replace the AudioNode container with GlassCard
content = re.sub(r'Container\(\s*padding: const EdgeInsets\.symmetric[^\)]+\),\s*decoration: BoxDecoration\([\s\S]*?boxShadow: \[[^\]]+\]\s*\),',
                 '''GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      blur: 15.0,
      color: PremiumTheme.neonCyan.withOpacity(0.05),''', content)

# Make the cables look like glowing neural synapses
cable_paint = '''    final glowPaint = Paint()
      ..color = PremiumTheme.neonCyan.withOpacity(0.4)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.stroke;

    final paint = Paint()
      ..color = PremiumTheme.neonCyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Synapse 1
    path.moveTo(140, 124);
    path.cubicTo(160, 124, 180, 64, 200, 64);
    
    // Synapse 2
    path.moveTo(140, 124);
    path.cubicTo(160, 124, 180, 184, 200, 184);

    // Synapse 3
    path.moveTo(310, 64);
    path.cubicTo(330, 64, 340, 124, 360, 124);
    
    // Synapse 4
    path.moveTo(310, 184);
    path.cubicTo(330, 184, 340, 124, 360, 124);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);'''

content = re.sub(r'final paint = Paint\(\)[\s\S]*?canvas\.drawPath\(path, paint\);', cable_paint, content)

with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
