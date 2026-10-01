import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

typedef ProgressCallback = void Function(String jobId, String status, int progress, Map<String, dynamic>? critique);
typedef CompletedCallback = void Function(String jobId, String downloadUrl, Map<String, dynamic>? stems);
typedef FailedCallback = void Function(String jobId, String error);

class SignalRService {
  WebSocket? _socket;
  final String _hubUrl;
  bool _isConnected = false;

  ProgressCallback? onProgress;
  CompletedCallback? onCompleted;
  FailedCallback? onFailed;

  SignalRService({String? hubUrl})
      : _hubUrl = hubUrl ?? ((kIsWeb ? false : Platform.isAndroid) ? 'ws://10.0.2.2:5000/hub/music' : 'ws://localhost:5000/hub/music');

  bool get isConnected => _isConnected;

  Future<void> connect(String jobId) async {
    try {
      _socket = await WebSocket.connect(_hubUrl);
      _isConnected = true;

      // SignalR handshake protocol
      _socket!.add('{"protocol":"json","version":1}\x1e');

      _socket!.listen(
        (message) {
          _handleMessage(message.toString(), jobId);
        },
        onError: (err) {
          debugPrint('[SignalR] WebSocket error: $err');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('[SignalR] WebSocket closed');
          _isConnected = false;
        },
      );

      // Join job group
      final joinMsg = {
        "type": 1,
        "target": "JoinJobGroup",
        "arguments": [jobId]
      };
      _socket!.add('${jsonEncode(joinMsg)}\x1e');
    } catch (e) {
      debugPrint('[SignalR] Connection failed: $e');
      _isConnected = false;
    }
  }

  void _handleMessage(String raw, String targetJobId) {
    // SignalR messages are terminated by record separator 0x1e
    final parts = raw.split('\x1e');
    for (final part in parts) {
      if (part.trim().isEmpty || part.trim() == '{}') continue;
      try {
        final data = jsonDecode(part);
        if (data is Map<String, dynamic>) {
          final target = data['target'] as String?;
          final args = data['arguments'] as List?;

          if (target == 'OnJobProgress' && args != null && args.length >= 3) {
            final jobId = args[0] as String;
            final status = args[1] as String;
            final progress = (args[2] as num).toInt();
            final critique = args.length > 3 && args[3] is Map<String, dynamic> ? args[3] as Map<String, dynamic> : null;
            if (jobId == targetJobId) {
              onProgress?.call(jobId, status, progress, critique);
            }
          } else if (target == 'OnJobCompleted' && args != null && args.length >= 2) {
            final jobId = args[0] as String;
            final downloadUrl = args[1] as String;
            final stems = args.length > 2 && args[2] is Map<String, dynamic> ? args[2] as Map<String, dynamic> : null;
            if (jobId == targetJobId) {
              onCompleted?.call(jobId, downloadUrl, stems);
            }
          } else if (target == 'OnJobFailed' && args != null && args.isNotEmpty) {
            final jobId = args[0] as String;
            final error = args.length > 1 ? args[1] as String : 'Unknown error';
            if (jobId == targetJobId) {
              onFailed?.call(jobId, error);
            }
          }
        }
      } catch (e) {
        debugPrint('[SignalR] Parse error: $e');
      }
    }
  }

  void disconnect() {
    try {
      _socket?.close();
      _socket = null;
      _isConnected = false;
    } catch (_) {}
  }
}
