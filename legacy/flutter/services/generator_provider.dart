import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'signalr_service.dart';

class GeneratorProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  SignalRService? _signalR;

  String? currentJobId;
  JobStatusResponse? status;
  bool isPolling = false;
  String? errorMessage;
  String? downloadedPath;
  Map<String, String> downloadedStems = {}; // stemName -> localFilePath

  void reset() {
    _signalR?.disconnect();
    currentJobId = null;
    status = null;
    isPolling = false;
    errorMessage = null;
    downloadedPath = null;
    downloadedStems.clear();
    notifyListeners();
  }

  void startLiveTracking(String jobId) {
    currentJobId = jobId;
    errorMessage = null;
    downloadedPath = null;
    notifyListeners();

    // 1. Initialize SignalR real-time stream
    _signalR?.disconnect();
    _signalR = SignalRService();
    _signalR!.onProgress = (jId, stat, prog, crit) {
      if (jId == currentJobId) {
        status = JobStatusResponse(
          jobId: jId,
          status: stat,
          progress: prog,
          critique: crit,
          outputReady: stat == JobStatus.done,
          stemsAvailable: prog >= 90,
        );
        notifyListeners();
      }
    };

    _signalR!.onCompleted = (jId, dlUrl, stems) {
      if (jId == currentJobId) {
        status = JobStatusResponse(
          jobId: jId,
          status: JobStatus.done,
          progress: 100,
          outputReady: true,
          stemsAvailable: true,
        );
        notifyListeners();
      }
    };

    _signalR!.onFailed = (jId, err) {
      if (jId == currentJobId) {
        errorMessage = err;
        status = JobStatusResponse(
          jobId: jId,
          status: JobStatus.failed,
          progress: status?.progress ?? 0,
          error: err,
          outputReady: false,
        );
        notifyListeners();
      }
    };

    _signalR!.connect(jobId);

    // 2. Also start polling loop as robust fallback
    pollStatus();
  }

  Future<void> pollStatus() async {
    if (currentJobId == null || isPolling) return;
    isPolling = true;

    while (isPolling && currentJobId != null) {
      try {
        final res = await _api.getJobStatus(currentJobId!);
        status = res;
        notifyListeners();

        if (res.status == JobStatus.done) {
          isPolling = false;
          _downloadFinal(currentJobId!);
          break;
        }

        if (res.status == JobStatus.failed) {
          isPolling = false;
          errorMessage = res.error ?? 'Job failed unexpectedly.';
          notifyListeners();
          break;
        }
      } catch (e) {
        // Network blip, continue
      }

      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _downloadFinal(String jobId) async {
    try {
      final path = await _api.downloadSong(jobId);
      downloadedPath = path;
      notifyListeners();

      // Also attempt to download 4 stems for DAW
      for (final stem in ['vocals', 'drums', 'bass', 'other']) {
        try {
          final stemPath = await _api.downloadStem(jobId, stem);
          downloadedStems[stem] = stemPath;
        } catch (_) {}
      }
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to download generated track: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _signalR?.disconnect();
    super.dispose();
  }
}
