import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aureon/arrangement_edits.dart';
import 'package:aureon/arrangement_ui.dart';
import 'package:aureon/studio_model.dart';
import 'package:aureon/studio_ui.dart';

Map<String, dynamic> fixture() => {
  'version': 1,
  'sample_rate': 44100,
  'markers': [],
  'tracks': [
    {
      'id': 'track',
      'name': 'Original take',
      'gain': 1.0,
      'pan': 0.0,
      'mute': false,
      'automation': [
        {
          'parameter': 'volume',
          'interpolation': 'linear',
          'points': [
            {'sample': 0, 'value': 0.0},
            {'sample': 44100, 'value': 1.0},
          ],
        },
      ],
      'clips': [
        {
          'id': 'clip',
          'asset_id': 'asset',
          'start': 100,
          'source_start': 200,
          'length': 44100,
          'repeats': 1,
          'fade_in': 0,
          'fade_out': 0,
        },
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'Split preserves contiguous source samples and rejects invalid boundaries',
    () {
      final source = fixture();
      final next = cloneArrangement(source);
      splitArrangementClip(next, 'clip', 22150, 'right');
      final clips = next['tracks'][0]['clips'] as List;
      expect(clips[0]['length'] + clips[1]['length'], 44100);
      expect(
        clips[1]['source_start'],
        clips[0]['source_start'] + clips[0]['length'],
      );
      expect(clips[1]['start'], clips[0]['start'] + clips[0]['length']);
      expect((source['tracks'][0]['clips'] as List).length, 1);
      expect(
        () => splitArrangementClip(next, 'right', 22150, 'invalid'),
        throwsFormatException,
      );
    },
  );
  test('Rendered-curve inspection has endpoint, linear and hold semantics', () {
    final env = Map<String, dynamic>.from(
      fixture()['tracks'][0]['automation'][0],
    );
    expect(automationValue(env, 22050), .5);
    expect(automationValue(env, 100000), 1);
    env['interpolation'] = 'hold';
    expect(automationValue(env, 22050), 0);
    expect(automationValue(env, 44100), 1);
    expect(snappedSample(6000, 120, true), 5513);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('Timeline and editable curves remain readable at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = StudioModel(start: false);
      model.reduceMotion = true;
      model.current = {
        'id': 'project',
        'bpm': 120,
        'revision': 1,
        'arrangement': fixture(),
      };
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: MaterialApp(
            theme: AureonApp.theme(Brightness.light),
            home: const Scaffold(
              body: SingleChildScrollView(child: ArrangementPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Arrangement timeline'), findsOneWidget);
      await tester.tap(find.text('Accessible track and clip list'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clip 1 · Original take'));
      await tester.tap(find.text('Clip 1 · Original take'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add volume point'));
      await tester.tap(find.text('Add volume point'));
      await tester.pumpAndSettle();
      expect(find.text('volume automation point'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sample'),
        '22050',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Value'), '.5');
      await tester.tap(find.text('Apply edit'));
      await tester.pump();
      expect(
        (model.current!['arrangement']['tracks'][0]['automation'][0]['points']
                as List)
            .length,
        3,
      );
      await tester.ensureVisible(find.byType(EditableEnvelope));
      await tester.pumpAndSettle();
      final curveOrigin = tester.getTopLeft(find.byType(EditableEnvelope));
      final curveWidth = tester.getSize(find.byType(EditableEnvelope)).width;
      await tester.dragFrom(
        curveOrigin + const Offset(2, 82),
        Offset(curveWidth * .25, -20),
      );
      await tester.pumpAndSettle();
      final points =
          model.current!['arrangement']['tracks'][0]['automation'][0]['points']
              as List;
      expect(points.first['sample'], greaterThan(0));
      expect(points.first['value'], greaterThan(0));
      final clipButton = find.widgetWithText(
        OutlinedButton,
        'Selected · 1.00s ×1',
      );
      await tester.ensureVisible(clipButton);
      await tester.pumpAndSettle();
      await tester.drag(clipButton, const Offset(80, 0));
      await tester.pump();
      final moved = model.current!['arrangement']['tracks'][0]['clips'][0];
      expect(moved['start'], greaterThan(100));
      expect(moved['source_start'], 200);
      expect(moved['length'], 44100);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });
  }
}
