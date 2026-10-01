import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VoiceAssistantModal extends StatefulWidget {
  final Function(String transcript, String genre) onPromptApplied;

  const VoiceAssistantModal({
    super.key,
    required this.onPromptApplied,
  });

  @override
  State<VoiceAssistantModal> createState() => _VoiceAssistantModalState();
}

class _VoiceAssistantModalState extends State<VoiceAssistantModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isListening = true;
  String _selectedLang = 'en-IN';
  String _statusText = 'Listening to your musical idea...';

  final List<Map<String, String>> _voicePresets = [
    {"label": "English (IN)", "code": "en-IN"},
    {"label": "Hindi (हिंदी)", "code": "hi-IN"},
    {"label": "Punjabi (ਪੰਜਾਬੀ)", "code": "pa-IN"},
    {"label": "Tamil (தமிழ்)", "code": "ta-IN"},
  ];

  final List<String> _examplePrompts = [
    "Drop a dark London drill beat in C minor about late-night city streets",
    "Give me an energetic Hindi hip-hop flow with heavy 808s and fast rhymes",
    "Create a silky R&B track in A# minor with lush chords and autotuned hooks",
    "High-tempo cyberpunk synthwave with punchy kick and Travis Scott autotune",
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _applyPrompt(String prompt) {
    String inferredGenre = 'rap';
    final lower = prompt.toLowerCase();
    if (lower.contains('drill')) inferredGenre = 'drill';
    else if (lower.contains('trap') || lower.contains('808')) inferredGenre = 'trap';
    else if (lower.contains('r&b') || lower.contains('rnb') || lower.contains('silky')) inferredGenre = 'rnb';
    else if (lower.contains('pop') || lower.contains('synthwave')) inferredGenre = 'pop';

    widget.onPromptApplied(prompt, inferredGenre);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF2A2A44), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF33334D),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SARVAM AI',
                  style: GoogleFonts.spaceMono(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Studio Producer',
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Pulsing Glow Orb
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.18);
              final glowSpread = 10.0 + (_pulseController.value * 25.0);

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110 * scale,
                    height: 110 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.35),
                          blurRadius: glowSpread * 1.5,
                          spreadRadius: glowSpread,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF6584).withOpacity(0.25),
                          blurRadius: glowSpread * 2,
                          spreadRadius: glowSpread * 0.5,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6584), Color(0xFF38F9D7)],
                      ),
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          Text(
            _statusText,
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF8888AA),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 20),

          // Language Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _voicePresets.map((vp) {
                final isSelected = _selectedLang == vp["code"];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(vp["label"]!),
                    labelStyle: GoogleFonts.spaceMono(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 11,
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6C63FF),
                    backgroundColor: const Color(0xFF1A1A2E),
                    onSelected: (val) {
                      if (val) setState(() => _selectedLang = vp["code"]!);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Musical Inspirations
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'OR TAP A MUSICAL PROMPT:',
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF555577),
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),

          ..._examplePrompts.map((prompt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _applyPrompt(prompt),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151524),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF24243B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            prompt,
                            style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
