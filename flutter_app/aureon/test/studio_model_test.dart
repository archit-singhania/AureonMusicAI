import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aureon/studio_model.dart';

class ControlledAdapter implements HttpClientAdapter {
  final pending = <Completer<ResponseBody>>[];
  final requests = <Map<String, dynamic>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    requests.add(Map<String, dynamic>.from(options.data));
    final response = Completer<ResponseBody>();
    pending.add(response);
    return response.future;
  }

  void resolve(int index, Map<String, dynamic> project) {
    pending[index].complete(
      ResponseBody.fromString(
        jsonEncode(project),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  Future<void> waitForCount(int count) async {
    for (var attempt = 0; pending.length < count && attempt < 100; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(pending.length, greaterThanOrEqualTo(count));
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'A/B uses selected measured audio and only attenuates the louder master',
    () {
      final model = StudioModel(start: false);
      model.master = {
        'metrics': {'duration': 20, 'integrated_lufs': -12},
      };
      model.previousMaster = {
        'metrics': {'duration': 18, 'integrated_lufs': -18},
      };
      expect(model.playbackGain, closeTo(0.501187, 0.00001));
      expect(model.duration, 20);
      model.comparingPrevious = true;
      expect(model.playbackGain, 1);
      expect(model.duration, 18);
      expect(model.metrics['integrated_lufs'], -18);
      model.dispose();
    },
  );
  test(
    'Concurrent saves wait for new edits and preserve the latest revision',
    () async {
      SharedPreferences.setMockInitialValues({});
      final model = StudioModel(start: false);
      final adapter = ControlledAdapter();
      model.dio.httpClientAdapter = adapter;
      model.account = {'id': 'author'};
      model.current = {
        'id': 'session',
        'revision': 1,
        'title': 'Draft',
        'lyrics': 'first',
        'params': {},
      };
      model.projects = [Json.from(model.current!)];
      model.edit('lyrics', 'first saved draft');
      final firstSave = model.save();
      await adapter.waitForCount(1);
      model.edit('lyrics', 'new edits while saving');
      model.edit('title', 'Afterglow, revised');
      model.edit('beat_offset_ms', 125);
      model.edit('beats_per_bar', 3);
      final secondSave = model.save();
      adapter.resolve(0, {
        'id': 'session',
        'revision': 2,
        'title': 'Draft',
        'lyrics': 'first saved draft',
        'params': {},
      });
      await adapter.waitForCount(2);
      expect(adapter.requests.length, 2);
      expect(adapter.requests[1]['revision'], 2);
      expect(adapter.requests[1]['state']['lyrics'], 'new edits while saving');
      expect(adapter.requests[1]['state']['title'], 'Afterglow, revised');
      expect(adapter.requests[1]['state']['beat_offset_ms'], 125);
      expect(adapter.requests[1]['state']['beats_per_bar'], 3);
      var completed = false;
      secondSave.then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      adapter.resolve(1, {
        'id': 'session',
        'revision': 3,
        'title': 'Afterglow, revised',
        'lyrics': 'new edits while saving',
        'params': {},
      });
      await Future.wait([firstSave, secondSave]);
      expect(model.current!['revision'], 3);
      expect(model.projects.single['title'], 'Afterglow, revised');
      expect(model.projects.single['revision'], 3);
      expect(model.dirty, isFalse);
      model.dispose();
    },
  );
  test(
    'A failed save keeps the recoverable local draft and unsaved state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final model = StudioModel(start: false);
      final adapter = ControlledAdapter();
      model.dio.httpClientAdapter = adapter;
      model.account = {'id': 'author'};
      model.current = {
        'id': 'session',
        'revision': 1,
        'title': 'Draft',
        'lyrics': 'words',
        'params': {},
      };
      model.edit('lyrics', 'recover these words');
      await model.persistDraft();
      final saving = model.save();
      final failure = expectLater(saving, throwsException);
      await adapter.waitForCount(1);
      adapter.pending.single.completeError(StateError('offline'));
      await failure;
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('draft_session')!)['state']['lyrics'],
        'recover these words',
      );
      expect(model.dirty, isTrue);
      expect(model.saveStatus, 'Save needs attention');
      model.dispose();
    },
  );
}
