import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/waveform_bar.dart';

class PlayerScreen extends StatefulWidget {
  final String audioPath;
  final String jobId;

  const PlayerScreen({
    super.key,
    required this.audioPath,
    required this.jobId,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  late final AnimationController _pulseController;

  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int _userRating = 0; // 0 = unrated, 1-5 stars
  bool _ratingSaved = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _initPlayer();
    _loadExistingRating();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setFilePath(widget.audioPath);
      setState(() {
        _isLoading = false;
        _duration = _player.duration ?? Duration.zero;
      });

      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });

      _player.durationStream.listen((dur) {
        if (mounted && dur != null) setState(() => _duration = dur);
      });

      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
          if (state.processingState == ProcessingState.completed) {
            _player.seek(Duration.zero);
            _player.pause();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load audio: $e')),
        );
      }
    }
  }

  Future<void> _loadExistingRating() async {
    final prefs = await SharedPreferences.getInstance();
    final rating = prefs.getInt('rating_${widget.jobId}') ?? 0;
    if (mounted) setState(() => _userRating = rating);
  }

  Future<void> _saveRating(int rating) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rating_${widget.jobId}', rating);
    // Also save job metadata for Phase 6 feedback dataset
    final existing = prefs.getStringList('job_history') ?? [];
    if (!existing.contains(widget.jobId)) {
      existing.add(widget.jobId);
      await prefs.setStringList('job_history', existing);
    }
    await prefs.setString(
        'job_meta_${widget.jobId}',
        '{"jobId":"${widget.jobId}","rating":$rating,'
        '"timestamp":"${DateTime.now().toIso8601String()}",'
        '"path":"${widget.audioPath}"}');

    setState(() {
      _userRating = rating;
      _ratingSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_ratingLabel(rating)} — saved to your history',
          style: GoogleFonts.spaceMono(fontSize: 12),
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1:
        return '⭐ Needs work';
      case 2:
        return '⭐⭐ Getting there';
      case 3:
        return '⭐⭐⭐ Decent';
      case 4:
        return '⭐⭐⭐⭐ Solid!';
      case 5:
        return '⭐⭐⭐⭐⭐ Fire 🔥';
      default:
        return 'Rated';
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seekTo(double value) async {
    final target = Duration(milliseconds: value.toInt());
    await _player.seek(target);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'YOUR TRACK',
          style: GoogleFonts.spaceMono(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Album art placeholder with animated waveform
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.music_note,
                      color: Color(0xFF6C63FF),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    if (_isPlaying)
                      WaveformBar(
                        color: const Color(0xFF6C63FF),
                        barCount: 7,
                        height: 36,
                        width: 70,
                      )
                    else
                      Text(
                        'AUREON',
                        style: GoogleFonts.spaceMono(
                          color: const Color(0xFF6C63FF),
                          fontSize: 14,
                          letterSpacing: 4,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Track info
              Text(
                'Generated Track',
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.jobId.substring(0, 8).toUpperCase(),
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFF555577),
                  fontSize: 11,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 36),

              // Progress slider
              if (_isLoading)
                const LinearProgressIndicator(
                  color: Color(0xFF6C63FF),
                  backgroundColor: Color(0xFF1A1A2E),
                )
              else ...[
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF6C63FF),
                    inactiveTrackColor: const Color(0xFF1A1A2E),
                    thumbColor: const Color(0xFF6C63FF),
                    overlayColor: const Color(0xFF6C63FF).withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds
                        .clamp(0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1)
                        .toDouble(),
                    max: _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    onChanged: _seekTo,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: GoogleFonts.spaceMono(
                          color: const Color(0xFF555577),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: GoogleFonts.spaceMono(
                          color: const Color(0xFF555577),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Controls row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Color(0xFF555577)),
                    iconSize: 32,
                    onPressed: () {
                      final target =
                          _position - const Duration(seconds: 10);
                      _player.seek(target < Duration.zero ? Duration.zero : target);
                    },
                  ),
                  const SizedBox(width: 16),

                  // Play/Pause
                  GestureDetector(
                    onTap: _isLoading ? null : _togglePlay,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 34,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Forward
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: Color(0xFF555577)),
                    iconSize: 32,
                    onPressed: () {
                      final target = _position + const Duration(seconds: 10);
                      _player.seek(target > _duration ? _duration : target);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Rating — Phase 6 feedback loop
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111118),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Column(
                  children: [
                    Text(
                      'RATE THIS TRACK',
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFF555577),
                        fontSize: 10,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        return GestureDetector(
                          onTap: () => _saveRating(star),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                star <= _userRating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                key: ValueKey('star_${star}_$_userRating'),
                                color: star <= _userRating
                                    ? const Color(0xFFFFBE0B)
                                    : const Color(0xFF333344),
                                size: 36,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    if (_userRating > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        _ratingLabel(_userRating),
                        style: GoogleFonts.spaceMono(
                          color: const Color(0xFFFFBE0B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share, size: 18),
                      label: Text(
                        'SHARE',
                        style: GoogleFonts.spaceMono(fontSize: 11, letterSpacing: 1.5),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share coming soon!')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C63FF),
                        side: const BorderSide(color: Color(0xFF2A2A3E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        'SAVE',
                        style: GoogleFonts.spaceMono(fontSize: 11, letterSpacing: 1.5),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Saved to: ${widget.audioPath.split('/').last}',
                              style: GoogleFonts.spaceMono(fontSize: 11),
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF43E97B),
                        side: const BorderSide(color: Color(0xFF2A2A3E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
