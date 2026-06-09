class JobStatus {
  static const queued = 'queued';
  static const analyzing = 'analyzing';
  static const generatingFlow = 'generating_flow';
  static const synthesizing = 'synthesizing';
  static const correcting = 'correcting';
  static const mixing = 'mixing';
  static const done = 'done';
  static const failed = 'failed';
}

class GenerateResponse {
  final String jobId;
  final String status;

  GenerateResponse({required this.jobId, required this.status});

  factory GenerateResponse.fromJson(Map<String, dynamic> json) =>
      GenerateResponse(jobId: json['job_id'], status: json['status']);
}

class JobStatusResponse {
  final String jobId;
  final String status;
  final int progress;
  final String? error;
  final Map<String, dynamic>? critique;
  final bool outputReady;

  JobStatusResponse({
    required this.jobId,
    required this.status,
    required this.progress,
    this.error,
    this.critique,
    required this.outputReady,
  });

  factory JobStatusResponse.fromJson(Map<String, dynamic> json) =>
      JobStatusResponse(
        jobId: json['job_id'] ?? '',
        status: json['status'] ?? '',
        progress: json['progress'] ?? 0,
        error: json['error'],
        critique: json['critique'],
        outputReady: json['output_ready'] ?? false,
      );

  String get statusLabel {
    switch (status) {
      case JobStatus.queued:
        return 'Queued...';
      case JobStatus.analyzing:
        return 'Analyzing Beat';
      case JobStatus.generatingFlow:
        return 'Generating Flow';
      case JobStatus.synthesizing:
        return 'Synthesizing Vocals';
      case JobStatus.correcting:
        return 'Auto-Tune & Correction';
      case JobStatus.mixing:
        return 'Mixing Final Track';
      case JobStatus.done:
        return 'Done!';
      case JobStatus.failed:
        return 'Failed';
      default:
        return status;
    }
  }
}

class SongHistoryItem {
  final String jobId;
  final String genre;
  final String lyricsPreview;
  final DateTime createdAt;
  String status;

  SongHistoryItem({
    required this.jobId,
    required this.genre,
    required this.lyricsPreview,
    required this.createdAt,
    required this.status,
  });
}
