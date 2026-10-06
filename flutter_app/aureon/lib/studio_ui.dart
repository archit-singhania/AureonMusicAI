import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'studio_model.dart';
import 'liquid_glass.dart';

const violet = Color(0xFF7862B7);
const peach = Color(0xFFE1AE96);
Color statusGreen(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFA3D9B7)
    : const Color(0xFF286147);

class AureonApp extends StatelessWidget {
  const AureonApp({super.key});
  static ThemeData theme(Brightness brightness, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    var scheme = ColorScheme.fromSeed(
      seedColor: violet,
      brightness: brightness,
      surface: dark ? const Color(0xFF22242C) : const Color(0xFFFAF9F6),
    );
    if (highContrast) {
      scheme = scheme.copyWith(
        onSurface: dark ? Colors.white : const Color(0xFF111117),
        outline: dark ? const Color(0xFFCFCDD7) : const Color(0xFF4C4657),
      );
    }
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF15171E)
          : const Color(0xFFF2F1ED),
      fontFamily: 'Inter',
      textTheme: ThemeData(brightness: brightness).textTheme.copyWith(
        displayLarge: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w600,
          letterSpacing: -2.6,
          color: scheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.5,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -.5,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: scheme.onSurface,
        ),
        labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ).apply(fontFamily: 'Inter'),
      dividerColor: scheme.outline.withValues(alpha: .14),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface.withValues(alpha: .75),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: .2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: .2)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<StudioModel>();
    return MaterialApp(
      title: 'Aureon · Your sound, considered',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light, highContrast: model.highContrast),
      darkTheme: theme(Brightness.dark, highContrast: model.highContrast),
      highContrastTheme: theme(Brightness.light, highContrast: true),
      highContrastDarkTheme: theme(Brightness.dark, highContrast: true),
      themeMode: model.themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              model.reduceMotion || MediaQuery.of(context).disableAnimations,
          highContrast:
              model.highContrast || MediaQuery.of(context).highContrast,
        ),
        child: child!,
      ),
      home: const StudioShell(),
    );
  }
}

