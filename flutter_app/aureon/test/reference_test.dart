import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aureon/studio_model.dart';
import 'package:aureon/studio_ui.dart';
import 'package:aureon/reference_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Reference review is responsive and rejects invalid settings at $width',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = StudioModel();
        model.reduceMotion = true;
        model.current = {
          'id': 'p',
          'reference': {'asset_id': 'ref'},
        };
        model.master = {'id': 'master'};
        model.assets = [
          {'id': 'ref', 'name': 'Private reference', 'media_type': 'audio/wav'},
        ];
        model.jobs = [
          {
            'job_kind': 'reference_analysis',
            'status': 'done',
            'source_master_asset_id': 'master',
            'reference_asset_id': 'ref',
            'audition_asset_ids': ['a', 'b'],
            'comparison': {
              'suggestion': {'gain_db': -3, 'width': 1},
              'audition_lufs': -20,
              'master': {
                'integrated_lufs': -20,
                'crest_db': 8,
                'stereo_width': .5,
              },
              'reference': {
                'integrated_lufs': -18,
                'crest_db': 9,
                'stereo_width': .7,
              },
              'band_delta_percent': {'bass': 5},
              'explanation': 'Measured source comparison',
            },
          },
        ];
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: model,
            child: MaterialApp(
              theme: AureonApp.theme(Brightness.dark),
              home: const Scaffold(
                body: SingleChildScrollView(child: ReferencePanel()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Review adjustment'));
        await tester.tap(find.text('Review adjustment'));
        await tester.pumpAndSettle();
        expect(find.text('Render a reference adjustment'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Gain dB'),
          '99',
        );
        await tester.tap(find.text('Confirm new render'));
        await tester.pumpAndSettle();
        expect(find.text('Use −12 to 12 dB'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(model.current!['reference']['gain_db'], isNull);
        model.master = {'id': 'new-master'};
        model.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Review adjustment'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        model.dispose();
      },
    );
  }
}
