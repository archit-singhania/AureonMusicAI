import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aureon/midi_ui.dart';
import 'package:aureon/studio_model.dart';

void main() {
  testWidgets(
    'Quantize changes note starts and undo restores the saved numeric edit',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final model = StudioModel(start: false);
      model.current = {
        'id': 'fixture',
        'midi': {
          'version': 1,
          'ppq': 480,
          'preset': 'keys',
          'notes': [
            {
              'start': 85,
              'length': 120,
              'pitch': 60,
              'velocity': 84,
              'channel': 0,
            },
          ],
          'sustain': [],
          'tempos': [],
          'loop_start': 0,
          'loop_end': 0,
          'loop_repeats': 1,
        },
      };
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: MidiStudioPanel()),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Quantize starts'));
      await tester.tap(find.text('Quantize starts'));
      await tester.pump();
      expect(model.current!['midi']['notes'][0]['start'], 120);
      model.current!['midi'] = jsonDecode(jsonEncode(model.current!['midi']));
      await tester.ensureVisible(find.text('Undo quantize'));
      await tester.tap(find.text('Undo quantize'));
      await tester.pump();
      expect(model.current!['midi']['notes'][0]['start'], 85);
      expect(model.current!['midi']['notes'][0]['velocity'], 84);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
}
