import 'dart:io';
import 'package:dio/dio.dart';
import '../models/models.dart';

class ApiService {
  // Change to your .NET backend URL
  static const String baseUrl = 'http://localhost:5000/api/music';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(minutes: 15),
    sendTimeout: const Duration(minutes: 2),
  ));

  Future<GenerateResponse> generateSong({
    required File beatFile,
    required String lyrics,
    required String genre,
    File? speakerWav,
  }) async {
    final formData = FormData.fromMap({
      'beat': await MultipartFile.fromFile(beatFile.path,
          filename: beatFile.path.split('/').last),
      'lyrics': lyrics,
      'genre': genre,
      if (speakerWav != null)
        'speakerWav': await MultipartFile.fromFile(speakerWav.path,
            filename: speakerWav.path.split('/').last),
    });

    final response = await _dio.post('/generate', data: formData);
    return GenerateResponse.fromJson(response.data);
  }

  Future<JobStatusResponse> getStatus(String jobId) async {
    final response = await _dio.get('/status/$jobId');
    return JobStatusResponse.fromJson(response.data);
  }

  Future<String> downloadSong(String jobId, String savePath) async {
    await _dio.download(
      '/download/$jobId',
      savePath,
      onReceiveProgress: (received, total) {},
    );
    return savePath;
  }

  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get('/health');
    return Map<String, dynamic>.from(response.data);
  }
}
