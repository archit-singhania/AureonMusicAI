import 'dart:ui';
import 'package:flutter/material.dart';

/// A bounded glass interaction layer. Editing and analysis surfaces stay solid.
/// Pointer highlights repaint only this layer; there is no continuous animation.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 24,
    this.tint = const Color(0xFF7862B7),
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.highContrast = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color tint;
  final bool reduceTransparency, reduceMotion, highContrast;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  Alignment light = const Alignment(-.75, -.9);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final dark = theme.brightness == Brightness.dark;
    final contrast = widget.highContrast || media.highContrast;
    final solid = widget.reduceTransparency || contrast;
    final quiet = widget.reduceMotion || media.disableAnimations;
    final shape = BorderRadius.circular(widget.radius);
    final surface = theme.colorScheme.surface;
    final rim = contrast
        ? theme.colorScheme.onSurface.withValues(alpha: .65)
        : Colors.white.withValues(alpha: dark ? .26 : .72);
    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: solid
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  surface.withValues(alpha: dark ? .86 : .9),
                  Color.alphaBlend(
                    widget.tint.withValues(alpha: dark ? .12 : .035),
                    surface.withValues(alpha: dark ? .77 : .81),
                  ),
                ],
              ),
        color: solid ? surface : null,
        border: Border.all(color: rim, width: contrast ? 1.5 : .8),
      ),
      child: Stack(
        children: [
          if (!solid)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: shape,
                    gradient: RadialGradient(
                      center: light,
                      radius: 1.25,
                      colors: [
                        Colors.white.withValues(alpha: dark ? .10 : .32),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: widget.padding, child: widget.child),
        ],
      ),
    );
    return RepaintBoundary(
      child: MouseRegion(
        onHover: quiet || solid
            ? null
            : (event) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize || box.size.isEmpty) return;
                final point = box.globalToLocal(event.position);
                final next = Alignment(
                  (point.dx / box.size.width * 2 - 1).clamp(-1, 1),
                  (point.dy / box.size.height * 2 - 1).clamp(-1, 1),
                );
                if ((next.x - light.x).abs() + (next.y - light.y).abs() > .1) {
                  setState(() => light = next);
                }
              },
        onExit: quiet || solid
            ? null
            : (_) => setState(() => light = const Alignment(-.75, -.9)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .18 : .075),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: shape,
            child: solid
                ? body
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: body,
                  ),
          ),
        ),
      ),
    );
  }
}
