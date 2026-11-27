import 'package:aureon/studio_model.dart';
import 'package:aureon/studio_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixtureRecorder extends AudioRecorder {
  FixtureRecorder(this.samples);
  final Uint8List samples;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 44100);
    expect(config.numChannels, 1);
    return Stream.value(samples);
  }

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('Captured PCM is uploaded with consent and saved as a take', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const methods = MethodChannel('com.llfbandit.record/messages');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methods, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(methods, null));
    final model = StudioModel(start: false)
      ..current = {'id': 'project', 'revision': 1};
    addTearDown(model.dispose);
    final samples = Uint8List.fromList([1, 0, 255, 255, 4, 0, 8, 0]);
    Json? saved;
    var uploads = 0;
    model.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          Object data;
          if (options.method == 'POST') {
            expect(
              options.path,
              '/api/v1/assets?project_id=project&consent=true',
            );
            final file = (options.data as FormData).files.single.value;
            expect(file.filename, 'voice-take.wav');
            final bytes = await file
                .finalize()
                .expand((chunk) => chunk)
                .toList();
            expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
            expect(bytes.sublist(44), samples);
            uploads++;
            data = {'id': 'voice-asset'};
          } else if (options.method == 'GET') {
            expect(options.path, '/api/v1/assets');
            data = [
              {'id': 'voice-asset'},
            ];
          } else {
            expect(options.method, 'PUT');
            expect(options.path, '/api/v1/projects/project');
            saved = (options.data as Json)['state'] as Json;
            data = {'id': 'project', 'revision': 2, ...saved!};
          }
          handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200),
          );
        },
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: RecordingForm(
                      createRecorder: () => FixtureRecorder(samples),
                    ),
                  ),
                ),
                child: const Text('Open recorder'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open recorder'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Start recording'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Stop & save recording'));
      for (
        var attempt = 0;
        attempt < 25 && (saved == null || model.busy);
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(
      uploads,
      1,
      reason: [
        model.error,
        ...tester.widgetList<Text>(find.byType(Text)).map((text) => text.data),
      ].join(' | '),
    );
    expect(saved?['vocal_asset_id'], 'voice-asset');
    expect(saved?['engine'], 'recording');
    expect(find.byType(RecordingForm), findsNothing);
  });

  testWidgets('Consent gates microphone requests and denial permits retry', (
    tester,
  ) async {
    const channel = MethodChannel('com.llfbandit.record/messages');
    final messenger = tester.binding.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'hasPermission' ? false : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final model = StudioModel(start: false);
    addTearDown(model.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: const MaterialApp(home: Scaffold(body: RecordingForm())),
      ),
    );
    final start = find.widgetWithText(FilledButton, 'Start recording');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(calls, isNot(contains('hasPermission')));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    for (var attempt = 1; attempt <= 2; attempt++) {
      await tester.tap(start);
      await tester.pumpAndSettle();
      final notice = find.text('Microphone permission is needed.');
      expect(notice, findsOneWidget);
      final announcement = find.ancestor(
        of: notice,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      );
      expect(announcement, findsOneWidget);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(
        calls.where((method) => method == 'hasPermission').length,
        attempt,
      );
      expect(calls, isNot(contains('startStream')));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
