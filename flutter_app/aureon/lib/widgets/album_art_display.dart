import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';

class AlbumArtDisplay extends StatelessWidget {
  final String jobId;
  const AlbumArtDisplay({Key? key, required this.jobId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: PremiumTheme.backgroundBlack,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.accentNeonPurple.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
        image: DecorationImage(
          image: NetworkImage('http://127.0.0.1:8000/outputs/covers/cover_$jobId.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "AI GENERATED ART",
                style: TextStyle(color: PremiumTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
          )
        ],
      ),
    );
  }
}
