import 'dart:math';
import 'package:flutter/material.dart';

class SpectralVisualizer extends StatefulWidget {
  final bool isPlaying;
  final double height;
  final Color primaryColor;
  final Color secondaryColor;
  final int barCount;

  const SpectralVisualizer({
    super.key,
    required this.isPlaying,
    this.height = 80,
    this.primaryColor = const Color(0xFF6C63FF),
    this.secondaryColor = const Color(0xFFFF6584),
    this.barCount = 28,
  });

  @override
  State<SpectralVisualizer> createState() => _SpectralVisualizerState();
}

class _SpectralVisualizerState extends State<SpectralVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _rnd = Random();
  late List<double> _heightMultipliers;

  @override
  void initState() {
    super.initState();
    _heightMultipliers = List.generate(widget.barCount, (_) => 0.2 + _rnd.nextDouble() * 0.8);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(() {
        if (widget.isPlaying) {
          setState(() {
            for (int i = 0; i < _heightMultipliers.length; i++) {
              _heightMultipliers[i] = 0.15 + _rnd.nextDouble() * 0.85;
            }
          });
        }
      });

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpectralVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        setState(() {
          for (int i = 0; i < _heightMultipliers.length; i++) {
            _heightMultipliers[i] = 0.1;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (i) {
          final factor = widget.isPlaying ? _heightMultipliers[i] : 0.1;
          final barH = (widget.height * factor).clamp(4.0, widget.height);
          final t = i / widget.barCount;
          final barColor = Color.lerp(widget.primaryColor, widget.secondaryColor, t)!;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3.5,
            height: barH,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(4),
              boxShadow: widget.isPlaying
                  ? [
                      BoxShadow(
                        color: barColor.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}
