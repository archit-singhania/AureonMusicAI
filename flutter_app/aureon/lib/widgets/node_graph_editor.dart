import 'glass_card.dart';
import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';

class NodeGraphEditor extends StatelessWidget {
  const NodeGraphEditor({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      height: 300,
      borderRadius: 16,
      child: Stack(
        children: [
          // Simulated Cables
          CustomPaint(
            painter: CablePainter(),
            size: Size.infinite,
          ),
          // Nodes
          const Positioned(left: 40, top: 100, child: AudioNode(title: 'Vocal Stem')),
          const Positioned(left: 200, top: 40, child: AudioNode(title: 'Neural Denoise')),
          const Positioned(left: 200, top: 160, child: AudioNode(title: 'Vocoder')),
          const Positioned(left: 360, top: 100, child: AudioNode(title: 'Master Bus')),
        ],
      ),
    );
  }
}

class AudioNode extends StatelessWidget {
  final String title;
  const AudioNode({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      blur: 15.0,
      color: PremiumTheme.neonCyan.withOpacity(0.05),
      child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class CablePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
        final glowPaint = Paint()
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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
