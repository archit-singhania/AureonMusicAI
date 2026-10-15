import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aureon/production_ui.dart';
import 'package:aureon/studio_model.dart';
import 'package:aureon/studio_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [390.0, 1440.0]) {
    testWidgets('Comping editor bounds and release cancellation at $width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = StudioModel(start: false);
      model.reduceMotion = true;
      model.current = {
        'id': 'p',
        'release_kit': {
          'artist': 'Artist',
          'credits': 'Owned original',
          'teaser_start': 0,
          'teaser_seconds': 1,
        },
        'take_groups': [
          {
            'id': 'bank',
            'name': 'My takes',
            'asset_ids': ['take'],
            'phrases': [
              {
                'id': 'phrase',
                'asset_id': 'take',
                'start': 0,
                'source_start': 0,
                'length': 44100,
                'fade_in': 0,
                'fade_out': 0,
              },
            ],
          },
        ],
      };
      model.master = {
        'id': 'take',
        'name': 'Original take',
        'metrics': {'duration': 2.0},
      };
      model.assets = [
        {'id': 'take', 'name': 'Original take', 'media_type': 'audio/wav'},
      ];
      model.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'sample_count': 88200},
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: MaterialApp(
            theme: AureonApp.theme(Brightness.light),
            home: const Scaffold(
              body: SingleChildScrollView(child: ProductionPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Phrase 1 · sample 0'));
      await tester.tap(find.text('Phrase 1 · sample 0'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Length samples'),
        '9999999',
      );
      await tester.tap(find.text('Save edit'));
      await tester.pumpAndSettle();
      expect(model.current!['take_groups'][0]['phrases'][0]['length'], 44100);
      expect(
        find.text(
          'Use integer samples within the take, with fades fitting the phrase.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Review release kit'));
      await tester.tap(find.text('Review release kit'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm release credits and rights'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(model.jobs, isEmpty);
      expect(model.dirty, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });
  }
}
