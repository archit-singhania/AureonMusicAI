import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GenreChip extends StatelessWidget {
  final String genre;
  final bool selected;
  final VoidCallback onTap;

  const GenreChip({
    super.key,
    required this.genre,
    required this.selected,
    required this.onTap,
  });

  static const Map<String, Map<String, dynamic>> _genreMeta = {
    'trap': {'emoji': '🥶', 'color': Color(0xFF7B2FF7)},
    'drill': {'emoji': '🔩', 'color': Color(0xFF1A1A2E)},
    'rap': {'emoji': '🎤', 'color': Color(0xFF6C63FF)},
    'rnb': {'emoji': '🎶', 'color': Color(0xFFFF6584)},
    'pop': {'emoji': '✨', 'color': Color(0xFFFFBE0B)},
  };

  @override
  Widget build(BuildContext context) {
    final meta = _genreMeta[genre] ?? {'emoji': '🎵', 'color': const Color(0xFF6C63FF)};
    final color = meta['color'] as Color;
    final emoji = meta['emoji'] as String;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : const Color(0xFF111118),
          border: Border.all(
            color: selected ? color : const Color(0xFF2A2A3E),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              genre.toUpperCase(),
              style: GoogleFonts.spaceMono(
                color: selected ? color : const Color(0xFF555577),
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
