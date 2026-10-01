import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/api_service.dart';
import '../services/generator_provider.dart';
import '../models/models.dart';
import '../widgets/progress_stepper.dart';
import '../widgets/critique_card.dart';
import 'player_screen.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Studio Pipeline',
          style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<GeneratorProvider>(
        builder: (context, provider, _) {
          final status = provider.status;
          final jobId = provider.currentJobId;

          if (status == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SpinKitWave(
                    color: Color(0xFF6C63FF),
                    size: 40,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Connecting to DSP Engine...',
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFF8888AA),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          final isDone = status.status == JobStatus.done;
          final isFailed = status.status == JobStatus.failed;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        if (!isDone && !isFailed)
                          const SpinKitPulse(
                            color: Color(0xFF6C63FF),
                            size: 80,
                          )
                        else if (isDone)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFF43E97B)],
                              ),
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 40),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF4444).withOpacity(0.2),
                            ),
                            child: const Icon(Icons.error_outline, color: Color(0xFFFF4444), size: 40),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          status.statusLabel,
                          style: GoogleFonts.spaceMono(
                            color: isDone
                                ? const Color(0xFF43E97B)
                                : isFailed
                                    ? const Color(0xFFFF4444)
                                    : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Progress Bar
                  Text(
                    'DSP PIPELINE PROGRESS',
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFF8888AA),
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: status.progress / 100,
                      backgroundColor: const Color(0xFF1A1A2E),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDone ? const Color(0xFF43E97B) : const Color(0xFF6C63FF),
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${status.progress}%',
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFF6C63FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Step Tracker
                  ProgressStepper(currentStatus: status.status),

                  const SizedBox(height: 28),

                  // Critique Card
                  if (status.critique != null)
                    CritiqueCard(critique: status.critique!),

                  // Error
                  if (isFailed && (status.error != null || provider.errorMessage != null)) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4444).withOpacity(0.1),
                        border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFFF4444), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              status.error ?? provider.errorMessage ?? 'Unknown error',
                              style: GoogleFonts.spaceMono(
                                color: const Color(0xFFFF4444),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Done Actions
                  if (isDone && jobId != null) ...[
                    const SizedBox(height: 32),
                    _DoneActions(jobId: jobId),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DoneActions extends StatefulWidget {
  final String jobId;
  const _DoneActions({required this.jobId});

  @override
  State<_DoneActions> createState() => _DoneActionsState();
}

class _DoneActionsState extends State<_DoneActions> {
  bool _isDownloading = false;
  final _api = ApiService();

  Future<void> _downloadAndPlay() async {
    setState(() => _isDownloading = true);
    try {
      final downloadedPath = await _api.downloadSong(widget.jobId);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(audioPath: downloadedPath, jobId: widget.jobId),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isDownloading ? null : _downloadAndPlay,
            icon: _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 26),
            label: Text(
              _isDownloading ? 'PREPARING MASTER...' : 'OPEN IN STUDIO PLAYER',
              style: GoogleFonts.spaceMono(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2A2A3E)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'MAKE ANOTHER TRACK',
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF8888AA),
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
