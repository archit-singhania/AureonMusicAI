import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aureon/mastering_ui.dart';
import 'package:aureon/studio_model.dart';
import 'package:aureon/studio_theme.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('Mastering report shows unknown values and historical source at $width', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = StudioModel();
      model.reduceMotion = true;
      model.current = {'id': 'p'};
      model.master = {'id': 'new-master'};
      model.jobs = [{
        'job_kind': 'mastering_analysis', 'status': 'done', 'source_master_asset_id': 'old-master',
        'report_asset_id': 'report', 'quality_report': {
          'profile': {'target_lufs': -14, 'ceiling_dbtp': -1},
          'integrated_lufs': null, 'estimated_true_peak_dbtp': null,
          'clipped_frames': 0, 'stereo_correlation': null, 'mono_energy_delta_db': null,
          'findings': [], 'limitations': 'Analysis never changes audio.',
        },
      }];
      await tester.pumpWidget(ChangeNotifierProvider.value(value: model, child: MaterialApp(
        theme: StudioTheme.create(Brightness.light), home: const Scaffold(body: SingleChildScrollView(child: MasteringQualityPanel())),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Historical report'), findsOneWidget);
      expect(find.text('Integrated loudness: Not measurable LUFS'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '-100');
      await tester.pump();
      expect(find.textContaining('Enter a value from'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    });
  }
}
