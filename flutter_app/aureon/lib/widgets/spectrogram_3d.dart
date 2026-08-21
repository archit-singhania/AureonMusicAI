import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';
import 'dart:math';

class Spectrogram3D extends StatelessWidget {
  const Spectrogram3D({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: PremiumTheme.backgroundBlack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        painter: SpectrogramPainter(),
      ),
    );
  }
}

class SpectrogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PremiumTheme.accentNeonPurple.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final random = Random(42);
    for (int i = 0; i < size.width; i += 8) {
      double height = random.nextDouble() * size.height * 0.8;
      // Simulating a 3D perspective lean
      canvas.drawRect(
        Rect.fromLTWH(i.toDouble(), size.height - height, 4, height),
        paint..color = PremiumTheme.accentNeonPurple.withOpacity(0.2 + (height / size.height) * 0.8)
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
