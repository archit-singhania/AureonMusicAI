import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aureon/studio_model.dart';
import 'package:aureon/studio_ui.dart';
import 'package:aureon/liquid_glass.dart';

void main() {
  test('Audio plots repaint when appearance changes without new audio', () {
    final samples = <num>[.2, .5, .7];
    final light = AureonApp.theme(Brightness.light).colorScheme;
    final dark = AureonApp.theme(Brightness.dark).colorScheme;
    expect(
      SpectrumPainter(
        samples,
        dark.primary,
      ).shouldRepaint(SpectrumPainter(samples, light.primary)),
      isTrue,
    );
    expect(
      WavePainter(
        samples,
        .5,
        light.outline,
        active: dark.primary,
      ).shouldRepaint(
        WavePainter(samples, .5, light.outline, active: light.primary),
      ),
      isTrue,
    );
  });

  test('Studio palettes retain readable content and action contrast', () {
    double contrast(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (values.last + .05) / (values.first + .05);
    }

    for (final brightness in Brightness.values) {
      for (final highContrast in [false, true]) {
        final theme = AureonApp.theme(brightness, highContrast: highContrast);
        final colors = theme.colorScheme;
        for (final pair in [
          [colors.onSurface, colors.surface],
          [colors.onSurfaceVariant, colors.surface],
          [colors.onSurfaceVariant, colors.surfaceContainerLow],
          [colors.onPrimary, colors.primary],
          [colors.primary, colors.primaryContainer],
        ]) {
          expect(
            contrast(pair.first, pair.last),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness, high contrast $highContrast: $pair',
          );
        }
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Manrope');
      }
    }
  });

  final previousError = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    previousError?.call(details);
  };

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Large text and contrast retain navigation and readable sheets at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final model = StudioModel(start: false);
        model.reduceMotion = true;
        model.highContrast = true;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(value: model, child: const AureonApp()),
        );
        await tester.pump();
        expect(find.byType(LiquidGlass), findsWidgets);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Settings').first);
        await tester.pumpAndSettle();
        expect(find.text('Increase contrast'), findsOneWidget);
        expect(tester.takeException(), isNull);
        accountSheet(tester.element(find.byType(SettingsPage)));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close sheet'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close sheet'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        model.dispose();
      },
    );
  }
  testWidgets('Covered showcase tracks retain an explicit playback action', (
    tester,
  ) async {
    final model = StudioModel(start: false);
    model.destination = 2;
    model.showcase = [
      {
        'id': 'showcase-fixture',
        'title': 'A covered original',
        'artist': 'Fixture creator',
        'genre': 'rnb',
        'likes': 0,
        'owner_id': 'fixture-owner',
        'cover': {'url': '/unavailable-cover.png'},
        'master': {'url': '/fixture-master.wav'},
      },
    ];
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: model, child: const AureonApp()),
    );
    await tester.pump();
    expect(find.text('Play track'), findsOneWidget);
    expect(find.text('A covered original'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('Completed phone master remains usable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final model = StudioModel(start: false);
    model.reduceMotion = true;
    model.highContrast = true;
    model.current = {
      'id': 'readable-completed-session',
      'title': 'A completed original session',
      'lyrics': 'A little light in the midnight air',
      'genre': 'rnb',
      'preset_id': 'afterglow',
      'bpm': 88,
      'key': 'A minor',
      'engine': 'instrumental',
      'language': 'en-IN',
      'params': {},
    };
    model.master = {
      'id': 'real-shape-master',
      'url': '/fixture.wav',
      'metrics': {
        'duration': 30,
        'integrated_lufs': -14,
        'true_peak_dbtp': -1,
        'waveform': [.2, .6, .4, .7],
        'spectrum_frames': [
          [.2, .4],
        ],
      },
    };
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: model, child: const AureonApp()),
    );
    await tester.pump();
    expect(find.text('Play master'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -900),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('Responsive workspace at $width has usable navigation', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
        originalHandler?.call(details);
      };
      final model = StudioModel(start: false);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: model, child: const AureonApp()),
      );
      await tester.pump();
      expect(find.text('Make room\nfor your sound.'), findsOneWidget);
      expect(find.text('Try the studio'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Library').first);
      await tester.pumpAndSettle();
      expect(find.text('Your sound, collected.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      expect(find.text('Reduce motion'), findsOneWidget);
      expect(find.text('Reduce transparency'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });
  }
  for (final width in [390.0, 800.0, 840.0, 1440.0]) {
    testWidgets('Editable studio has no overflow at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = StudioModel(start: false);
      model.current = {
        'id': 'test-session',
        'title': 'Afterglow Sessions',
        'lyrics': 'A little light in the midnight air',
        'genre': 'rnb',
        'preset_id': 'afterglow',
        'bpm': 88,
        'key': 'A minor',
        'language': 'en-IN',
        'engine': 'instrumental',
        'params': {
          'vocals_gain': .8,
          'drums_gain': .85,
          'bass_gain': .8,
          'other_gain': .8,
          'saturation': .1,
          'delay_mix': .1,
          'stereo_width': .5,
          'de_esser': .2,
          'target_lufs': -14,
        },
      };
      model.themeMode = ThemeMode.dark;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: model, child: const AureonApp()),
      );
      await tester.pump();
      expect(find.text('Your master'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -700),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });
  }
  test('Captured PCM has a valid WAV header and exact sample payload', () {
    final pcm = Uint8List.fromList([0, 0, 100, 0, 200, 0]);
    final bytes = pcmWav(pcm);
    final header = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(header.getUint32(24, Endian.little), 44100);
    expect(header.getUint32(40, Endian.little), pcm.length);
    expect(bytes.sublist(44), pcm);
  });
  testWidgets('Beat grid changes meter and retains an editable offset', (
    tester,
  ) async {
    final model = StudioModel(start: false);
    model.current = {
      'id': 'grid-session',
      'bpm': 120,
      'beats_per_bar': 4,
      'beat_offset_ms': 125,
    };
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: EditableBeatGrid()),
          ),
        ),
      ),
    );
    expect(
      find.text('Downbeat offset 125 ms · tap a beat to seek'),
      findsOneWidget,
    );
    await tester.tap(find.text('4/4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3/4').last);
    await tester.pumpAndSettle();
    expect(model.current!['beats_per_bar'], 3);
    expect(find.text('1.4'), findsNothing);
    expect(model.dirty, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets(
    'Cover editor offers real template and palette choices at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = StudioModel(start: false);
      model.current = {'id': 'cover-session', 'title': 'Original artwork'};
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: ArtworkEditor())),
          ),
        ),
      );
      await tester.tap(find.text('Halo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wave').last);
      await tester.pumpAndSettle();
      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('Render cover'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
}
