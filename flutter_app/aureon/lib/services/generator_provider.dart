import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class GeneratorProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  String? currentJobId;
  JobStatusResponse? jobStatus;
  bool isPolling = false;
  String? downloadedPath;
  String? errorMessage;

  void reset() {
    currentJobId = null;
    jobStatus = null;
    isPolling = false;
    downloadedPath = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> pollStatus() async {
    if (currentJobId == null || isPolling) return;
    isPolling = true;

    while (currentJobId != null) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final status = await _api.getStatus(currentJobId!);
        jobStatus = status;
        notifyListeners();

        if (status.status == JobStatus.done || status.status == JobStatus.failed) {
          break;
        }
      } catch (e) {
        errorMessage = e.toString();
        notifyListeners();
        break;
      }
    }
    isPolling = false;
    notifyListeners();
  }
}
