import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MixingCopilotModal extends StatefulWidget {
  final Function(String instruction) onInstructionApplied;

  const MixingCopilotModal({
    super.key,
    required this.onInstructionApplied,
  });

  @override
  State<MixingCopilotModal> createState() => _MixingCopilotModalState();
}

class _MixingCopilotModalState extends State<MixingCopilotModal> {
  final _textController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      "sender": "ai",
      "text": "Hey! I'm your Aureon Studio Mixing Engineer. Tell me how you want your track tweaked (e.g., 'Make the bass punchier', 'Add vintage tape warmth', 'More Travis Scott autotune')."
    }
  ];

  final List<String> _quickSuggestions = [
    "Boost the 808 sub-bass by +2dB and widen stereo image",
    "Make the lead vocals more upfront and cut harsh sibilance",
    "Apply heavy robotic Travis Scott hard-tune",
    "Add lush dreamy reverb and warm analog tape saturation"
  ];

  void _sendPrompt(String prompt) {
    if (prompt.trim().isEmpty) return;
    setState(() {
      _messages.add({"sender": "user", "text": prompt});
      _messages.add({
        "sender": "ai",
        "text": "Understood! Adjusting DSP multiband EQ, sidechain parameters, and spatial effects rack now..."
      });
    });
    _textController.clear();
    widget.onInstructionApplied(prompt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D18),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF2A2A44), width: 1.5)),
      ),
      child: Column(
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
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF6C63FF), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Mixing Engineer Copilot',
                    style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Conversational Studio Producer',
                    style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Messages List
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final m = _messages[idx];
                final isAi = m["sender"] == "ai";
                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isAi ? const Color(0xFF161628) : const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(14),
                      border: isAi ? Border.all(color: const Color(0xFF222238)) : null,
                    ),
                    child: Text(
                      m["text"]!,
                      style: GoogleFonts.spaceMono(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick suggestions carousel
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickSuggestions.length,
              itemBuilder: (context, idx) {
                final s = _quickSuggestions[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: const Color(0xFF161628),
                    side: const BorderSide(color: Color(0xFF2A2A44)),
                    label: Text(
                      s,
                      style: GoogleFonts.spaceMono(color: const Color(0xFF38F9D7), fontSize: 10),
                    ),
                    onPressed: () => _sendPrompt(s),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Input field
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161628),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A2A44)),
                  ),
                  child: TextField(
                    controller: _textController,
                    style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Ask to adjust bass, autotune, reverb...',
                      hintStyle: GoogleFonts.spaceMono(color: const Color(0xFF555577), fontSize: 11),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: _sendPrompt,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _sendPrompt(_textController.text),
                icon: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
