import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StudioEffectsRack extends StatefulWidget {
  final String jobId;
  final Function(Map<String, double> params) onApplyEffects;

  const StudioEffectsRack({
    super.key,
    required this.jobId,
    required this.onApplyEffects,
  });

  @override
  State<StudioEffectsRack> createState() => _StudioEffectsRackState();
}

class _StudioEffectsRackState extends State<StudioEffectsRack> {
  double _saturation = 0.25;
  double _delayMs = 180.0;
  double _delayFeedback = 0.30;
  double _delayMix = 0.20;
  double _stereoWidth = 0.60;
  double _deEsser = 0.40;
  bool _isProcessing = false;

  void _triggerRemix() {
    setState(() => _isProcessing = true);
    widget.onApplyEffects({
      'saturation': _saturation,
      'delay_ms': _delayMs,
      'delay_feedback': _delayFeedback,
      'delay_mix': _delayMix,
      'stereo_width': _stereoWidth,
      'de_esser': _deEsser,
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF11111E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
                ),
                child: Text(
                  'DSP FX RACK',
                  style: GoogleFonts.spaceMono(
                    color: const Color(0xFF6C63FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Studio Mastering Hardware',
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Tape Saturation
          _buildKnobRow(
            title: 'TAPE SATURATION',
            value: _saturation,
            label: '${(_saturation * 100).toInt()}% Drive',
            color: const Color(0xFFFF6584),
            onChanged: (v) => setState(() => _saturation = v),
          ),

          // 2. Spatial Stereo Width
          _buildKnobRow(
            title: 'STEREO SPATIAL WIDTH',
            value: _stereoWidth,
            label: '${(_stereoWidth * 100).toInt()}% Width',
            color: const Color(0xFF38F9D7),
            onChanged: (v) => setState(() => _stereoWidth = v),
          ),

          // 3. Stereo Ping-Pong Delay Mix
          _buildKnobRow(
            title: 'PING-PONG DELAY',
            value: _delayMix,
            label: '${_delayMs.toInt()}ms | ${(_delayMix * 100).toInt()}%',
            color: const Color(0xFF6C63FF),
            onChanged: (v) => setState(() => _delayMix = v),
          ),

          // 4. Dynamic De-Esser
          _buildKnobRow(
            title: 'DYNAMIC DE-ESSER',
            value: _deEsser,
            label: '${(_deEsser * 100).toInt()}% Sibilance Cut',
            color: const Color(0xFFFFBE0B),
            onChanged: (v) => setState(() => _deEsser = v),
          ),

          const SizedBox(height: 12),

          // Apply FX Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _triggerRemix,
              icon: _isProcessing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.flash_on_rounded, size: 20),
              label: Text(
                _isProcessing ? 'RENDERING DSP FX...' : 'RE-MASTER TRACK',
                style: GoogleFonts.spaceMono(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnobRow({
    required String title,
    required double value,
    required String label,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: GoogleFonts.spaceMono(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: color,
              inactiveTrackColor: const Color(0xFF222238),
              thumbColor: color,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
