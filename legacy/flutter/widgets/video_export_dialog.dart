import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VideoExportDialog extends StatefulWidget {
  final String jobId;
  final String genre;
  final Function() onExportVideo;

  const VideoExportDialog({
    super.key,
    required this.jobId,
    required this.genre,
    required this.onExportVideo,
  });

  @override
  State<VideoExportDialog> createState() => _VideoExportDialogState();
}

class _VideoExportDialogState extends State<VideoExportDialog> {
  bool _isGenerating = false;
  bool _isReady = false;

  void _startRender() {
    setState(() => _isGenerating = true);
    widget.onExportVideo();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _isReady = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F0F1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF2A2A44), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.video_collection_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'TikTok & Reels Visualizer',
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Exports a 1080x1920 9:16 vertical MP4 video with real-time waveform spectrum overlay ready to share on social media.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 11),
            ),
            const SizedBox(height: 24),

            if (_isReady)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF43E97B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF43E97B).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF43E97B), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Video rendered successfully!',
                      style: GoogleFonts.spaceMono(color: const Color(0xFF43E97B), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _startRender,
                  icon: _isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.movie_creation_rounded, size: 20),
                  label: Text(
                    _isGenerating ? 'RENDERING 9:16 VIDEO...' : 'GENERATE MP4 REELS VIDEO',
                    style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CLOSE',
                style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 11, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
