class JobStatus {
  static const queued = 'queued';
  static const analyzing = 'analyzing';
  static const separatingStems = 'separating_stems';
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
  final String? preferredEngine;
  final String? languageCode;

  GenerateResponse({
    required this.jobId,
    required this.status,
    this.preferredEngine,
    this.languageCode,
  });

  factory GenerateResponse.fromJson(Map<String, dynamic> json) =>
      GenerateResponse(
        jobId: json['job_id'] ?? '',
        status: json['status'] ?? '',
        preferredEngine: json['preferred_engine'],
        languageCode: json['language_code'],
      );
}

class JobStatusResponse {
  final String jobId;
  final String status;
  final int progress;
  final String? error;
  final Map<String, dynamic>? critique;
  final bool stemsAvailable;
  final bool outputReady;

  JobStatusResponse({
    required this.jobId,
    required this.status,
    required this.progress,
    this.error,
    this.critique,
    this.stemsAvailable = false,
    required this.outputReady,
  });

  factory JobStatusResponse.fromJson(Map<String, dynamic> json) =>
      JobStatusResponse(
        jobId: json['job_id'] ?? '',
        status: json['status'] ?? '',
        progress: json['progress'] ?? 0,
        error: json['error'],
        critique: json['critique'] is Map<String, dynamic> ? json['critique'] : null,
        stemsAvailable: json['stems_available'] ?? false,
        outputReady: json['output_ready'] ?? false,
      );

  String get statusLabel {
    switch (status) {
      case JobStatus.queued:
        return 'Queued...';
      case JobStatus.analyzing:
        return 'Analyzing Beat & BPM';
      case JobStatus.separatingStems:
        return 'Demucs 4-Stem Separation';
      case JobStatus.generatingFlow:
        return 'AI Lyricist Flow Grid';
      case JobStatus.synthesizing:
        return 'Sarvam / Neural Vocal Synthesis';
      case JobStatus.correcting:
        return 'Auto-Tune & Scale Pitch Lock';
      case JobStatus.mixing:
        return 'Sidechain & Mastering to -14 LUFS';
      case JobStatus.done:
        return 'Master Track Ready!';
      case JobStatus.failed:
        return 'Processing Failed';
      default:
        return status;
    }
  }
}

class PresetBeatItem {
  final String id;
  final String title;
  final String genre;
  final int bpm;
  final String key;
  final String description;

  const PresetBeatItem({
    required this.id,
    required this.title,
    required this.genre,
    required this.bpm,
    required this.key,
    required this.description,
  });

  factory PresetBeatItem.fromJson(Map<String, dynamic> json) => PresetBeatItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        genre: json['genre'] ?? 'rap',
        bpm: json['bpm'] ?? 120,
        key: json['key'] ?? 'C Minor',
        description: json['description'] ?? '',
      );
}

class VoicePromptResult {
  final String transcript;
  final String language;
  final String source;

  VoicePromptResult({
    required this.transcript,
    required this.language,
    required this.source,
  });

  factory VoicePromptResult.fromJson(Map<String, dynamic> json) =>
      VoicePromptResult(
        transcript: json['transcript'] ?? '',
        language: json['language'] ?? 'en-IN',
        source: json['source'] ?? 'sarvam_saaras',
      );
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