class StudioShell extends StatelessWidget {
  const StudioShell({super.key});
  static const names = [
    'Studio',
    'Library',
    'Discover',
    'Activity',
    'Settings',
  ];
  static const icons = [
    Icons.graphic_eq_rounded,
    Icons.library_music_outlined,
    Icons.explore_outlined,
    Icons.bolt_outlined,
    Icons.tune_rounded,
  ];
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final roomyRail =
        MediaQuery.sizeOf(context).height >= 850 &&
        MediaQuery.textScalerOf(context).scale(14) <= 18;
    final page = [
      const StudioPage(),
      const LibraryPage(),
      const DiscoverPage(),
      const ActivityPage(),
      const SettingsPage(),
    ][m.destination];
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (m.master != null) m.togglePlay();
              return null;
            },
          ),
        },
        child: Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [
                        const Color(0xFF20202B),
                        const Color(0xFF15171E),
                        const Color(0xFF23232E),
                      ]
                    : [
                        const Color(0xFFF0EDF4),
                        const Color(0xFFF4F3EF),
                        const Color(0xFFF5EEE8),
                      ],
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (wide)
                    Container(
                      width: 236,
                      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                      child: Panel(
                        glass: true,
                        padding: const EdgeInsets.fromLTRB(24, 26, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Brand(),
                            SizedBox(height: roomyRail ? 44 : 24),
                            Text('WORKSPACE', style: label(context)),
                            const SizedBox(height: 14),
                            ...List.generate(
                              5,
                              (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: NavItem(
                                  name: names[i],
                                  icon: icons[i],
                                  selected: m.destination == i,
                                  onTap: () {
                                    m.destination = i;
                                    m.changed();
                                  },
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (roomyRail)
                              Panel(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_outlined,
                                      color: violet,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'A little room to create.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'From the first spark to the final master.',
                                      style: muted(context),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      m.online
                                          ? 'Studio connected'
                                          : 'Waiting for studio',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: m.online
                                            ? statusGreen(context)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              'AUREON  /  MUSIC STUDIO',
                              style: label(
                                context,
                              ).copyWith(fontSize: 10, letterSpacing: 1.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 20 : 20,
                            18,
                            wide ? 34 : 20,
                            14,
                          ),
                          child: Row(
                            children: [
                              if (!wide)
                                const Expanded(child: Brand(compact: true)),
                              if (wide)
                                Text(
                                  names[m.destination],
                                  style: muted(context),
                                ),
                              if (wide) const Spacer(),
                              if (m.current != null && wide)
                                Padding(
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Text(
                                    m.saveStatus,
                                    style: muted(
                                      context,
                                    ).copyWith(fontSize: 12),
                                  ),
                                ),
                              Tooltip(
                                message: 'Appearance',
                                child: IconButton(
                                  onPressed: () => m.settings(
                                    theme: m.themeMode == ThemeMode.dark
                                        ? ThemeMode.light
                                        : ThemeMode.dark,
                                  ),
                                  icon: Icon(
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Icons.light_mode_outlined
                                        : Icons.dark_mode_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!wide)
                                IconButton(
                                  tooltip: m.authenticated
                                      ? 'Your account'
                                      : 'Sign in',
                                  onPressed: () => accountSheet(context),
                                  icon: const Icon(Icons.person_outline),
                                )
                              else if (m.authenticated)
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.person_outline,
                                    size: 16,
                                  ),
                                  label: Text(m.account?['name'] ?? 'Creator'),
                                  onPressed: () => accountSheet(context),
                                )
                              else
                                OutlinedButton(
                                  onPressed: () => accountSheet(context),
                                  child: const Text('Sign in'),
                                ),
                            ],
                          ),
                        ),
                        if (m.error.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18),
                                const SizedBox(width: 12),
                                Expanded(child: Text(m.error)),
                                IconButton(
                                  tooltip: 'Dismiss message',
                                  onPressed: () {
                                    m.error = '';
                                    m.changed();
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                          ),
                        if (m.busy) const LinearProgressIndicator(minHeight: 2),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: Duration(
                              milliseconds:
                                  MediaQuery.of(context).disableAnimations
                                  ? 0
                                  : 260,
                            ),
                            child: KeyedSubtree(
                              key: ValueKey(m.destination),
                              child: page,
                            ),
                          ),
                        ),
                        if (m.master != null || m.previewing) const Transport(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Panel(
                    glass: true,
                    padding: EdgeInsets.zero,
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      height: 76,
                      indicatorColor: violet.withValues(alpha: .17),
                      selectedIndex: m.destination,
                      onDestinationSelected: (i) {
                        m.destination = i;
                        m.changed();
                      },
                      destinations: List.generate(
                        5,
                        (i) => NavigationDestination(
                          icon: Icon(icons[i]),
                          label: names[i],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

TextStyle muted(BuildContext context) => TextStyle(
  color: Theme.of(context).colorScheme.onSurface.withValues(
    alpha: MediaQuery.of(context).highContrast ? .9 : .72,
  ),
  fontSize: 13,
  height: 1.5,
);
TextStyle label(BuildContext context) => muted(
  context,
).copyWith(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.6);

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.glass = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool glass;
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final theme = Theme.of(context);
    if (glass) {
      return LiquidGlass(
        padding: padding,
        reduceTransparency: m.reduceTransparency,
        reduceMotion: m.reduceMotion,
        highContrast: m.highContrast,
        child: Material(type: MaterialType.transparency, child: child),
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: MediaQuery.of(context).highContrast ? .7 : .14,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? .06 : .025,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        label: 'Aureon soundwave monogram',
        image: true,
        child: Container(
          width: compact ? 34 : 42,
          height: compact ? 34 : 42,
          decoration: BoxDecoration(
            color: violet,
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.all(7),
          child: CustomPaint(painter: MarkPainter(Colors.white)),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'aureon',
            style: TextStyle(
              fontSize: compact ? 22 : 27,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.2,
            ),
          ),
        ),
      ),
    ],
  );
}

class MarkPainter extends CustomPainter {
  MarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = size.width * .065
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .1, size.height * .88)
        ..lineTo(size.width * .5, size.height * .12)
        ..lineTo(size.width * .9, size.height * .88),
      p,
    );
    for (var i = 0; i < 4; i++) {
      final x = size.width * (.33 + i * .12),
          h = [.16, .29, .4, .22][i] * size.height;
      canvas.drawLine(
        Offset(x, size.height * .8 - h),
        Offset(x, size.height * .8),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(MarkPainter old) => old.color != color;
}

class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.name,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: AnimatedContainer(
      duration: Duration(
        milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 150,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: selected
            ? LinearGradient(
                colors: [
                  violet.withValues(alpha: .18),
                  violet.withValues(alpha: .07),
                ],
              )
            : null,
        border: Border.all(
          color: selected ? violet.withValues(alpha: .25) : Colors.transparent,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .72),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                if (selected) ...[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: violet,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading({super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: muted(context)),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class StudioPage extends StatelessWidget {
  const StudioPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    if (m.current == null) return const WelcomePage();
    return LayoutBuilder(
      builder: (context, constraints) {
        final large = constraints.maxWidth >= 1000;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            large ? 20 : 20,
            12,
            large ? 34 : 20,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, header) {
                  final title = Editor(
                    value: m.title,
                    onChanged: (v) => m.edit('title', v),
                    style: Theme.of(context).textTheme.displayMedium,
                    label: 'Session title',
                    borderless: true,
                  );
                  final actions = [
                    Tooltip(
                      message: 'Version history',
                      child: IconButton(
                        onPressed: () => versionSheet(context),
                        icon: const Icon(Icons.history_rounded),
                      ),
                    ),
                    Tooltip(
                      message: 'Invite a collaborator',
                      child: IconButton(
                        onPressed: () => collaborationSheet(context),
                        icon: const Icon(Icons.group_add_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: m.busy || m.rendering
                          ? null
                          : () => m.generate(),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(m.rendering ? 'Rendering…' : 'Create master'),
                    ),
                  ];
                  if (header.maxWidth < 620) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 10),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: actions,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      ...actions,
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    '${m.current!['genre'].toString().toUpperCase()}  ·  ${m.current!['bpm']} BPM  ·  ${m.current!['key']}',
                    style: muted(context),
                  ),
                  Text(
                    '● ${m.liveStatus}',
                    style: TextStyle(fontSize: 12, color: statusGreen(context)),
                  ),
                  TextButton.icon(
                    onPressed: !m.busy && (m.canUndo || m.dirty)
                        ? () => m.navigateHistory('undo')
                        : null,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Undo'),
                  ),
                  TextButton.icon(
                    onPressed: !m.busy && m.canRedo && !m.dirty
                        ? () => m.navigateHistory('redo')
                        : null,
                    icon: const Icon(Icons.redo, size: 16),
                    label: const Text('Redo'),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              if (large)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          const SourcePanel(),
                          const SizedBox(height: 20),
                          const LyricsPanel(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          const MasterPanel(),
                          const SizedBox(height: 20),
                          const MixerPanel(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    const SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          InspectorPanel(),
                          SizedBox(height: 20),
                          ArtworkPanel(),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const MasterPanel(),
                    const SizedBox(height: 20),
                    const SourcePanel(),
                    const SizedBox(height: 20),
                    const LyricsPanel(),
                    const SizedBox(height: 20),
                    const MixerPanel(),
                    const SizedBox(height: 20),
                    const InspectorPanel(),
                    const SizedBox(height: 20),
                    const ArtworkPanel(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Panel(
            padding: const EdgeInsets.all(34),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 680;
                return Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR SOUND, CONSIDERED.',
                            style: label(context).copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Make room\nfor your sound.',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontSize: wide ? 60 : 42,
                                  height: 1.06,
                                ),
                          ),
                          const SizedBox(height: 20),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(
                              'A calm, capable studio for your next idea. Compose a beat, shape every stem, and take something beautiful into the world.',
                              style: muted(
                                context,
                              ).copyWith(fontSize: 15, height: 1.7),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: m.busy
                                    ? null
                                    : m.authenticated
                                    ? m.createProject
                                    : m.demo,
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  m.authenticated
                                      ? 'Start a session'
                                      : 'Try the studio',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => accountSheet(context),
                                icon: const Icon(
                                  Icons.person_outline,
                                  size: 17,
                                ),
                                label: Text(
                                  m.authenticated
                                      ? 'Your account'
                                      : 'Create an account',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Real audio. Your own workspace. A fresh start.',
                            style: label(
                              context,
                            ).copyWith(letterSpacing: .2, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (wide) ...[
                      const SizedBox(width: 30),
                      Expanded(
                        flex: 4,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const RadialGradient(
                                center: Alignment(.3, -.5),
                                radius: 1.1,
                                colors: [
                                  Color(0xFFD8C7F0),
                                  Color(0xFFAD96D0),
                                  Color(0xFF625680),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(70),
                            child: CustomPaint(
                              painter: MarkPainter(const Color(0xFFFCF5EB)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          const Heading(
            title: 'Find your starting point',
            subtitle:
                'Original algorithmic instruments. Preview a mood, then make it yours.',
          ),
          PresetGrid(
            onSelect: (p) async {
              if (!m.authenticated) {
                await m.demo();
              } else if (m.current == null) {
                await m.createProject();
              }
              if (m.current != null) {
                m.edit('preset_id', p['id']);
                m.edit('bpm', p['bpm']);
                m.edit('key', p['key']);
                m.edit('genre', p['genre']);
                m.edit('beat_asset_id', null);
              }
            },
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, c) {
              final cards = [
                feature(
                  context,
                  Icons.layers_outlined,
                  'Every layer, yours',
                  'Compose and mix four instrument stems.',
                ),
                feature(
                  context,
                  Icons.waves_rounded,
                  'Hear the difference',
                  'Measured waveforms, spectrum and loudness.',
                ),
                feature(
                  context,
                  Icons.ios_share_rounded,
                  'Made to leave the studio',
                  'WAV, MP3, stem packs and visualizer video.',
                ),
              ];
              return c.maxWidth > 780
                  ? Row(
                      children: cards
                          .map(
                            (w) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: w,
                              ),
                            ),
                          )
                          .toList(),
                    )
                  : Column(
                      children: cards
                          .map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: w,
                            ),
                          )
                          .toList(),
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget feature(
    BuildContext context,
    IconData icon,
    String title,
    String text,
  ) => Panel(
    padding: const EdgeInsets.all(22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: violet, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(text, style: muted(context)),
            ],
          ),
        ),
      ],
    ),
  );
}

class PresetGrid extends StatelessWidget {
  const PresetGrid({super.key, required this.onSelect});
  final void Function(Json) onSelect;
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    if (m.presets.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Connect your studio',
        text:
            'Start the Aureon service to browse and preview your instruments.',
        action: OutlinedButton(
          onPressed: () => m.guard(m.refreshPublic),
          child: const Text('Reconnect'),
        ),
      );
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: m.presets
          .map(
            (p) => SizedBox(
              width: 190,
              child: Panel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 94,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(
                            p['color'].toString().replaceFirst('#', 'FF'),
                            radix: 16,
                          ),
                        ).withValues(alpha: .23),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Center(
                        child: IconButton(
                          tooltip: 'Preview ${p['title']}',
                          onPressed: () => m.preview(p),
                          icon: const Icon(Icons.play_circle_outline, size: 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      p['title'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p['bpm']} BPM · ${p['key']}',
                      style: muted(context).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => onSelect(p),
                        child: const Text('Use this mood'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class SourcePanel extends StatelessWidget {
  const SourcePanel({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Heading(
            title: 'The starting point',
            subtitle: 'A mood, a beat, or something of your own.',
          ),
          DropdownButtonFormField<String>(
            initialValue: m.current!['preset_id'],
            decoration: const InputDecoration(labelText: 'Instrument preset'),
            items: m.presets
                .map(
                  (p) => DropdownMenuItem(
                    value: p['id'] as String,
                    child: Text(p['title']),
                  ),
                )
                .toList(),
            onChanged: (v) {
              final p = m.presets.firstWhere((p) => p['id'] == v);
              m.edit('preset_id', v);
              m.edit('beat_asset_id', null);
              m.edit('bpm', p['bpm']);
              m.edit('key', p['key']);
              m.edit('genre', p['genre']);
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => m.pickAsset('beat_asset_id'),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(
              m.current!['beat_asset_id'] == null
                  ? 'Import a beat'
                  : 'Replace imported beat',
            ),
          ),
          if (m.current!['beat_asset_id'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Imported audio · choose a separation engine below',
              style: muted(context).copyWith(fontSize: 11),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Editor(
                  value: '${m.current!['bpm']}',
                  label: 'BPM',
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null && n >= 40 && n <= 220) m.edit('bpm', n);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Editor(
                  value: m.current!['key'],
                  label: 'Key / scale',
                  onChanged: (v) {
                    if (RegExp(r'^[A-G]#? (major|minor)$').hasMatch(v)) {
                      m.edit('key', v);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('VOCAL SOURCE', style: label(context)),
          const SizedBox(height: 16),
          const EditableBeatGrid(),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: m.current!['separation_engine'] ?? 'spectral-dsp',
            decoration: const InputDecoration(
              labelText: 'Imported separation engine',
            ),
            items: [
              const DropdownMenuItem(
                value: 'spectral-dsp',
                child: Text('Approximate spectral DSP'),
              ),
              DropdownMenuItem(
                value: 'demucs',
                enabled: m.capabilities['demucs'] == true,
                child: Text(
                  m.capabilities['demucs'] == true
                      ? 'Demucs · genuine neural four stems'
                      : 'Demucs · optional engine not installed',
                ),
              ),
            ],
            onChanged: (v) => m.edit('separation_engine', v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: m.current!['engine'],
            decoration: const InputDecoration(labelText: 'Voice mode'),
            items: [
              const DropdownMenuItem(
                value: 'instrumental',
                child: Text('Instrumental composition'),
              ),
              const DropdownMenuItem(
                value: 'recording',
                child: Text('My voice recording'),
              ),
              DropdownMenuItem(
                value: 'sarvam',
                enabled: m.capabilities['sarvam'] == true,
                child: Text(
                  m.capabilities['sarvam'] == true
                      ? 'Sarvam speech synthesis'
                      : 'Sarvam · not configured',
                ),
              ),
              DropdownMenuItem(
                value: 'xtts',
                enabled: m.capabilities['xtts'] == true,
                child: Text(
                  m.capabilities['xtts'] == true
                      ? 'Local XTTS speech'
                      : 'XTTS · not installed',
                ),
              ),
            ],
            onChanged: (v) => m.edit('engine', v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => recordingSheet(context),
                icon: const Icon(Icons.mic_none_rounded, size: 18),
                label: const Text('Record'),
              ),
              OutlinedButton.icon(
                onPressed: () => voiceConsent(context),
                icon: const Icon(Icons.audio_file_outlined, size: 18),
                label: const Text('Import voice'),
              ),
              TextButton.icon(
                onPressed: () => voiceProfilesSheet(context),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('My voice profiles'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: m.current!['language'],
            decoration: const InputDecoration(labelText: 'Language'),
            items: const [
              DropdownMenuItem(value: 'en-IN', child: Text('English')),
              DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
              DropdownMenuItem(value: 'ta-IN', child: Text('Tamil')),
              DropdownMenuItem(value: 'pa-IN', child: Text('Punjabi')),
            ],
            onChanged: (v) => m.edit('language', v),
          ),
          if (m.current!['vocal_asset_id'] != null)
            TextButton.icon(
              onPressed: m.capabilities['sarvam'] == true
                  ? m.transcribeTake
                  : null,
              icon: const Icon(Icons.subtitles_outlined, size: 17),
              label: Text(
                m.capabilities['sarvam'] == true
                    ? 'Transcribe this take'
                    : 'Transcription · Sarvam key required',
              ),
            ),
          if (m.current!['vocal_asset_id'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Voice recording attached. Your take is saved in the library.',
                style: muted(context),
              ),
            ),
        ],
      ),
    );
  }
}

class LyricsPanel extends StatelessWidget {
  const LyricsPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final lyrics = m.current!['lyrics'] as String;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(
            title: 'Words & rhythm',
            subtitle: 'Keep the spark. Refine the flow.',
            action: Tooltip(
              message: 'Contextual lyric assistant',
              child: IconButton(
                onPressed: m.capabilities['lyric_ai'] == true
                    ? () => lyricsSheet(context)
                    : null,
                icon: const Icon(Icons.auto_awesome_outlined, color: violet),
              ),
            ),
          ),
          Editor(
            key: ValueKey(m.current!['id']),
            value: lyrics,
            label: 'Write your lyrics',
            maxLines: 9,
            onChanged: (v) => m.edit('lyrics', v),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: lyrics
                .split('\n')
                .where((line) => line.isNotEmpty)
                .take(8)
                .map(
                  (line) => Chip(
                    label: Text(
                      '${syllables(line)} syllables',
                      style: const TextStyle(fontSize: 10),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 7),
          Text(
            'English syllable estimates · ${m.current!['beats_per_bar'] ?? 4}/4 grid · ${lyrics.split('\n').where((line) => line.trim().isNotEmpty).length} lines. Aim for a similar syllable count in parallel phrases; audition the rhythm.',
            style: muted(context).copyWith(fontSize: 11),
          ),
          TextButton.icon(
            onPressed: () => versionSheet(context),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('Lyric revisions'),
          ),
          if (m.current!['engine'] == 'instrumental')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Instrumental mode preserves your lyrics as a draft; no vocal is synthesized.',
                style: muted(context).copyWith(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

int syllables(String text) => text
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .fold(
      0,
      (sum, w) =>
          sum +
          math.max(
            1,
            RegExp(
              r'[aeiouy]+',
            ).allMatches(w.replaceAll(RegExp(r'e$'), '')).length,
          ),
    );

class MasterPanel extends StatelessWidget {
  const MasterPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final active = m.jobs
        .where((j) => !['done', 'failed', 'cancelled'].contains(j['status']))
        .toList();
    final duration = m.duration;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(
            title: 'Your master',
            subtitle: m.master == null
                ? 'A little idea, a larger possibility.'
                : '${duration.toStringAsFixed(1)} seconds · stereo · 44.1 kHz',
            action: const Icon(Icons.waves_rounded, color: violet),
          ),
          if (m.master == null)
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: violet.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: violet,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      active.isNotEmpty
                          ? 'Shaping your sound…'
                          : 'Ready when you are.',
                      style: muted(context),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                Semantics(
                  label: 'Measured audio waveform. Tap to seek.',
                  child: GestureDetector(
                    onTapDown: (d) {
                      final box = context.findRenderObject() as RenderBox;
                      final ratio = (d.localPosition.dx / (box.size.width - 48))
                          .clamp(0.0, 1.0);
                      m.seekMaster(
                        Duration(
                          milliseconds: (ratio * duration * 1000).round(),
                        ),
                      );
                    },
                    child: SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: WavePainter(
                            List<num>.from(m.metrics['waveform'] ?? []),
                            duration > 0
                                ? (m.previewing
                                          ? 0
                                          : m.position.inMilliseconds) /
                                      (duration * 1000)
                                : 0,
                            Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .15),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  label: 'Seek project master',
                  child: Slider(
                    value:
                        (m.previewing
                                ? 0.0
                                : m.position.inMilliseconds.toDouble())
                            .clamp(0, duration * 1000),
                    max: math.max(1.0, duration * 1000),
                    onChanged: (value) =>
                        m.seekMaster(Duration(milliseconds: value.round())),
                    semanticFormatterCallback: (value) =>
                        '${(value / 1000).round()} seconds of ${duration.round()}',
                  ),
                ),
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: SpectrumPainter(frame(m), violet),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    FilledButton.icon(
                      onPressed: m.togglePlay,
                      icon: Icon(
                        m.playing && !m.previewing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        m.playing && !m.previewing ? 'Pause' : 'Play master',
                      ),
                    ),
                    Text(
                      '${clock(m.previewing ? 0 : m.position.inSeconds)} / ${clock(duration.round())}',
                      style: muted(context),
                    ),
                  ],
                ),
              ],
            ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: (active.first['progress'] as num).toDouble() / 100,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${active.first['status']} · ${active.first['progress']}%',
                    style: muted(context),
                  ),
                ),
                TextButton(
                  onPressed: () => m.jobAction(active.first, 'cancel'),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              meter(
                context,
                'INTEGRATED',
                m.metrics['integrated_lufs'] == null
                    ? '—'
                    : '${m.metrics['integrated_lufs']} LUFS',
              ),
              meter(
                context,
                'TRUE PEAK',
                m.metrics['true_peak_dbtp'] == null
                    ? '—'
                    : '${m.metrics['true_peak_dbtp']} dBTP',
              ),
              meter(context, 'FORMAT', m.master == null ? '—' : '24-bit WAV'),
            ],
          ),
          if (m.previousMaster != null) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Current mix'),
                  selected: !m.comparingPrevious,
                  onSelected: (_) => m.compare(false),
                ),
                ChoiceChip(
                  label: const Text('Previous mix'),
                  selected: m.comparingPrevious,
                  onSelected: (_) => m.compare(true),
                ),
                FilterChip(
                  label: const Text('Match loudness'),
                  selected: m.loudnessMatched,
                  onSelected: (v) {
                    m.loudnessMatched = v;
                    m.player.setVolume(m.playbackGain);
                    m.changed();
                  },
                ),
              ],
            ),
          ],
          if (m.master != null) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      m.download(m.master!['url'], '${m.title}.wav'),
                  icon: const Icon(Icons.download_outlined, size: 17),
                  label: const Text('WAV'),
                ),
                OutlinedButton(
                  onPressed: m.capabilities['mp3'] == true
                      ? () => m.generate('mp3')
                      : null,
                  child: const Text('MP3'),
                ),
                OutlinedButton(
                  onPressed: m.selectedJob == null
                      ? null
                      : () => m.download(
                          '/api/v1/jobs/${m.selectedJob!['id']}/stems.zip',
                          '${m.title}-stems.zip',
                        ),
                  child: const Text('Stem pack'),
                ),
                OutlinedButton(
                  onPressed: m.capabilities['video'] == true
                      ? () => m.generate('video')
                      : null,
                  child: const Text('Video'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget meter(BuildContext context, String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: label(context).copyWith(fontSize: 9)),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ],
  );
  List<num> frame(StudioModel m) {
    final frames = m.metrics['spectrum_frames'] as List? ?? [];
    if (frames.isEmpty) return [];
    final index = ((m.previewing ? 0 : m.position.inMilliseconds) / 150)
        .floor()
        .clamp(0, frames.length - 1);
    return List<num>.from(frames[index]);
  }
}

class MixerPanel extends StatelessWidget {
  const MixerPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(
            title: 'A place for every layer',
            subtitle: 'Balance the instruments. Hear the whole.',
            action: Tooltip(
              message: 'Live stem balance',
              child: Switch(
                value: m.stemMode,
                onChanged: m.stemAssets.isEmpty
                    ? null
                    : (v) => m.toggleStems(v),
              ),
            ),
          ),
          ...['vocals', 'drums', 'bass', 'other'].map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: stemColor(name),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 55,
                    child: Text(
                      name == 'other'
                          ? 'Keys'
                          : name[0].toUpperCase() + name.substring(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Solo $name',
                    child: FilterChip(
                      label: const Text('S', style: TextStyle(fontSize: 11)),
                      selected: m.params['${name}_solo'] == true,
                      onSelected: (v) => m.setParam('${name}_solo', v),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Mute $name',
                    child: FilterChip(
                      label: const Text('M', style: TextStyle(fontSize: 11)),
                      selected: m.params['${name}_mute'] == true,
                      onSelected: (v) => m.setParam('${name}_mute', v),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: '$name gain',
                      child: Slider(
                        min: 0,
                        max: 2,
                        value: ((m.params['${name}_gain'] ?? .8) as num)
                            .toDouble(),
                        onChanged: (v) => m.setParam('${name}_gain', v),
                        semanticFormatterCallback: (v) =>
                            '${(v * 100).round()} percent',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${(((m.params['${name}_gain'] ?? .8) as num) * 100).round()}',
                      style: muted(context).copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  m.stemMode
                      ? 'Live balance · render to include effects or gains above 100%'
                      : 'Saved mixer settings · render to hear changes',
                  style: muted(context).copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: m.master == null || m.rendering
                    ? null
                    : () => m.generate('remix'),
                child: const Text('Render mix'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (m.selectedJob != null)
            Text(
              m.selectedJob!['separation'] ??
                  'Stem playback uses the project’s source instrument stems.',
              style: muted(context).copyWith(fontSize: 10),
            ),
        ],
      ),
    );
  }
}

Color stemColor(String name) => {
  'vocals': const Color(0xFFB38C9D),
  'drums': const Color(0xFFBFA47D),
  'bass': const Color(0xFF7A9D8E),
  'other': violet,
}[name]!;

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(
            title: 'Sound, shaped',
            subtitle: 'Small changes. A different feeling.',
            action: Tooltip(
              message: 'Suggest a DSP adjustment',
              child: IconButton(
                onPressed: () => copilotSheet(context),
                icon: const Icon(Icons.auto_awesome_outlined, size: 19),
              ),
            ),
          ),
          ...[
            (key: 'saturation', name: 'Tape warmth', max: 1.0),
            (key: 'delay_mix', name: 'Delay blend', max: .8),
            (key: 'stereo_width', name: 'Stereo width', max: 1.0),
            (key: 'de_esser', name: 'De-esser', max: 1.0),
          ].map(
            (control) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        control.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${((((m.params[control.key] ?? 0) as num).toDouble()) * 100).round()}%',
                      style: muted(context).copyWith(fontSize: 11),
                    ),
                  ],
                ),
                Semantics(
                  label: control.name,
                  child: Slider(
                    value: ((m.params[control.key] ?? 0) as num).toDouble(),
                    max: control.max,
                    onChanged: (v) => m.setParam(control.key, v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<double>(
            isExpanded: true,
            initialValue: ((m.params['target_lufs'] ?? -14) as num).toDouble(),
            decoration: const InputDecoration(labelText: 'Loudness target'),
            items: const [
              DropdownMenuItem(value: -14, child: Text('-14 LUFS · balanced')),
              DropdownMenuItem(value: -18, child: Text('-18 LUFS · dynamic')),
              DropdownMenuItem(value: -11, child: Text('-11 LUFS · energetic')),
            ],
            onChanged: (v) => m.setParam('target_lufs', v),
          ),
          const SizedBox(height: 14),
          Text(
            'True peak limiting preserves headroom; the measured master may differ from the requested target.',
            style: muted(context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class ArtworkPanel extends StatelessWidget {
  const ArtworkPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final cover = m.assets
        .where((a) => a['id'] == m.current!['cover_asset_id'])
        .toList();
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Heading(title: 'A visual signature'),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: cover.isNotEmpty
                  ? Image.network(
                      m.url(cover.first['url']),
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) =>
                          const Icon(Icons.broken_image_outlined),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFB7A4CD), Color(0xFF6D5D8D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(50),
                      child: CustomPaint(
                        painter: MarkPainter(const Color(0xFFF9EBDD)),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => sheet(context, const ArtworkEditor()),
                child: const Text('Edit cover'),
              ),
              TextButton(
                onPressed: () => m.pickAsset('cover_asset_id'),
                child: const Text('Upload'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: m.master == null ? null : m.publish,
              icon: const Icon(Icons.ios_share_rounded, size: 17),
              label: const Text('Share to showcase'),
            ),
          ),
        ],
      ),
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String query = '';
  bool showAssets = false;
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final projects = m.projects
        .where(
          (p) =>
              p['title'].toString().toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(
            title: 'Your sound, collected.',
            subtitle: 'Return to an idea. Keep every take.',
            action: FilledButton.icon(
              onPressed: m.authenticated ? m.createProject : m.demo,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New session'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search your library',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Sessions')),
                  ButtonSegment(value: true, label: Text('Assets & takes')),
                ],
                selected: {showAssets},
                onSelectionChanged: (v) => setState(() => showAssets = v.first),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!showAssets) ...[
            if (projects.isEmpty)
              const EmptyState(
                icon: Icons.library_music_outlined,
                title: 'Space for your first idea.',
                text: 'Start a session and it will be waiting for you here.',
              ),
            ...projects.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Panel(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: violet.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: CustomPaint(painter: MarkPainter(violet)),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['title'],
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${p['genre']} · ${p['bpm']} BPM · ${p['key']}',
                              style: muted(context),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => m.guard(() => m.selectProject(p)),
                        child: const Text('Open'),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Session actions',
                        onSelected: (v) => m.guard(() async {
                          if (v == 'archive') {
                            await m.request('DELETE', '/projects/${p['id']}');
                            await m.reload();
                          } else {
                            final state = Json.from(p)
                              ..remove('id')
                              ..remove('revision');
                            state['title'] = '${p['title']} copy';
                            await m.request('POST', '/projects', data: state);
                            await m.reload();
                          }
                        }),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'duplicate',
                            child: Text('Duplicate session'),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive session'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            if (m.assets.isEmpty)
              const EmptyState(
                icon: Icons.audio_file_outlined,
                title: 'A home for every take.',
                text: 'Imported and rendered media are saved here.',
              ),
            ...m.assets
                .where(
                  (a) => a['name'].toString().toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            a['media_type'].toString().startsWith('image')
                                ? Icons.image_outlined
                                : Icons.audio_file_outlined,
                            color: violet,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${a['media_type']} · ${a['metrics']?['duration'] ?? '—'} seconds',
                                  style: muted(context),
                                ),
                              ],
                            ),
                          ),
                          if (a['media_type'].toString().startsWith('audio'))
                            IconButton(
                              tooltip: 'Analyze tempo and key',
                              onPressed: () => m.guard(() => m.analyze(a)),
                              icon: const Icon(Icons.query_stats_rounded),
                            ),
                          IconButton(
                            tooltip: 'Download asset',
                            onPressed: () => m.download(
                              a['url'],
                              a['name'].toString() + extension(a['media_type']),
                            ),
                            icon: const Icon(Icons.download_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

String extension(dynamic mime) =>
    {
      'audio/wav': '.wav',
      'audio/mpeg': '.mp3',
      'video/mp4': '.mp4',
      'image/png': '.png',
      'image/jpeg': '.jpg',
    }[mime] ??
    '';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(
            title: 'Good sound travels.',
            subtitle: 'Ideas shared by the people who made them.',
            action: IconButton(
              tooltip: 'Refresh showcase',
              onPressed: () => m.guard(m.refreshPublic),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          if (m.showcase.isEmpty)
            const EmptyState(
              icon: Icons.public_outlined,
              title: 'Be the first to set the tone.',
              text:
                  'Publish a finished master from your studio to begin the showcase.',
            ),
          ...m.showcase.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Panel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: violet.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: p['cover'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                m.url(p['cover']['url']),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.album_outlined,
                                  color: violet,
                                  size: 36,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.album_outlined,
                              color: violet,
                              size: 36,
                            ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title'],
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p['artist']} · ${p['genre']}',
                            style: muted(context),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () => m.playPreview(
                                  p['master']['url'],
                                  '${p['title']} · showcase',
                                ),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: const Text('Play track'),
                              ),
                              TextButton.icon(
                                onPressed: m.authenticated
                                    ? () => m.guard(() async {
                                        await m.request(
                                          'POST',
                                          '/showcase/${p['id']}/like',
                                        );
                                        await m.refreshPublic();
                                      })
                                    : () => accountSheet(context),
                                icon: const Icon(
                                  Icons.favorite_border,
                                  size: 16,
                                ),
                                label: Text('${p['likes']}'),
                              ),
                              TextButton.icon(
                                onPressed: () => commentsSheet(context, p),
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                ),
                                label: const Text('Notes'),
                              ),
                              if (m.account?['id'] == p['owner_id'])
                                TextButton(
                                  onPressed: () => m.guard(() async {
                                    await m.request(
                                      'DELETE',
                                      '/showcase/${p['id']}',
                                    );
                                    await m.refreshPublic();
                                  }),
                                  child: const Text('Unpublish'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Heading(
            title: 'Ideas in motion.',
            subtitle: 'Every render, with a place to return.',
          ),
          if (m.jobs.isEmpty)
            const EmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'Nothing in the queue.',
              text: 'Your generation and export jobs will appear here.',
            ),
          ...m.jobs.map(
            (j) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          j['status'] == 'done'
                              ? Icons.check_circle_outline
                              : j['status'] == 'failed'
                              ? Icons.error_outline
                              : Icons.graphic_eq_rounded,
                          color: j['status'] == 'failed'
                              ? Theme.of(context).colorScheme.error
                              : violet,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${j['state']['title']} · ${j['job_kind']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${j['status']} · ${j['progress']}%',
                                style: muted(context),
                              ),
                            ],
                          ),
                        ),
                        if (['failed', 'cancelled'].contains(j['status']))
                          TextButton(
                            onPressed: () => m.jobAction(j, 'retry'),
                            child: const Text('Retry'),
                          ),
                        if (![
                          'done',
                          'failed',
                          'cancelled',
                        ].contains(j['status']))
                          TextButton(
                            onPressed: () => m.jobAction(j, 'cancel'),
                            child: const Text('Cancel'),
                          ),
                        if (j['status'] == 'done')
                          TextButton.icon(
                            onPressed: () => m.guard(() async {
                              final a = await m.request(
                                'GET',
                                '/assets/${j['master_asset_id']}',
                              );
                              await m.download(
                                a['url'],
                                m.title + extension(a['media_type']),
                              );
                            }),
                            icon: const Icon(Icons.download_outlined, size: 16),
                            label: const Text('Save'),
                          ),
                      ],
                    ),
                    if (!['done', 'failed', 'cancelled'].contains(j['status']))
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: LinearProgressIndicator(
                          value: (j['progress'] as num) / 100,
                        ),
                      ),
                    if (j['status'] == 'done' && j['job_kind'] == 'video')
                      TextButton.icon(
                        onPressed: () => m.guard(() async {
                          final a = await m.request(
                            'GET',
                            '/assets/${j['master_asset_id']}',
                          );
                          if (context.mounted) {
                            await sheet(
                              context,
                              VideoPreview(url: m.url(a['url'])),
                            );
                          }
                        }),
                        icon: const Icon(Icons.movie_outlined),
                        label: const Text('Preview video'),
                      ),
                    if (j['error'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          j['error'],
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 28, 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Heading(
              title: 'A studio that feels like you.',
              subtitle: 'Choose how your workspace moves and looks.',
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {m.themeMode},
                      onSelectionChanged: (v) => m.settings(theme: v.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reduce motion'),
                    subtitle: const Text(
                      'Use instant transitions and quieter controls.',
                    ),
                    value: m.reduceMotion,
                    onChanged: (v) => m.settings(motion: v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reduce transparency'),
                    subtitle: const Text(
                      'Solid surfaces for a clearer workspace.',
                    ),
                    value: m.reduceTransparency,
                    onChanged: (v) => m.settings(transparency: v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Increase contrast'),
                    subtitle: const Text(
                      'Sharper text and solid glass for easier reading.',
                    ),
                    value: m.highContrast,
                    onChanged: (v) => m.settings(contrast: v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Heading(
                    title: 'Connected capabilities',
                    subtitle: 'Available tools for this studio.',
                  ),
                  ...[
                    (key: 'instrumental', title: 'Local composition'),
                    (key: 'recording', title: 'Your voice recordings'),
                    (key: 'sarvam', title: 'Sarvam speech & transcription'),
                    (key: 'xtts', title: 'Local XTTS speech'),
                    (key: 'lyric_ai', title: 'Contextual lyric AI'),
                    (key: 'mp3', title: 'MP3 export'),
                    (key: 'video', title: 'Visualizer video'),
                  ].map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.title)),
                          Text(
                            m.capabilities[item.key] == true
                                ? [
                                        'sarvam',
                                        'xtts',
                                        'lyric_ai',
                                      ].contains(item.key)
                                      ? 'Configured'
                                      : 'Available'
                                : 'Not configured',
                            style: TextStyle(
                              fontSize: 12,
                              color: m.capabilities[item.key] == true
                                  ? statusGreen(context)
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: .5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Configured engines still need a working provider or installed model. Speech engines generate spoken vocals. Imported beats use approximate spectral separation or an installed Demucs engine. Advanced MusicGen, RVC, vocoder, MIDI and Ableton experiments are outside the production workspace.',
                    style: muted(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Heading(title: 'Your account'),
                  Text(
                    m.account?['email'] ??
                        'Sign in to keep a permanent workspace.',
                    style: muted(context),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: m.authenticated
                        ? m.logout
                        : () => accountSheet(context),
                    child: Text(m.authenticated ? 'Sign out' : 'Sign in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });
  final IconData icon;
  final String title, text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 36, color: violet),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(text, style: muted(context), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}

class Transport extends StatelessWidget {
  const Transport({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 24, 16),
      child: Panel(
        glass: true,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            IconButton(
              tooltip: m.previewing
                  ? 'Play or pause preview'
                  : 'Play or pause master',
              onPressed: m.toggleTransport,
              icon: Icon(
                m.playing
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: violet,
                size: 35,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.transportTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    m.previewing
                        ? 'Preview playback'
                        : m.stemMode
                        ? 'Instrument balance'
                        : 'Master playback',
                    style: muted(context).copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width > 600)
              Expanded(
                flex: 5,
                child: Slider(
                  value: m.position.inMilliseconds.toDouble().clamp(
                    0,
                    m.transportDuration * 1000,
                  ),
                  max: math.max(1.0, m.transportDuration * 1000),
                  onChanged: (v) => m.seek(Duration(milliseconds: v.round())),
                  semanticFormatterCallback: (v) =>
                      '${(v / 1000).round()} seconds',
                ),
              ),
            Text(
              clock(m.position.inSeconds),
              style: muted(context).copyWith(fontSize: 12),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Volume',
              child: IconButton(
                onPressed: () =>
                    m.player.setVolume(m.player.volume == 0 ? 1 : 0),
                icon: Icon(
                  m.player.volume == 0
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                  size: 21,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

class WavePainter extends CustomPainter {
  WavePainter(this.data, this.progress, this.inactive);
  final List<num> data;
  final double progress;
  final Color inactive;
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final width = size.width / data.length;
    for (var i = 0; i < data.length; i++) {
      final h = (data[i].toDouble() * size.height * .9)
          .clamp(2.0, size.height)
          .toDouble();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * width,
            (size.height - h) / 2,
            math.max(1.0, width * .6),
            h,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = i / data.length <= progress ? violet : inactive,
      );
    }
  }

  @override
  bool shouldRepaint(WavePainter old) =>
      old.progress != progress || old.data != data || old.inactive != inactive;
}

class SpectrumPainter extends CustomPainter {
  SpectrumPainter(this.data, this.color);
  final List<num> data;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final width = size.width / data.length;
    for (var i = 0; i < data.length; i++) {
      final h = (math.sqrt(data[i].toDouble().clamp(0, 1)) * size.height * 3)
          .clamp(1.0, size.height)
          .toDouble();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * width, size.height - h, width * .55, h),
          const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: .45),
      );
    }
  }

  @override
  bool shouldRepaint(SpectrumPainter old) => old.data != data;
}

class Editor extends StatefulWidget {
  const Editor({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.style,
    this.maxLines = 1,
    this.borderless = false,
  });
  final String value, label;
  final ValueChanged<String> onChanged;
  final TextStyle? style;
  final int maxLines;
  final bool borderless;
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late final TextEditingController controller = TextEditingController(
    text: widget.value,
  );
  final focus = FocusNode();
  @override
  void didUpdateWidget(Editor old) {
    super.didUpdateWidget(old);
    if (widget.value != controller.text && !focus.hasFocus) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: TextField(
      controller: controller,
      focusNode: focus,
      style: widget.style,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
      decoration: widget.borderless
          ? InputDecoration(
              hintText: widget.label,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            )
          : InputDecoration(labelText: widget.label, alignLabelWithHint: true),
    ),
  );
}

Future<void> sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .3),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          12 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 728,
            maxHeight: math.max(
              120,
              MediaQuery.sizeOf(ctx).height * .88 -
                  MediaQuery.viewInsetsOf(ctx).bottom,
            ),
          ),
          child: LiquidGlass(
            radius: 28,
            reduceMotion: ctx.watch<StudioModel>().reduceMotion,
            reduceTransparency: ctx.watch<StudioModel>().reduceTransparency,
            highContrast: ctx.watch<StudioModel>().highContrast,
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  ctx,
                                ).colorScheme.onSurface.withValues(alpha: .35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close sheet',
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
Future<void> accountSheet(BuildContext context) =>
    sheet(context, const AccountForm());

class AccountForm extends StatefulWidget {
  const AccountForm({super.key});
  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool register = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(
          title: m.authenticated
              ? 'Your workspace'
              : register
              ? 'A home for your sound.'
              : 'Welcome back.',
          subtitle: m.authenticated
              ? (m.account?['email'] as String?)
              : 'Sign in to keep your sessions across devices.',
        ),
        if (m.authenticated)
          FilledButton(
            onPressed: () async {
              await m.logout();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sign out'),
          )
        else ...[
          if (register) ...[
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password · at least 10 characters',
            ),
          ),
          const SizedBox(height: 20),
          if (m.error.isNotEmpty)
            Text(
              m.error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: m.busy
                ? null
                : () async {
                    await m.login(
                      email.text.trim(),
                      password.text,
                      name.text.isEmpty ? 'Creator' : name.text,
                      register: register,
                    );
                    if (context.mounted && m.authenticated) {
                      Navigator.pop(context);
                    }
                  },
            child: Text(
              m.busy
                  ? 'Connecting…'
                  : register
                  ? 'Create account'
                  : 'Sign in',
            ),
          ),
          TextButton(
            onPressed: () => setState(() => register = !register),
            child: Text(
              register
                  ? 'Already have an account? Sign in'
                  : 'New here? Create an account',
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> voiceConsent(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Use your own voice.'),
      content: const Text(
        'Confirm that this recording is yours, or that you have the speaker’s permission to use it in your production.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('I have permission'),
        ),
      ],
    ),
  );
  if (accepted == true && context.mounted) {
    context.read<StudioModel>().pickAsset('vocal_asset_id', consent: true);
  }
}

Future<void> recordingSheet(BuildContext context) =>
    sheet(context, const RecordingForm());

class RecordingForm extends StatefulWidget {
  const RecordingForm({super.key});
  @override
  State<RecordingForm> createState() => _RecordingFormState();
}

class _RecordingFormState extends State<RecordingForm> {
  final recorder = AudioRecorder();
  bool recording = false, consent = false, processing = false;
  final chunks = <int>[];
  StreamSubscription<Uint8List>? pcmSubscription;
  Completer<void>? pcmDone;
  String message = '';
  static const maxPcmBytes = 44100 * 2 * 180;
  @override
  void dispose() {
    pcmSubscription?.cancel();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(
          title: 'Keep a real take.',
          subtitle: 'Record your voice, then use it in your mix.',
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('This is my voice, or I have permission.'),
          value: consent,
          onChanged: recording || processing
              ? null
              : (v) => setState(() => consent = v ?? false),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: !consent || processing
              ? null
              : () async {
                  setState(() => processing = true);
                  try {
                    if (!recording) {
                      if (!await recorder.hasPermission()) {
                        throw Exception('Microphone permission is needed.');
                      }
                      if (!mounted) return;
                      chunks.clear();
                      final stream = await recorder.startStream(
                        const RecordConfig(
                          encoder: AudioEncoder.pcm16bits,
                          sampleRate: 44100,
                          numChannels: 1,
                        ),
                      );
                      if (!mounted) {
                        await recorder.stop();
                        return;
                      }
                      pcmDone = Completer<void>();
                      pcmSubscription = stream.listen(
                        (bytes) {
                          final remaining = maxPcmBytes - chunks.length;
                          if (remaining <= 0) return;
                          chunks.addAll(bytes.take(remaining));
                          if (chunks.length == maxPcmBytes && mounted) {
                            setState(
                              () => message =
                                  'Three-minute limit reached. Stop and save your take.',
                            );
                            recorder.pause().catchError((_) {});
                          }
                        },
                        onError: (Object error) {
                          if (mounted) {
                            setState(
                              () => message =
                                  'Microphone input stopped. Save your captured take or try again.',
                            );
                          }
                          if (pcmDone?.isCompleted == false) {
                            pcmDone!.complete();
                          }
                        },
                        onDone: () {
                          if (pcmDone?.isCompleted == false) {
                            pcmDone!.complete();
                          }
                        },
                      );
                      setState(() {
                        recording = true;
                        message = '';
                      });
                    } else {
                      await recorder.stop();
                      if (mounted) setState(() => recording = false);
                      try {
                        await pcmDone?.future.timeout(
                          const Duration(seconds: 3),
                        );
                      } on TimeoutException {
                        // The input is stopped. Retain the bounded PCM already received.
                      }
                      await pcmSubscription?.cancel();
                      pcmSubscription = null;
                      if (!mounted) return;
                      if (chunks.isEmpty) {
                        throw Exception(
                          'No audio was captured. Check your microphone and try again.',
                        );
                      }
                      final bytes = pcmWav(Uint8List.fromList(chunks));
                      await m.guard(() async {
                        final a = await m.uploadBytes(
                          bytes,
                          'voice-take.wav',
                          consent: true,
                        );
                        m.edit('vocal_asset_id', a!['id']);
                        m.edit('engine', 'recording');
                        await m.save();
                      });
                      if (context.mounted && m.error.isEmpty) {
                        Navigator.pop(context);
                      }
                    }
                  } catch (e) {
                    if (mounted) setState(() => message = e.toString());
                  } finally {
                    if (mounted) setState(() => processing = false);
                  }
                },
          icon: Icon(recording ? Icons.stop_rounded : Icons.mic_none_rounded),
          label: Text(
            processing
                ? 'Preparing your take…'
                : recording
                ? 'Stop & save recording'
                : 'Start recording',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          recording
              ? message.isEmpty
                    ? 'Recording from your microphone…'
                    : message
              : message.isEmpty
              ? 'Recordings are stored privately with this session.'
              : message,
          style: muted(context),
        ),
      ],
    );
  }
}

Uint8List pcmWav(Uint8List pcm) {
  final data = ByteData(44 + pcm.length);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 44100, Endian.little);
  data.setUint32(28, 88200, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  data.buffer.asUint8List().setRange(44, 44 + pcm.length, pcm);
  return data.buffer.asUint8List();
}

Future<void> lyricsSheet(BuildContext context) => sheet(
  context,
  PromptForm(
    title: 'Find the next line.',
    button: 'Write a revision',
    onSubmit: (m, text) => m.guard(() async {
      final result = await m.request(
        'POST',
        '/lyrics',
        data: {'prompt': text, 'context': m.current!['lyrics']},
      );
      m.edit('lyrics', result['lyrics']);
      await m.save();
    }),
  ),
);
Future<void> copilotSheet(BuildContext context) =>
    sheet(context, const CopilotForm());

class PromptForm extends StatefulWidget {
  const PromptForm({
    super.key,
    required this.title,
    required this.button,
    required this.onSubmit,
  });
  final String title, button;
  final Future<void> Function(StudioModel, String) onSubmit;
  @override
  State<PromptForm> createState() => _PromptFormState();
}

class _PromptFormState extends State<PromptForm> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(title: widget.title),
        TextField(
          controller: text,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tell us what you have in mind…',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: m.busy
              ? null
              : () async {
                  await widget.onSubmit(m, text.text);
                  if (context.mounted && m.error.isEmpty) {
                    Navigator.pop(context);
                  }
                },
          child: Text(widget.button),
        ),
        if (m.error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(m.error),
          ),
      ],
    );
  }
}

class CopilotForm extends StatefulWidget {
  const CopilotForm({super.key});
  @override
  State<CopilotForm> createState() => _CopilotFormState();
}

class _CopilotFormState extends State<CopilotForm> {
  final text = TextEditingController();
  Json? proposal;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(
          title: 'A second pair of ears.',
          subtitle: 'Describe a change. Review the suggested settings.',
        ),
        TextField(
          controller: text,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'A warmer tape feel and a wider stereo image…',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => m.guard(() async {
            final result = await m.request(
              'POST',
              '/copilot',
              data: {'prompt': text.text},
            );
            if (mounted) setState(() => proposal = Json.from(result));
          }),
          child: const Text('Suggest an adjustment'),
        ),
        if (proposal != null) ...[
          const SizedBox(height: 20),
          ...List.from(proposal!['explanation']).map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• $reason'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: Json.from(proposal!['params']).isEmpty
                ? null
                : () async {
                    for (final entry in Json.from(
                      proposal!['params'],
                    ).entries) {
                      m.setParam(entry.key, entry.value);
                    }
                    await m.guard(m.save);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: const Text('Apply these settings'),
          ),
          const SizedBox(height: 12),
          Text(
            'Settings are saved. Render the mix to hear the effect.',
            style: muted(context),
          ),
        ],
      ],
    );
  }
}

Future<void> versionSheet(BuildContext context) async {
  final m = context.read<StudioModel>();
  await m.guard(() async {
    await m.save();
    await m.loadVersions();
  });
  if (!context.mounted) return;
  await sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(
          title: 'Room to go back.',
          subtitle:
              'Restore an earlier version. Your current state is preserved.',
        ),
        if (m.versions.isEmpty)
          Text('Versions appear after your first edit.', style: muted(context)),
        ...m.versions.map(
          (v) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded, color: violet),
            title: Text(v['action']),
            subtitle: Text(
              '${v['author']} · ${DateTime.fromMillisecondsSinceEpoch(((v['created_at'] as num) * 1000).round()).toLocal().toString().substring(0, 16)}',
            ),
            trailing: TextButton(
              onPressed: () async {
                await m.restore(v);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Restore'),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> collaborationSheet(BuildContext context) async {
  final m = context.read<StudioModel>();
  await m.guard(m.loadMembers);
  if (!context.mounted) return;
  await sheet(
    context,
    Consumer<StudioModel>(
      builder: (context, m, _) => m.current == null
          ? const Heading(
              title: 'Session access changed',
              subtitle:
                  'Close this sheet and open another session from your library.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Heading(
                  title: 'Better, together.',
                  subtitle: 'Invite another creator to edit this session.',
                ),
                SelectableText(
                  'Project: ${m.current!['id']}\nInvite code: ${m.current!['invite_code']}',
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(
                      text: '${m.current!['id']}\n${m.current!['invite_code']}',
                    ),
                  ),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy invitation'),
                ),
                ...m.members.map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(p['name']),
                    subtitle: Text(p['role']),
                    trailing:
                        m.current?['owner_id'] == m.account?['id'] &&
                            p['role'] != 'owner'
                        ? TextButton(
                            onPressed: m.busy
                                ? null
                                : () => m.removeMember(p['id']),
                            child: const Text('Remove'),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                const JoinForm(),
              ],
            ),
    ),
  );
}

class JoinForm extends StatefulWidget {
  const JoinForm({super.key});
  @override
  State<JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<JoinForm> {
  final id = TextEditingController(), code = TextEditingController();
  @override
  void dispose() {
    id.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Join another session',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: id,
          decoration: const InputDecoration(labelText: 'Project ID'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: code,
          decoration: const InputDecoration(labelText: 'Invite code'),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () async {
            await m.joinProject(id.text.trim(), code.text.trim());
            if (context.mounted && m.error.isEmpty) Navigator.pop(context);
          },
          child: const Text('Join session'),
        ),
      ],
    );
  }
}

Future<void> commentsSheet(BuildContext context, Json publication) async {
  final m = context.read<StudioModel>();
  List<Json> comments = [];
  await m.guard(() async {
    comments = m.list(
      await m.request('GET', '/showcase/${publication['id']}/comments'),
    );
  });
  if (!context.mounted) return;
  await sheet(
    context,
    CommentsForm(publication: publication, comments: comments),
  );
}

class CommentsForm extends StatefulWidget {
  const CommentsForm({
    super.key,
    required this.publication,
    required this.comments,
  });
  final Json publication;
  final List<Json> comments;
  @override
  State<CommentsForm> createState() => _CommentsFormState();
}

class _CommentsFormState extends State<CommentsForm> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(
          title: widget.publication['title'],
          subtitle: 'Leave a listening note.',
        ),
        ...widget.comments.map(
          (c) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              c['author'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(c['text']),
            trailing:
                m.account?['id'] == c['owner_id'] ||
                    m.account?['id'] == widget.publication['owner_id']
                ? IconButton(
                    tooltip: 'Remove note',
                    onPressed: () => m.guard(() async {
                      await m.request(
                        'DELETE',
                        '/showcase/${widget.publication['id']}/comments/${c['id']}',
                      );
                      if (mounted) setState(() => widget.comments.remove(c));
                    }),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  )
                : null,
          ),
        ),
        if (m.authenticated) ...[
          const SizedBox(height: 14),
          TextField(
            controller: text,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Your note'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => m.guard(() async {
              final c = Json.from(
                await m.request(
                  'POST',
                  '/showcase/${widget.publication['id']}/comments',
                  data: {'text': text.text},
                ),
              );
              if (mounted) {
                setState(() => widget.comments.add(c));
                text.clear();
              }
            }),
            child: const Text('Add a note'),
          ),
        ] else
          Text('Sign in to join the conversation.', style: muted(context)),
      ],
    );
  }
}

class EditableBeatGrid extends StatelessWidget {
  const EditableBeatGrid({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final meter = (m.current!['beats_per_bar'] ?? 4) as int;
    final bpm = (m.current!['bpm'] as num).toDouble();
    final offset = ((m.current!['beat_offset_ms'] ?? 0) as num).toDouble();
    final seconds = (m.previewing ? 0 : m.position.inMilliseconds) / 1000;
    final currentBar = math.max(
      0,
      ((seconds - offset / 1000) * bpm / 60 / meter).floor(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EDITABLE BEAT GRID', style: label(context)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: meter,
          decoration: const InputDecoration(labelText: 'Beats per bar'),
          items: [
            for (final value in [3, 4, 6, 8])
              DropdownMenuItem(value: value, child: Text('$value/4')),
          ],
          onChanged: (v) => m.edit('beats_per_bar', v),
        ),
        const SizedBox(height: 8),
        Text(
          'Downbeat offset ${offset.round()} ms · tap a beat to seek',
          style: muted(context).copyWith(fontSize: 11),
        ),
        Slider(
          value: offset,
          min: -5000,
          max: 5000,
          divisions: 200,
          label: '${offset.round()} ms',
          onChanged: (v) => m.edit('beat_offset_ms', v),
        ),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (var beat = 0; beat < meter * 2; beat++)
              ActionChip(
                label: Text(
                  '${currentBar + 1 + beat ~/ meter}.${beat % meter + 1}',
                ),
                onPressed: m.master == null
                    ? null
                    : () => m.seekMaster(
                        Duration(
                          milliseconds:
                              ((offset / 1000 +
                                              (currentBar * meter + beat) *
                                                  60 /
                                                  bpm)
                                          .clamp(0, m.duration) *
                                      1000)
                                  .round(),
                        ),
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

Future<void> voiceProfilesSheet(BuildContext context) async {
  final m = context.read<StudioModel>();
  await m.guard(m.loadVoiceProfiles);
  if (context.mounted) await sheet(context, const VoiceProfilesForm());
}

class VoiceProfilesForm extends StatefulWidget {
  const VoiceProfilesForm({super.key});
  @override
  State<VoiceProfilesForm> createState() => _VoiceProfilesFormState();
}

class _VoiceProfilesFormState extends State<VoiceProfilesForm> {
  final name = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(
          title: 'Your voice, kept.',
          subtitle:
              'Private consented recording profiles. Reuse a real take; these profiles do not clone a voice.',
        ),
        if (m.current?['vocal_asset_id'] != null) ...[
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Voice profile name'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: m.busy
                ? null
                : () => m.saveVoiceProfile(name.text.trim()),
            child: const Text('Save attached take as profile'),
          ),
          const SizedBox(height: 16),
        ],
        if (m.voiceProfiles.isEmpty)
          Text(
            'Record or import your own voice with consent, then save an attached take here.',
            style: muted(context),
          ),
        for (final profile in m.voiceProfiles)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(profile['name']),
            subtitle: Text(
              '${profile['language']} · consented original recording',
            ),
            trailing: Wrap(
              children: [
                TextButton(
                  onPressed: m.busy
                      ? null
                      : () async {
                          await m.useVoiceProfile(profile);
                          if (context.mounted && m.error.isEmpty) {
                            Navigator.pop(context);
                          }
                        },
                  child: const Text('Use take'),
                ),
                IconButton(
                  tooltip: 'Remove profile',
                  onPressed: m.busy
                      ? null
                      : () => m.guard(() async {
                          await m.request(
                            'DELETE',
                            '/voice-profiles/${profile['id']}',
                          );
                          await m.loadVoiceProfiles();
                        }),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ArtworkEditor extends StatefulWidget {
  const ArtworkEditor({super.key});
  @override
  State<ArtworkEditor> createState() => _ArtworkEditorState();
}

class _ArtworkEditorState extends State<ArtworkEditor> {
  String template = 'halo', accent = '#9877DE', background = '#191C2B';
  final caption = TextEditingController();
  @override
  void initState() {
    super.initState();
    final style = context.read<StudioModel>().current?['artwork'] as Map?;
    template = style?['template'] ?? template;
    accent = style?['accent'] ?? accent;
    background = style?['background'] ?? background;
    caption.text = style?['caption'] ?? '';
  }

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Color color(String hex) =>
      Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(
          title: 'A cover with character.',
          subtitle:
              'Choose an original template, palette and caption. Render a real 1024 px cover.',
        ),
        Center(
          child: SizedBox(
            width: 230,
            height: 230,
            child: Container(
              decoration: BoxDecoration(
                color: color(background),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      painter: MarkPainter(color(accent)),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    m.title,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    caption.text,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: template,
          decoration: const InputDecoration(labelText: 'Cover template'),
          items: const [
            DropdownMenuItem(value: 'halo', child: Text('Halo')),
            DropdownMenuItem(value: 'wave', child: Text('Wave')),
            DropdownMenuItem(value: 'minimal', child: Text('Minimal')),
          ],
          onChanged: (v) => setState(() => template = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: accent,
          decoration: const InputDecoration(labelText: 'Accent palette'),
          items: const [
            DropdownMenuItem(value: '#9877DE', child: Text('Amethyst')),
            DropdownMenuItem(value: '#E1AE96', child: Text('Apricot')),
            DropdownMenuItem(value: '#75A58D', child: Text('Sage')),
          ],
          onChanged: (v) => setState(() => accent = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: background,
          decoration: const InputDecoration(labelText: 'Cover background'),
          items: const [
            DropdownMenuItem(value: '#191C2B', child: Text('Midnight')),
            DropdownMenuItem(value: '#3C2A3E', child: Text('Plum')),
            DropdownMenuItem(value: '#243C39', child: Text('Forest')),
          ],
          onChanged: (v) => setState(() => background = v!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: caption,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Cover caption'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: m.busy
              ? null
              : () async {
                  await m.createArtwork({
                    'template': template,
                    'accent': accent,
                    'background': background,
                    'caption': caption.text,
                  });
                  if (context.mounted && m.error.isEmpty) {
                    Navigator.pop(context);
                  }
                },
          child: const Text('Render cover'),
        ),
        const SizedBox(height: 8),
        Text(
          'Preview shows your identity/palette; the selected template is applied to the rendered cover. Optional AI artwork is not configured.',
          style: muted(context),
        ),
      ],
    );
  }
}

class VideoPreview extends StatefulWidget {
  const VideoPreview({super.key, required this.url});
  final String url;
  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late final VideoPlayerController controller;
  String failure = '';
  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    controller
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object error) {
          if (mounted) {
            setState(
              () => failure =
                  'Video preview is unavailable on this device. Download the real MP4 and open it in a video player.',
            );
          }
        });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Heading(
        title: 'Watch your sound.',
        subtitle: 'The completed portrait visualizer and actual master.',
      ),
      if (failure.isNotEmpty)
        Text(failure)
      else if (!controller.value.isInitialized)
        const Center(child: CircularProgressIndicator())
      else ...[
        Center(
          child: SizedBox(
            height: 360,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => FilledButton.icon(
            onPressed: () =>
                value.isPlaying ? controller.pause() : controller.play(),
            icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
            label: Text(value.isPlaying ? 'Pause video' : 'Play video'),
          ),
        ),
      ],
    ],
  );
}
