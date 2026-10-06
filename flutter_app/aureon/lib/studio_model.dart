import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'studio_theme.dart';

typedef Json = Map<String, dynamic>;

class StudioModel extends ChangeNotifier {
  StudioModel({bool start = true}) {
    const configured = String.fromEnvironment('API_BASE_URL');
    baseUrl = configured.isNotEmpty
        ? configured
        : (kIsWeb
              ? Uri.base.origin
              : defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:5000'
              : 'http://localhost:5000');
    if (kIsWeb && Uri.base.host == 'localhost' && configured.isEmpty) {
      baseUrl = 'http://localhost:5000';
    }
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    positionSubscription = player.positionStream.listen((value) {
      position = value;
      notifyListeners();
    });
    playerSubscription = player.playerStateStream.listen((value) {
      playing = value.playing;
      notifyListeners();
    });
    if (start) bootstrap();
  }
  void changed() => notifyListeners();
  late final Dio dio;
  late String baseUrl;
  String token = '', error = '', saveStatus = 'All changes saved';
  Json? current, master, account, selectedJob;
  Json capabilities = {};
  List<Json> projects = [],
      jobs = [],
      assets = [],
      presets = [],
      showcase = [],
      versions = [],
      members = [];
  final AudioPlayer player = AudioPlayer();
  late final StreamSubscription<Duration> positionSubscription;
  late final StreamSubscription<PlayerState> playerSubscription;
  bool disposed = false;
  @override
  void notifyListeners() {
    if (!disposed) super.notifyListeners();
  }

  final Map<String, AudioPlayer> stemPlayers = {};
  final Map<String, Json> stemAssets = {};
  Duration position = Duration.zero;
  bool playing = false,
      busy = false,
      online = false,
      dirty = false,
      saving = false,
      stemMode = false;
  bool refreshingPublic = false;
  bool canUndo = false, canRedo = false;
  List<Json> voiceProfiles = [];
  bool comparingPrevious = false, loudnessMatched = true;
  Json? previousMaster;
  bool previewing = false;
  String previewTitle = '';
  double previewDuration = 0;
  String get transportTitle => previewing ? previewTitle : title;
  double get transportDuration => previewing ? previewDuration : duration;
  Timer? driftTimer;
  bool reduceMotion = false, reduceTransparency = false, highContrast = false;
  ThemeMode themeMode = ThemeMode.system;
  StudioPalette palette = StudioPalette.iris;
  String liveStatus = 'Connecting';
  int destination = 0, eventCursor = 0;
  Timer? refreshTimer, saveTimer, reconnect;
  Completer<void>? saveCompletion;
  WebSocketChannel? channel;
  final secure = const FlutterSecureStorage();

  String url(String path) => path.startsWith('http') ? path : '$baseUrl$path';
  String get title => current?['title'] ?? 'Your next great idea';
  Json get params => Map<String, dynamic>.from(current?['params'] ?? {});
  bool get authenticated => token.isNotEmpty;
  bool get rendering =>
      jobs.any((j) => !['done', 'failed', 'cancelled'].contains(j['status']));
  double get duration => (metrics['duration'] as num?)?.toDouble() ?? 0;
  Json get metrics => Map<String, dynamic>.from(
    (comparingPrevious ? previousMaster : master)?['metrics'] ?? {},
  );

  Future<dynamic> request(String method, String path, {dynamic data}) async {
    try {
      return (await dio.request(
        '/api/v1$path',
        data: data,
        options: Options(method: method),
      )).data;
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? e.response?.data['detail']
          : null;
      throw Exception(
        detail is String
            ? detail
            : e.response?.statusCode == 422
            ? 'Check the entered fields and try again.'
            : 'Studio connection unavailable. Your local draft is preserved.',
      );
    }
  }

