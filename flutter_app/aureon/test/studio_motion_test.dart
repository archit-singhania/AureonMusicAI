import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aureon/studio_model.dart';
import 'package:aureon/studio_motion.dart';
import 'package:aureon/studio_theme.dart';
import 'package:aureon/studio_ui.dart';

void main() {
  testWidgets(
    'Consent dialog keeps closed-loop keyboard focus and quiet timing',
    (tester) async {
      final model = StudioModel(start: false)
        ..destination = 4
        ..reduceMotion = true;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: model, child: const AureonApp()),
      );
      await tester.pumpAndSettle();
      final consent = voiceConsent(tester.element(find.byType(SettingsPage)));
      await tester.pumpAndSettle();
      final dialogContext = tester.element(find.byType(AlertDialog));
      final route = ModalRoute.of(dialogContext);
      expect(route?.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);
      expect(route?.transitionDuration, Duration.zero);
      for (var index = 0; index < 5; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<AlertDialog>(),
          isNotNull,
        );
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await consent;
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
  test('Every curated palette retains text, action and selection contrast', () {
    double contrast(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (values.last + .05) / (values.first + .05);
    }

    for (final palette in StudioPalette.values) {
      for (final brightness in Brightness.values) {
        for (final highContrast in [false, true]) {
          final colors = StudioTheme.create(
            brightness,
            palette: palette,
            highContrast: highContrast,
          ).colorScheme;
          for (final pair in [
            [colors.onSurface, colors.surface],
            [colors.onSurfaceVariant, colors.surfaceContainerLow],
            [colors.onPrimary, colors.primary],
            [colors.primary, colors.primaryContainer],
            [colors.onSecondary, colors.secondary],
            [colors.onSecondaryContainer, colors.secondaryContainer],
          ]) {
            expect(
              contrast(pair.first, pair.last),
              greaterThanOrEqualTo(4.5),
              reason: '$palette $brightness contrast=$highContrast $pair',
            );
          }
        }
      }
    }
  });

  test('Palette and comfort choices are persisted together', () async {
    SharedPreferences.setMockInitialValues({});
    final model = StudioModel(start: false);
    await model.settings(
      colors: StudioPalette.tide,
      theme: ThemeMode.dark,
      motion: true,
      transparency: true,
      contrast: true,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('palette'), 'tide');
    expect(prefs.getInt('theme'), ThemeMode.dark.index);
    expect(prefs.getBool('reduceMotion'), isTrue);
    expect(prefs.getBool('reduceTransparency'), isTrue);
    expect(prefs.getBool('highContrast'), isTrue);
    model.dispose();
  });

  testWidgets('Section navigation preserves search controller and text', (
    tester,
  ) async {
    final model = StudioModel(start: false)..destination = 1;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: model, child: const AureonApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'a saved search');
    final fieldElement = tester.element(find.byType(TextField).first);
    model.destination = 4;
    model.changed();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    model.destination = 1;
    model.changed();
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(TextField).first), same(fieldElement));
    expect(find.text('a saved search'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });

  testWidgets(
    'Reduced motion finishes an in-flight entrance and section change',
    (tester) async {
      final model = StudioModel(start: false);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: model, child: const AureonApp()),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.binding.hasScheduledFrame, isTrue);
      model.reduceMotion = true;
      model.destination = 4;
      model.changed();
      await tester.pump();
      await tester.pump();
      final sections = find.byType(StudioSections);
      final sectionFade = tester.widget<FadeTransition>(
        find
            .descendant(of: sections, matching: find.byType(FadeTransition))
            .first,
      );
      expect(sectionFade.opacity.value, 1);
      for (final entrance in tester.widgetList<StudioEntrance>(
        find.byType(StudioEntrance),
      )) {
        final fade = tester.widget<FadeTransition>(
          find
              .descendant(
                of: find.byWidget(entrance),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(fade.opacity.value, 1);
      }
      final context = tester.element(find.byType(SettingsPage));
      expect(StudioMotion.sheet(context).duration, Duration.zero);
      expect(StudioMotion.sheet(context).reverseDuration, Duration.zero);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );

  testWidgets('Playback feedback retains the transport button identity', (
    tester,
  ) async {
    final model = StudioModel(start: false)
      ..previewing = true
      ..previewTitle = 'Original preview'
      ..previewDuration = 12;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: model, child: const AureonApp()),
    );
    await tester.pumpAndSettle();
    final button = find.byTooltip('Play or pause preview');
    final element = tester.element(button);
    model.playing = true;
    model.changed();
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.element(button), same(element));
    expect(find.byType(StudioIconFeedback), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
