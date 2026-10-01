import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SyllableCounterBar extends StatelessWidget {
  final String lyrics;
  final String genre;

  const SyllableCounterBar({
    super.key,
    required this.lyrics,
    required this.genre,
  });

  int _countSyllablesInWord(String word) {
    word = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (word.isEmpty) return 0;
    if (word.length <= 3) return 1;

    final vowels = RegExp(r'[aeiouy]+');
    final matches = vowels.allMatches(word);
    int count = matches.length;

    if (word.endsWith('e') && !word.endsWith('le') && count > 1) {
      count--;
    }
    return count > 0 ? count : 1;
  }

  int _countSyllablesInLine(String line) {
    final words = line.trim().split(RegExp(r'\s+'));
    return words.fold(0, (sum, w) => sum + _countSyllablesInWord(w));
  }

  @override
  Widget build(BuildContext context) {
    final lines = lyrics.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final totalLines = lines.length;
    final totalSyllables = lines.fold(0, (sum, l) => sum + _countSyllablesInLine(l));
    final avgSyllables = totalLines > 0 ? (totalSyllables / totalLines).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131322),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF222238)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: Color(0xFF6C63FF), size: 16),
              const SizedBox(width: 6),
              Text(
                'FLOW METER: ',
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFF8888AA),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '$totalLines Bars | $totalSyllables Syllables',
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Avg $avgSyllables / bar',
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF6C63FF),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