  Future<void> guard(Future<void> Function() action) async {
    busy = true;
    error = '';
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getInt('theme') ?? 0;
    themeMode =
        ThemeMode.values[savedTheme >= 0 && savedTheme < ThemeMode.values.length
            ? savedTheme
            : 0];
    reduceMotion = prefs.getBool('reduceMotion') ?? false;
    reduceTransparency = prefs.getBool('reduceTransparency') ?? false;
    highContrast = prefs.getBool('highContrast') ?? false;
    palette = StudioPalette.values.firstWhere(
      (value) => value.name == prefs.getString('palette'),
      orElse: () => StudioPalette.iris,
    );
    if (!kIsWeb) token = await secure.read(key: 'aureon_token') ?? '';
    await refreshPublic();
    if (authenticated) {
      await guard(() async {
        account = await request('GET', '/auth/me');
        await reload();
      });
    }
    refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!online) {
        refreshPublic();
      } else {
        refreshQuietly();
      }
    });
    notifyListeners();
  }

  Future<void> refreshPublic() async {
    if (refreshingPublic) return;
    refreshingPublic = true;
    try {
      final results = await Future.wait([
        request('GET', '/capabilities'),
        request('GET', '/presets'),
        request('GET', '/showcase'),
      ]);
      capabilities = Json.from(results[0]);
      presets = list(results[1]);
      showcase = list(results[2]);
      online = true;
    } catch (_) {
      online = false;
    } finally {
      refreshingPublic = false;
    }
    notifyListeners();
  }

  List<Json> list(dynamic data) =>
      (data as List).map((item) => Json.from(item)).toList();
  Future<void> login(
    String email,
    String password,
    String name, {
    bool register = false,
  }) => guard(() async {
    final data = await request(
      'POST',
      register ? '/auth/register' : '/auth/login',
      data: {'email': email, 'password': password, 'name': name},
    );
    await session(data);
    await reload();
  });
  Future<void> demo() => guard(() async {
    final data = await request('POST', '/demo');
    await session(data);
    await reload();
    await selectProject(Json.from(data['project']));
  });
  Future<void> session(dynamic data) async {
    if (account?['id'] != data['user']['id']) {
      reconnect?.cancel();
      channel?.sink.close();
      await player.stop();
      await closeStems();
      current = null;
      master = null;
      previousMaster = null;
      previewing = false;
      projects = [];
      jobs = [];
      assets = [];
      eventCursor = 0;
      dirty = false;
    }
    token = data['token'];
    account = Json.from(data['user']);
    if (!kIsWeb) await secure.write(key: 'aureon_token', value: token);
  }

  Future<void> logout() => guard(() async {
    try {
      await request('POST', '/auth/logout');
    } catch (_) {
      // Local credentials can always be cleared, including while offline.
    }
    token = '';
    account = null;
    current = null;
    master = null;
    projects = [];
    jobs = [];
    assets = [];
    reconnect?.cancel();
    saveTimer?.cancel();
    dirty = false;
    await player.stop();
    await closeStems();
    previewing = false;
    await secure.delete(key: 'aureon_token');
    channel?.sink.close();
  });
  Future<void> reload() async {
    projects = list(await request('GET', '/projects'));
    assets = list(await request('GET', '/assets'));
    if (current != null) {
      jobs = list(await request('GET', '/jobs?project_id=${current!['id']}'));
    } else {
      jobs = list(await request('GET', '/jobs'));
    }
    await refreshPublic();
    notifyListeners();
  }

  void updateLibraryProject(Json project) {
    final index = projects.indexWhere((item) => item['id'] == project['id']);
    if (index < 0) {
      projects.insert(0, Json.from(project));
    } else {
      projects[index] = Json.from(project);
    }
  }

  Future<void> createProject() => guard(() async {
    await save();
    final result = Json.from(
      await request('POST', '/projects', data: {'title': 'Untitled session'}),
    );
    await reload();
    await selectProject(result);
  });
  Future<void> selectProject(Json project) async {
    await save();
    await player.stop();
    await closeStems();
    previewing = false;
    current = Json.from(await request('GET', '/projects/${project['id']}'));
    dirty = false;
    final prefs = await SharedPreferences.getInstance();
    final draftText = prefs.getString('draft_${project['id']}');
    if (draftText != null) {
      final draft = Json.from(jsonDecode(draftText));
      if (draft['owner'] == account?['id']) {
        final state = Json.from(draft['state']);
        if (state['revision'] == current!['revision']) {
          current = state;
          dirty = true;
          saveStatus = 'Recovered local draft';
        } else {
          error =
              'A local draft exists, but this session has a newer saved revision. The saved version is open.';
        }
      }
    }
    master = null;
    selectedJob = null;
    eventCursor = 0;
    position = Duration.zero;
    jobs = list(await request('GET', '/jobs?project_id=${current!['id']}'));
    await loadVersions();
    await loadMembers();
    await refreshMaster();
    await connectLive();
    destination = 0;
    notifyListeners();
  }

  void edit(String key, dynamic value) {
    if (current == null) return;
    current![key] = value;
    dirty = true;
    saveStatus = 'Unsaved changes';
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 850), () => guard(save));
    unawaited(persistDraft());
    notifyListeners();
  }

  void setParam(String key, dynamic value) {
    final next = params;
    next[key] = value;
    edit('params', next);
    if (stemMode) updateStemGains();
  }

  Future<void> save() async {
    while (saving) {
      await saveCompletion?.future;
    }
    if (!dirty || current == null) return;
    saving = true;
    saveCompletion = Completer<void>();
    saveStatus = 'Saving…';
    final editingProjectId = current!['id'];
    final snapshot = Json.from(current!);
    final nextState = <String, dynamic>{
      for (final key in [
        'title',
        'genre',
        'lyrics',
        'preset_id',
        'beat_asset_id',
        'vocal_asset_id',
        'cover_asset_id',
        'bpm',
        'key',
        'language',
        'engine',
        'separation_engine',
        'beat_offset_ms',
        'beats_per_bar',
        'artwork',
        'params',
      ])
        if (snapshot.containsKey(key)) key: snapshot[key],
    };
    dirty = false;
    try {
      final result = Json.from(
        await request(
          'PUT',
          '/projects/$editingProjectId',
          data: {
            'revision': snapshot['revision'],
            'state': nextState,
            'action': 'Studio edit',
          },
        ),
      );
      updateLibraryProject(result);
      canUndo = true;
      canRedo = false;
      if (current?['id'] == editingProjectId) {
        if (dirty) {
          current!['revision'] = result['revision'];
        } else {
          current = result;
        }
        saveStatus = dirty ? 'Unsaved changes' : 'All changes saved';
        if (!dirty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('draft_$editingProjectId');
        }
      }
    } catch (e) {
      dirty = true;
      saveStatus = 'Save needs attention';
      rethrow;
    } finally {
      saving = false;
      saveCompletion?.complete();
      notifyListeners();
    }
    if (dirty) await save();
  }

  Future<void> persistDraft() async {
    if (current == null || account == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'draft_${current!['id']}',
      jsonEncode({'owner': account!['id'], 'state': current}),
    );
  }

  Future<void> generate([String kind = 'generate']) => guard(() async {
    if (current == null) return;
    await save();
    await request(
      'POST',
      '/projects/${current!['id']}/jobs',
      data: {'kind': kind},
    );
    jobs = list(await request('GET', '/jobs?project_id=${current!['id']}'));
    destination = kind == 'generate' ? 0 : 3;
  });
  Future<void> jobAction(Json job, String action) => guard(() async {
    await request('POST', '/jobs/${job['id']}/$action');
    await reload();
  });
  Future<void> refreshQuietly() async {
    if (!authenticated || busy || current == null) return;
    try {
      jobs = list(await request('GET', '/jobs?project_id=${current!['id']}'));
      final events = list(
        await request(
          'GET',
          '/events?after=$eventCursor&project_id=${current!['id']}',
        ),
      );
      for (final event in events) {
        eventCursor = (event['event_id'] as num).toInt();
        if (event['kind'] == 'project' &&
            !dirty &&
            !saving &&
            (event['revision'] as num) > ((current?['revision'] ?? 0) as num)) {
          current = Json.from(
            await request('GET', '/projects/${current!['id']}'),
          );
          updateLibraryProject(current!);
          await loadVersions();
        }
      }
      await refreshMaster();
      online = true;
      notifyListeners();
    } catch (_) {
      online = false;
      notifyListeners();
    }
  }

  Future<void> refreshMaster() async {
    final completed = jobs
        .where(
          (j) =>
              j['status'] == 'done' &&
              ['generate', 'remix'].contains(j['job_kind']),
        )
        .toList();
    if (completed.isEmpty) return;
    final selected = completed.first;
    if (master?['id'] == selected['master_asset_id']) return;
    selectedJob = selected;
    master = Json.from(
      await request('GET', '/assets/${selected['master_asset_id']}'),
    );
    stemAssets.clear();
    for (final entry in Json.from(selected['stem_asset_ids'] ?? {}).entries) {
      stemAssets[entry.key] = Json.from(
        await request('GET', '/assets/${entry.value}'),
      );
    }
    await closeStems();
    comparingPrevious = false;
    previousMaster = null;
    if (completed.length > 1) {
      previousMaster = Json.from(
        await request('GET', '/assets/${completed[1]['master_asset_id']}'),
      );
    }
    if (!previewing) {
      await player.setUrl(url(master!['url']));
      position = Duration.zero;
    }
  }

  Future<void> connectLive() async {
    channel?.sink.close();
    reconnect?.cancel();
    if (current == null) return;
    try {
      final response = await dio.post(
        '/hub/music/negotiate?negotiateVersion=1&access_token=$token',
      );
      final uri = Uri.parse('$baseUrl/hub/music').replace(
        scheme: baseUrl.startsWith('https') ? 'wss' : 'ws',
        queryParameters: {
          'id': response.data['connectionToken'],
          'access_token': token,
        },
      );
      channel = WebSocketChannel.connect(uri);
      await channel!.ready;
      channel!.sink.add(
        '${jsonEncode({'protocol': 'json', 'version': 1})}\u001e',
      );
      bool joined = false;
      channel!.stream.listen(
        (message) {
          for (final part in message.toString().split('\u001e')) {
            if (part.trim().isEmpty) continue;
            final event = jsonDecode(part);
            if (!joined && event is Map && !event.containsKey('type')) {
              joined = true;
              channel!.sink.add(
                '${jsonEncode({
                  'type': 1,
                  'target': 'JoinProject',
                  'arguments': [current!['id']],
                })}\u001e',
              );
              liveStatus = 'Live session';
              notifyListeners();
            }
            if (event['target'] == 'StudioEvent') refreshQuietly();
            if (event['target'] == 'Presence') loadMembers();
            if (event['target'] == 'SessionAccessRevoked') {
              current = null;
              master = null;
              jobs = [];
              reconnect?.cancel();
              channel?.sink.close();
              player.stop();
              closeStems();
              error =
                  'Your access to this session changed. Open another session from the library.';
              destination = 1;
              notifyListeners();
            }
          }
        },
        onError: (_) => lostConnection(),
        onDone: lostConnection,
      );
    } catch (_) {
      lostConnection();
    }
  }

  void lostConnection() {
    if (disposed || current == null || !authenticated) return;
    liveStatus = 'Reconnect available';
    reconnect?.cancel();
    reconnect = Timer(const Duration(seconds: 5), connectLive);
    notifyListeners();
  }

  Future<void> togglePlay() => guard(() async {
    if (master == null) return;
    if (previewing) {
      await player.pause();
      await player.setUrl(
        url((comparingPrevious ? previousMaster : master)!['url']),
      );
      previewing = false;
      position = Duration.zero;
      playing = false;
    }
    if (playing) {
      await player.pause();
      for (final p in stemPlayers.values) {
        await p.pause();
      }
    } else {
      if (position.inMilliseconds >= duration * 1000) await seek(Duration.zero);
      if (stemMode) {
        await player.setVolume(0);
        for (final p in stemPlayers.values) {
          unawaited(p.play());
        }
      } else {
        await player.setVolume(playbackGain);
      }
      unawaited(player.play());
    }
  });
  Future<void> toggleTransport() => previewing
      ? guard(() async {
          if (playing) {
            await player.pause();
          } else {
            if (position.inMilliseconds >= transportDuration * 1000) {
              await player.seek(Duration.zero);
            }
            unawaited(player.play());
          }
        })
      : togglePlay();
  Future<void> seek(Duration value) async {
    await player.seek(value);
    await Future.wait(stemPlayers.values.map((p) => p.seek(value)));
  }

  Future<void> seekMaster(Duration value) async {
    if (previewing && master != null) {
      await player.pause();
      await player.setUrl(
        url((comparingPrevious ? previousMaster : master)!['url']),
      );
      previewing = false;
      await player.setVolume(playbackGain);
    }
    await seek(value);
    notifyListeners();
  }

  Future<void> toggleStems(bool enabled) => guard(() async {
    await player.pause();
    await closeStems();
    if (previewing || (enabled && comparingPrevious)) {
      final time = position;
      comparingPrevious = false;
      await player.setUrl(url(master!['url']));
      previewing = false;
      await player.seek(time);
    }
    stemMode = enabled;
    if (enabled) {
      for (final entry in stemAssets.entries) {
        final p = AudioPlayer();
        await p.setUrl(url(entry.value['url']));
        await p.seek(position);
        stemPlayers[entry.key] = p;
      }
      await updateStemGains();
    }
    await player.setVolume(enabled ? 0 : playbackGain);
    if (enabled) {
      driftTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (playing) {
          for (final p in stemPlayers.values) {
            if ((p.position - position).inMilliseconds.abs() > 45) {
              p.seek(position);
            }
          }
        }
      });
    }
  });
  Future<void> updateStemGains() async {
    final solos = stemPlayers.keys
        .where((name) => params['${name}_solo'] == true)
        .toSet();
    for (final entry in stemPlayers.entries) {
      final muted =
          params['${entry.key}_mute'] == true ||
          (solos.isNotEmpty && !solos.contains(entry.key));
      await entry.value.setVolume(
        muted
            ? 0
            : ((params['${entry.key}_gain'] ?? .8) as num).toDouble().clamp(
                0,
                1,
              ),
      );
    }
  }

  Future<void> closeStems() async {
    driftTimer?.cancel();
    for (final p in stemPlayers.values) {
      await p.dispose();
    }
    stemPlayers.clear();
    stemMode = false;
  }

  Future<void> playPreview(String audioUrl, String name) => guard(() async {
    await closeStems();
    await player.pause();
    final length = await player.setUrl(url(audioUrl));
    await player.setVolume(1);
    previewing = true;
    previewTitle = name;
    previewDuration = (length?.inMilliseconds ?? 0) / 1000;
    position = Duration.zero;
    unawaited(player.play());
  });
  Future<void> preview(Json preset) => playPreview(
    '/api/v1/presets/${preset['id']}/preview',
    '${preset['title']} · preset preview',
  );
  Future<Json?> uploadBytes(
    Uint8List bytes,
    String name, {
    bool consent = false,
  }) async {
    final response = await dio.post(
      '/api/v1/assets?project_id=${current?['id'] ?? ''}&consent=$consent',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: name),
      }),
    );
    assets = list(await request('GET', '/assets'));
    notifyListeners();
    return Json.from(response.data);
  }

  Future<void> pickAsset(String field, {bool consent = false}) =>
      guard(() async {
        final picked = await FilePicker.platform.pickFiles(
          type: field == 'cover_asset_id' ? FileType.image : FileType.audio,
          withData: true,
        );
        if (picked == null) return;
        final file = picked.files.single;
        if (file.bytes == null) throw Exception('This file could not be read.');
        final a = await uploadBytes(file.bytes!, file.name, consent: consent);
        edit(field, a!['id']);
        if (field == 'beat_asset_id') await analyze(a);
        if (field == 'vocal_asset_id') edit('engine', 'recording');
        await save();
      });
  Future<void> analyze(Json a) async {
    final data = await request('POST', '/assets/${a['id']}/analyze');
    if (current != null) {
      edit('bpm', data['bpm']);
      edit('key', data['key']);
    }
  }

  /// Binary exports can wait for archive preparation before response headers.
  /// Keep normal API calls on their short connection budget.
  Future<Uint8List> fetchExport(String path) async {
    final options = Options(responseType: ResponseType.bytes)
        .compose(dio.options, url(path))
        .copyWith(connectTimeout: const Duration(seconds: 60));
    try {
      final response = await dio.fetch<List<int>>(options);
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw Exception('The export is empty. Render it again and retry.');
      }
      return Uint8List.fromList(data);
    } on DioException catch (failure) {
      if ([
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
      ].contains(failure.type)) {
        throw Exception(
          'Export preparation took too long. Your saved mix is safe; try the download again.',
        );
      }
      throw Exception('The export could not be downloaded. Please try again.');
    }
  }

  Future<void> download(String path, String filename) => guard(() async {
    final bytes = await fetchExport(path);
    await FilePicker.platform.saveFile(
      dialogTitle: 'Save from Aureon',
      fileName: filename,
      bytes: bytes,
    );
  });
  Future<void> loadVersions() async {
    if (current != null) {
      versions = list(
        await request('GET', '/projects/${current!['id']}/versions'),
      );
      final history = await request(
        'GET',
        '/projects/${current!['id']}/history',
      );
      canUndo = history['can_undo'] == true;
      canRedo = history['can_redo'] == true;
    }
    notifyListeners();
  }

  Future<void> restore(Json version) => guard(() async {
    await save();
    current = Json.from(
      await request(
        'POST',
        '/projects/${current!['id']}/restore/${version['id']}',
      ),
    );
    dirty = false;
    updateLibraryProject(current!);
    await loadVersions();
  });
  Future<void> loadMembers() async {
    if (current != null) {
      members = list(
        await request('GET', '/projects/${current!['id']}/members'),
      );
    }
    notifyListeners();
  }

  Future<void> joinProject(String id, String code) => guard(() async {
    final p = Json.from(
      await request('POST', '/projects/$id/join', data: {'code': code}),
    );
    await reload();
    await selectProject(p);
  });
  Future<void> navigateHistory(String direction) => guard(() async {
    await save();
    current = Json.from(
      await request(
        'POST',
        '/projects/${current!['id']}/$direction',
        data: {'revision': current!['revision']},
      ),
    );
    dirty = false;
    updateLibraryProject(current!);
    await loadVersions();
  });

  Future<void> loadVoiceProfiles() async {
    voiceProfiles = list(await request('GET', '/voice-profiles'));
    notifyListeners();
  }

  Future<void> saveVoiceProfile(String name) => guard(() async {
    await request(
      'POST',
      '/voice-profiles',
      data: {
        'name': name,
        'asset_id': current!['vocal_asset_id'],
        'language': current!['language'],
      },
    );
    await loadVoiceProfiles();
  });

  Future<void> useVoiceProfile(Json profile) => guard(() async {
    final take = await request(
      'POST',
      '/projects/${current!['id']}/voice-profiles/${profile['id']}/use',
    );
    edit('vocal_asset_id', take['id']);
    edit('engine', 'recording');
    edit('language', profile['language']);
    await save();
    assets = list(await request('GET', '/assets'));
  });
  Future<void> removeMember(String id) => guard(() async {
    await save();
    final projectId = current!['id'];
    await request('DELETE', '/projects/$projectId/members/$id');
    current = Json.from(await request('GET', '/projects/$projectId'));
    updateLibraryProject(current!);
    await loadMembers();
  });
  Future<void> publish() => guard(() async {
    await save();
    await request(
      'POST',
      '/projects/${current!['id']}/publish',
      data: {'title': title, 'description': current!['lyrics']},
    );
    await refreshPublic();
    destination = 2;
  });
  Future<void> createArtwork([Json? options]) => guard(() async {
    await save();
    final style = options ?? Json.from(current!['artwork'] ?? {});
    final a = await request(
      'POST',
      '/projects/${current!['id']}/artwork',
      data: style,
    );
    edit('artwork', style);
    edit('cover_asset_id', a['id']);
    await save();
    assets = list(await request('GET', '/assets'));
  });

  double get playbackGain {
    if (!loudnessMatched || master == null || previousMaster == null) return 1;
    final a = (master!['metrics']?['integrated_lufs'] as num?)?.toDouble();
    final b = (previousMaster!['metrics']?['integrated_lufs'] as num?)
        ?.toDouble();
    if (a == null || b == null) return 1;
    return math
        .pow(10, (math.min(a, b) - (comparingPrevious ? b : a)) / 20)
        .toDouble()
        .clamp(0, 1);
  }

  Future<void> compare(bool previous) => guard(() async {
    if (previous && previousMaster == null) return;
    final resume = playing, time = position;
    await closeStems();
    await player.pause();
    comparingPrevious = previous;
    previewing = false;
    await player.setUrl(url((previous ? previousMaster : master)!['url']));
    await player.seek(time);
    await player.setVolume(playbackGain);
    if (resume) unawaited(player.play());
  });
  Future<void> transcribeTake() => guard(() async {
    final aid = current?['vocal_asset_id'];
    if (aid == null) throw Exception('Record or import a voice take first.');
    final result = await request('POST', '/assets/$aid/transcribe');
    edit('lyrics', result['transcript']);
    await save();
  });

  Future<void> settings({
    ThemeMode? theme,
    StudioPalette? colors,
    bool? motion,
    bool? transparency,
    bool? contrast,
  }) async {
    themeMode = theme ?? themeMode;
    palette = colors ?? palette;
    reduceMotion = motion ?? reduceMotion;
    reduceTransparency = transparency ?? reduceTransparency;
    highContrast = contrast ?? highContrast;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', themeMode.index);
    await prefs.setString('palette', palette.name);
    await prefs.setBool('reduceMotion', reduceMotion);
    await prefs.setBool('reduceTransparency', reduceTransparency);
    await prefs.setBool('highContrast', highContrast);
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    positionSubscription.cancel();
    playerSubscription.cancel();
    refreshTimer?.cancel();
    saveTimer?.cancel();
    reconnect?.cancel();
    driftTimer?.cancel();
    channel?.sink.close();
    player.dispose();
    for (final p in stemPlayers.values) {
      p.dispose();
    }
    super.dispose();
  }
}
