import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveformBar extends StatefulWidget {
  final Color color;
  final int barCount;
  final double height;
  final double width;

  const WaveformBar({
    super.key,
    this.color = const Color(0xFF6C63FF),
    this.barCount = 5,
    this.height = 28,
    this.width = 36,
  });

  @override
  State<WaveformBar> createState() => _WaveformBarState();
}

class _WaveformBarState extends State<WaveformBar>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.barCount, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + _rng.nextInt(400)),
      );
      controller.repeat(reverse: true);
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) controller.forward();
      });
      return controller;
    });

    _animations = _controllers.map((c) {
      return Tween<double>(
        begin: 0.15,
        end: 1.0,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = (widget.width - (widget.barCount - 1) * 3) / widget.barCount;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, __) {
              return Container(
                width: barWidth,
                height: widget.height * _animations[i].value,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.7 + _animations[i].value * 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
