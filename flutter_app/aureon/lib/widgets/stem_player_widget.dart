import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

class StemPlayerWidget extends StatefulWidget {
  final Map<String, String> stemPaths; // vocals, drums, bass, other -> local path
  final Color accentColor;

  const StemPlayerWidget({
    super.key,
    required this.stemPaths,
    this.accentColor = const Color(0xFF6C63FF),
  });

  @override
  State<StemPlayerWidget> createState() => _StemPlayerWidgetState();
}

class _StemPlayerWidgetState extends State<StemPlayerWidget> {
  final Map<String, AudioPlayer> _stemPlayers = {};
  final Map<String, double> _volumes = {
    'vocals': 1.0,
    'drums': 0.85,
    'bass': 0.90,
    'other': 0.80,
  };
  final Map<String, bool> _muted = {
    'vocals': false,
    'drums': false,
    'bass': false,
    'other': false,
  };
  final Map<String, bool> _solo = {
    'vocals': false,
    'drums': false,
    'bass': false,
    'other': false,
  };

  double _playbackSpeed = 1.0;
  double _pitchShift = 0.0;
  bool _isPlaying = false;
  bool _isReady = false;

  final Map<String, Color> _stemColors = {
    'vocals': const Color(0xFFFF6584),
    'drums': const Color(0xFF43E97B),
    'bass': const Color(0xFF38F9D7),
    'other': const Color(0xFFFA709A),
  };

  @override
  void initState() {
    super.initState();
    _initStemPlayers();
  }

  Future<void> _initStemPlayers() async {
    try {
      for (final entry in widget.stemPaths.entries) {
        if (File(entry.value).existsSync()) {
          final p = AudioPlayer();
          await p.setFilePath(entry.value);
          await p.setVolume(_volumes[entry.key] ?? 1.0);
          _stemPlayers[entry.key] = p;
        }
      }
      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      debugPrint('[StemPlayer] Init error: $e');
    }
  }

  Future<void> _togglePlayAll() async {
    if (_stemPlayers.isEmpty) return;

    if (_isPlaying) {
      for (final p in _stemPlayers.values) {
        await p.pause();
      }
      setState(() => _isPlaying = false);
    } else {
      for (final p in _stemPlayers.values) {
        await p.seek(Duration.zero);
        p.play();
      }
      setState(() => _isPlaying = true);
    }
  }

  void _updateVolume(String stem, double val) {
    setState(() => _volumes[stem] = val);
    if (!_muted[stem]!) {
      _stemPlayers[stem]?.setVolume(val);
    }
  }

  void _toggleMute(String stem) {
    setState(() {
      _muted[stem] = !_muted[stem]!;
      if (_muted[stem]!) {
        _stemPlayers[stem]?.setVolume(0.0);
      } else {
        _stemPlayers[stem]?.setVolume(_volumes[stem] ?? 1.0);
      }
    });
  }

  void _toggleSolo(String stem) {
    setState(() {
      final nowSolo = !_solo[stem]!;
      _solo[stem] = nowSolo;

      final anySolo = _solo.values.any((s) => s);
      for (final sName in _stemPlayers.keys) {
        if (anySolo) {
          if (_solo[sName] == true) {
            _stemPlayers[sName]?.setVolume(_volumes[sName] ?? 1.0);
          } else {
            _stemPlayers[sName]?.setVolume(0.0);
          }
        } else {
          _stemPlayers[sName]?.setVolume(_muted[sName] == true ? 0.0 : (_volumes[sName] ?? 1.0));
        }
      }
    });
  }

  @override
  void dispose() {
    for (final p in _stemPlayers.values) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF11111E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A44), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.accentColor.withOpacity(0.4)),
                ),
                child: Text(
                  'MINI DAW',
                  style: GoogleFonts.spaceMono(
                    color: widget.accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '4-Stem Isolation Mixer',
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Stem play button
              IconButton(
                onPressed: _isReady ? _togglePlayAll : null,
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: widget.accentColor,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stem Sliders
          ...['vocals', 'drums', 'bass', 'other'].map((stemKey) {
            final color = _stemColors[stemKey] ?? Colors.white;
            final isMuted = _muted[stemKey] ?? false;
            final isSolo = _solo[stemKey] ?? false;
            final vol = _volumes[stemKey] ?? 1.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSolo
                        ? color
                        : isMuted
                            ? Colors.transparent
                            : const Color(0xFF1E1E30),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        stemKey.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Solo toggle
                    GestureDetector(
                      onTap: () => _toggleSolo(stemKey),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSolo ? color : const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'S',
                          style: TextStyle(
                            color: isSolo ? Colors.black : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Mute toggle
                    GestureDetector(
                      onTap: () => _toggleMute(stemKey),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isMuted ? const Color(0xFFFF6584) : const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'M',
                          style: TextStyle(
                            color: isMuted ? Colors.white : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Volume slider
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: color,
                          inactiveTrackColor: const Color(0xFF2A2A44),
                          thumbColor: color,
                        ),
                        child: Slider(
                          value: isMuted ? 0.0 : vol,
                          onChanged: (v) => _updateVolume(stemKey, v),
                        ),
                      ),
                    ),
                    Text(
                      '${((isMuted ? 0.0 : vol) * 100).toInt()}%',
                      style: GoogleFonts.spaceMono(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
