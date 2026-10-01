import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

class ProgressStepper extends StatelessWidget {
  final String currentStatus;

  const ProgressStepper({super.key, required this.currentStatus});

  static const _steps = [
    (status: JobStatus.analyzing, label: 'Beat Analysis', icon: Icons.graphic_eq),
    (status: JobStatus.separatingStems, label: 'Stem Separation (Demucs)', icon: Icons.layers_rounded),
    (status: JobStatus.generatingFlow, label: 'AI Flow Engine', icon: Icons.auto_awesome),
    (status: JobStatus.synthesizing, label: 'Sarvam / Neural Vocal Gen', icon: Icons.record_voice_over),
    (status: JobStatus.correcting, label: 'Auto-Tune & Scale Pitch Lock', icon: Icons.tune),
    (status: JobStatus.mixing, label: 'Sidechain & -14 LUFS Mastering', icon: Icons.equalizer),
    (status: JobStatus.done, label: 'Studio Master Ready', icon: Icons.check_circle_outline),
  ];

  static const _statusOrder = [
    JobStatus.queued,
    JobStatus.analyzing,
    JobStatus.separatingStems,
    JobStatus.generatingFlow,
    JobStatus.synthesizing,
    JobStatus.correcting,
    JobStatus.mixing,
    JobStatus.done,
  ];

  int _currentIndex() {
    final idx = _statusOrder.indexOf(currentStatus);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _currentIndex();
    final isFailed = currentStatus == JobStatus.failed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REAL-TIME DSP PIPELINE',
          style: GoogleFonts.spaceMono(
            color: const Color(0xFF8888AA),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(_steps.length, (i) {
          final step = _steps[i];
          final stepOrderIdx = _statusOrder.indexOf(step.status);
          final isDone = stepOrderIdx < currentIdx;
          final isActive = step.status == currentStatus && !isFailed;
          final isFailedStep = isFailed && isActive;

          final color = isFailedStep
              ? const Color(0xFFFF4444)
              : isDone
                  ? const Color(0xFF43E97B)
                  : isActive
                      ? const Color(0xFF6C63FF)
                      : const Color(0xFF2A2A3E);

          final textColor = isDone
              ? const Color(0xFF43E97B)
              : isActive
                  ? Colors.white
                  : const Color(0xFF555566);

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(isDone || isActive ? 0.2 : 0.05),
                        border: Border.all(color: color, width: isDone || isActive ? 1.5 : 1),
                      ),
                      child: Icon(
                        isDone ? Icons.check : step.icon,
                        size: 16,
                        color: color,
                      ),
                    ),
                    if (i < _steps.length - 1)
                      Container(
                        width: 1.5,
                        height: 20,
                        color: isDone
                            ? const Color(0xFF43E97B).withOpacity(0.4)
                            : const Color(0xFF2A2A3E),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      children: [
                        Text(
                          step.label,
                          style: GoogleFonts.spaceMono(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isActive && !isFailed) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
