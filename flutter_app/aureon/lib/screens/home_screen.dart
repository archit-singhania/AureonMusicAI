import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/generator_provider.dart';
import '../models/models.dart';
import '../widgets/genre_chip.dart';
import '../widgets/waveform_bar.dart';
import 'status_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _lyricsController = TextEditingController();
  final _api = ApiService();

  File? _beatFile;
  String _selectedGenre = 'rap';
  bool _isSubmitting = false;

  static const _genres = ['trap', 'drill', 'rap', 'rnb', 'pop'];

  Future<void> _pickBeat() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _beatFile = File(result.files.single.path!));
    }
  }

  Future<void> _generate() async {
    if (_beatFile == null) {
      _showSnack('Please upload a beat first.');
      return;
    }
    if (_lyricsController.text.trim().isEmpty) {
      _showSnack('Please enter your lyrics.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _api.generateSong(
        beatFile: _beatFile!,
        lyrics: _lyricsController.text.trim(),
        genre: _selectedGenre,
      );

      if (!mounted) return;

      final provider = context.read<GeneratorProvider>();
      provider.reset();
      provider.currentJobId = response.jobId;
      provider.pollStatus();

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StatusScreen()),
      );
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.music_note,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Aureon',
                    style: GoogleFonts.spaceMono(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  // History button
                  IconButton(
                    tooltip: 'History',
                    icon: const Icon(Icons.history_rounded,
                        color: Color(0xFF555577), size: 26),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const WaveformBar(),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                'AI Music Generator',
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFF6C63FF),
                  fontSize: 12,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 36),

              // ── Beat Upload ──────────────────────────────────────────────
              _SectionLabel(label: 'UPLOAD BEAT'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickBeat,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _beatFile != null
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFF111118),
                    border: Border.all(
                      color: _beatFile != null
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF2A2A3E),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF6C63FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _beatFile != null
                              ? Icons.audio_file
                              : Icons.upload_file,
                          color: const Color(0xFF6C63FF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _beatFile != null
                              ? _beatFile!.path.split('/').last
                              : 'Tap to upload beat (MP3, WAV, FLAC)',
                          style: GoogleFonts.spaceMono(
                            color: _beatFile != null
                                ? Colors.white
                                : const Color(0xFF555566),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_beatFile != null)
                        GestureDetector(
                          onTap: () => setState(() => _beatFile = null),
                          child: const Icon(Icons.close,
                              color: Color(0xFF555566), size: 18),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Genre Selector ───────────────────────────────────────────
              _SectionLabel(label: 'SELECT GENRE'),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _genres
                      .map((g) => GenreChip(
                            genre: g,
                            selected: _selectedGenre == g,
                            onTap: () =>
                                setState(() => _selectedGenre = g),
                          ))
                      .toList(),
                ),
              ),

              const SizedBox(height: 28),

              // ── Lyrics Input ─────────────────────────────────────────────
              _SectionLabel(label: 'YOUR LYRICS'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111118),
                  border: Border.all(
                      color: const Color(0xFF2A2A3E), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _lyricsController,
                  maxLines: 10,
                  style: GoogleFonts.spaceMono(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Paste your lyrics here...\n\nLine 1\nLine 2\nLine 3\n...',
                    hintStyle: GoogleFonts.spaceMono(
                      color: const Color(0xFF333344),
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.all(18),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Generate Button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _isSubmitting
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF6C63FF),
                                Color(0xFFFF6584)
                              ],
                            ),
                      color: _isSubmitting
                          ? const Color(0xFF2A2A3E)
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Color(0xFF6C63FF),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'GENERATE SONG',
                              style: GoogleFonts.spaceMono(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── History shortcut ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton.icon(
                  icon: const Icon(Icons.history_rounded,
                      size: 18, color: Color(0xFF444455)),
                  label: Text(
                    'VIEW PAST TRACKS',
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFF444455),
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HistoryScreen()),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.spaceMono(
        color: const Color(0xFF555577),
        fontSize: 11,
        letterSpacing: 3,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
