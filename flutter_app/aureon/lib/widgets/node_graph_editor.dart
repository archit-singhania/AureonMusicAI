import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';

class NodeGraphEditor extends StatelessWidget {
  const NodeGraphEditor({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: PremiumTheme.backgroundBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PremiumTheme.surfaceElevated),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PremiumTheme.accentNeonPurple),
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.accentNeonPurple.withOpacity(0.3),
            blurRadius: 10,
          )
        ]
      ),
      child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class CablePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PremiumTheme.accentNeonGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(140, 120);
    path.quadraticBezierTo(170, 60, 200, 60);
    
    path.moveTo(140, 120);
    path.quadraticBezierTo(170, 180, 200, 180);

    path.moveTo(300, 60);
    path.quadraticBezierTo(330, 120, 360, 120);
    
    path.moveTo(300, 180);
    path.quadraticBezierTo(330, 120, 360, 120);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
