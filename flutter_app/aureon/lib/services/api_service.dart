import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../models/preset_beats.dart';

class ApiService {
  static const String _defaultBaseUrl = 'http://10.0.2.2:5000'; // Android emulator
  // static const String _defaultBaseUrl = 'http://localhost:5000'; // iOS / macOS / Windows

  final Dio _dio;

  ApiService({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? _resolveBaseUrl(),
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ));

  static String _resolveBaseUrl() {
    if ((kIsWeb ? false : Platform.isAndroid)) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }

  /// Submit a beat + lyrics to start generation
  Future<GenerateResponse> generateSong({
    File? beatFile,
    String? presetBeatId,
    required String lyrics,
    required String genre,
    String preferredEngine = 'auto',
    String languageCode = 'en-IN',
    String scaleType = 'minor',
    double retuneSpeed = 0.1,
    File? speakerWav,
  }) async {
    final Map<String, dynamic> map = {
      'lyrics': lyrics,
      'genre': genre,
      'preferredEngine': preferredEngine,
      'languageCode': languageCode,
      'scaleType': scaleType,
      'retuneSpeed': retuneSpeed.toString(),
    };

    if (beatFile != null && await beatFile.exists()) {
      map['beat'] = await MultipartFile.fromFile(
        beatFile.path,
        filename: beatFile.path.split(('/')).last,
      );
    }

    if (speakerWav != null && await speakerWav.exists()) {
      map['speakerWav'] = await MultipartFile.fromFile(
        speakerWav.path,
        filename: speakerWav.path.split(('/')).last,
      );
    }

    final formData = FormData.fromMap(map);
    final response = await _dio.post('/api/music/generate', data: formData);
    return GenerateResponse.fromJson(response.data);
  }

  /// Poll status of a job
  Future<JobStatusResponse> getJobStatus(String jobId) async {
    final response = await _dio.get('/api/music/status/$jobId');
    return JobStatusResponse.fromJson(response.data);
  }

  /// Fetch preset beats list
  Future<List<PresetBeatItem>> getPresetBeats() async {
    try {
      final response = await _dio.get('/api/music/presets');
      if (response.data is List) {
        return (response.data as List)
            .map((b) => PresetBeatItem.fromJson(b))
            .toList();
      }
    } catch (_) {}
    return defaultPresetBeats;
  }

  /// Process voice recording with Sarvam Saaras AI
  Future<VoicePromptResult> processVoicePrompt(File voiceAudio, {String languageCode = 'unknown'}) async {
    final formData = FormData.fromMap({
      'languageCode': languageCode,
      'voiceAudio': await MultipartFile.fromFile(
        voiceAudio.path,
        filename: voiceAudio.path.split(('/')).last,
      ),
    });

    final response = await _dio.post('/api/music/voice/prompt', data: formData);
    return VoicePromptResult.fromJson(response.data);
  }

  /// Download finished MP3 to local cache
  Future<String> downloadSong(String jobId) async {
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/aureon_$jobId.mp3';

    await _dio.download(
      '/api/music/download/$jobId',
      savePath,
      options: Options(responseType: ResponseType.bytes),
    );

    return savePath;
  }

  /// Download separated stem WAV (vocals, drums, bass, other)
  Future<String> downloadStem(String jobId, String stemName) async {
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/aureon_${jobId}_$stemName.wav';

    await _dio.download(
      '/api/music/download/$jobId/stem/$stemName',
      savePath,
      options: Options(responseType: ResponseType.bytes),
    );

    return savePath;
  }

  /// Health check
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/api/music/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
