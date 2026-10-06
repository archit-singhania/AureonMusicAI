import 'package:flutter/material.dart';

/// Bounded motion: quick responses, a quiet arrival, then no idle ticker.
abstract final class StudioMotion {
  static const response = Duration(milliseconds: 140);
  static const arrival = Duration(milliseconds: 240);
  static const exit = Duration(milliseconds: 180);
  static const curve = Curves.easeOutCubic;

  static bool quiet(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
  static Duration duration(BuildContext context, Duration value) =>
      quiet(context) ? Duration.zero : value;

  static AnimationStyle sheet(BuildContext context) => AnimationStyle(
    duration: duration(context, arrival),
    reverseDuration: duration(context, exit),
  );

  static ChipAnimationStyle chip(BuildContext context) {
    final style = AnimationStyle(
      duration: duration(context, response),
      reverseDuration: duration(context, response),
    );
    return ChipAnimationStyle(
      enableAnimation: style,
      selectAnimation: style,
      avatarDrawerAnimation: style,
      deleteDrawerAnimation: style,
    );
  }
}

/// Keeps editors, search text and scroll state mounted across section changes.
/// Only the current section can paint, tick, receive focus or expose semantics.
class StudioSections extends StatefulWidget {
  const StudioSections({
    super.key,
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;

  @override
  State<StudioSections> createState() => _StudioSectionsState();
}

class _StudioSectionsState extends State<StudioSections>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: StudioMotion.arrival,
    value: 1,
  );
  late final CurvedAnimation eased = CurvedAnimation(
    parent: controller,
    curve: StudioMotion.curve,
  );
  final mountedSections = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (StudioMotion.quiet(context)) controller.value = 1;
  }

  @override
  void didUpdateWidget(StudioSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      if (StudioMotion.quiet(context)) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    eased.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    mountedSections.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: List.generate(widget.children.length, (index) {
        final active = index == widget.index;
        return TickerMode(
          enabled: active,
          child: ExcludeFocus(
            excluding: !active,
            child: ExcludeSemantics(
              excluding: !active,
              child: FadeTransition(
                opacity: eased,
                child: AnimatedBuilder(
                  animation: eased,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, (1 - eased.value) * 8),
                    child: child,
                  ),
                  child: mountedSections.contains(index)
                      ? widget.children[index]
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// One quiet entry per mounted surface. Replay only for a meaningful result.
class StudioEntrance extends StatefulWidget {
  const StudioEntrance({super.key, required this.child, this.replayKey});
  final Widget child;
  final Object? replayKey;

  @override
  State<StudioEntrance> createState() => _StudioEntranceState();
}

class _StudioEntranceState extends State<StudioEntrance>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: StudioMotion.arrival,
  );
  late final CurvedAnimation eased = CurvedAnimation(
    parent: controller,
    curve: StudioMotion.curve,
  );
  bool started = false;

  void arrive() {
    if (StudioMotion.quiet(context)) {
      controller.value = 1;
    } else {
      controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      arrive();
    } else if (StudioMotion.quiet(context)) {
      controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(StudioEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replayKey != oldWidget.replayKey) arrive();
  }

  @override
  void dispose() {
    eased.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: eased,
    child: AnimatedBuilder(
      animation: eased,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, (1 - eased.value) * 6),
        child: child,
      ),
      child: widget.child,
    ),
  );
}

/// Feedback belongs to the icon, keeping the button's identity and focus stable.
class StudioIconFeedback extends StatelessWidget {
  const StudioIconFeedback({
    super.key,
    required this.child,
    required this.value,
  });
  final Widget child;
  final Object value;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: StudioMotion.duration(context, StudioMotion.response),
    reverseDuration: StudioMotion.duration(context, StudioMotion.response),
    switchInCurve: StudioMotion.curve,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: .9, end: 1).animate(animation),
        child: child,
      ),
    ),
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.center,
      children: [
        ...previous.map(
          (child) => ExcludeSemantics(child: IgnorePointer(child: child)),
        ),
        ?current,
      ],
    ),
    child: KeyedSubtree(key: ValueKey(value), child: child),
  );
}
