import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CritiqueCard extends StatefulWidget {
  final Map<String, dynamic> critique;

  const CritiqueCard({super.key, required this.critique});

  @override
  State<CritiqueCard> createState() => _CritiqueCardState();
}

class _CritiqueCardState extends State<CritiqueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final score = (widget.critique['score'] as num?)?.toDouble() ?? 0.0;
    final onBeatRatio = (widget.critique['on_beat_ratio'] as num?)?.toDouble() ?? 0.0;
    final approved = widget.critique['approved'] as bool? ?? false;
    final issues = (widget.critique['issues'] as List?)?.cast<String>() ?? [];
    final overflowLines = (widget.critique['overflow_lines'] as List?)?.cast<int>() ?? [];

    final scoreColor = score >= 0.75
        ? const Color(0xFF43E97B)
        : score >= 0.5
            ? const Color(0xFFFFBE0B)
            : const Color(0xFFFF6584);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        border: Border.all(
          color: approved
              ? const Color(0xFF43E97B).withOpacity(0.3)
              : const Color(0xFFFF6584).withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    approved ? Icons.verified : Icons.warning_amber_rounded,
                    color: approved ? const Color(0xFF43E97B) : const Color(0xFFFF6584),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Critic: ${approved ? "Approved" : "Issues Found"}',
                      style: GoogleFonts.spaceMono(
                        color: approved ? const Color(0xFF43E97B) : const Color(0xFFFF6584),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Score badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scoreColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${(score * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.spaceMono(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF555577),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (_expanded) ...[
            const Divider(color: Color(0xFF1E1E2E), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        label: 'ON-BEAT',
                        value: '${(onBeatRatio * 100).toStringAsFixed(0)}%',
                        color: onBeatRatio >= 0.7
                            ? const Color(0xFF43E97B)
                            : const Color(0xFFFFBE0B),
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        label: 'OVERFLOW',
                        value: overflowLines.isEmpty
                            ? 'None'
                            : 'Lines ${overflowLines.join(", ")}',
                        color: overflowLines.isEmpty
                            ? const Color(0xFF43E97B)
                            : const Color(0xFFFF6584),
                      ),
                    ],
                  ),

                  if (issues.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'NOTES',
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFF555577),
                        fontSize: 9,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...issues.map(
                      (issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    color: Color(0xFF555577), fontSize: 13)),
                            Expanded(
                              child: Text(
                                issue,
                                style: GoogleFonts.spaceMono(
                                  color: const Color(0xFF888899),
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF555577),
                fontSize: 9,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.spaceMono(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
