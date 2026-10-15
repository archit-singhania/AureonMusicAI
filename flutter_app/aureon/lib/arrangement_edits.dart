import 'dart:convert';
import 'dart:math' as math;

typedef ArrangementJson = Map<String, dynamic>;
const arrangementRate = 44100;
const arrangementLimit = 180 * arrangementRate;
ArrangementJson cloneArrangement(ArrangementJson value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));
ArrangementJson emptyArrangement() => {
  'version': 1,
  'sample_rate': arrangementRate,
  'tracks': <dynamic>[],
  'markers': <dynamic>[],
};
int snappedSample(int sample, double bpm, bool snap) {
  final step = (arrangementRate * 60 / bpm / 4).round();
  return snap
      ? math.max(0, (sample / step).round() * step)
      : math.max(0, sample);
}

void splitArrangementClip(
  ArrangementJson document,
  String clipId,
  int sample,
  String nextId,
) {
  for (final track in document['tracks'] as List) {
    final clips = track['clips'] as List;
    final index = clips.indexWhere((c) => c['id'] == clipId);
    if (index < 0) continue;
    final clip = Map<String, dynamic>.from(clips[index]);
    if ((clip['repeats'] ?? 1) != 1) {
      throw const FormatException(
        'Set repetitions to one before splitting this clip.',
      );
    }
    final cut = sample - (clip['start'] as int);
    final length = clip['length'] as int;
    if (cut <= (clip['fade_in'] ?? 0) ||
        cut >= length - (clip['fade_out'] ?? 0)) {
      throw const FormatException(
        'Split inside the clip body, outside its fades.',
      );
    }
    clips[index] = {...clip, 'length': cut, 'fade_out': 0};
    clips.insert(index + 1, {
      ...clip,
      'id': nextId,
      'start': sample,
      'source_start': (clip['source_start'] as int) + cut,
      'length': length - cut,
      'fade_in': 0,
    });
    return;
  }
  throw const FormatException('Select a clip before splitting.');
}

double automationValue(ArrangementJson envelope, int sample) {
  final points = envelope['points'] as List;
  if (points.isEmpty) return 0;
  if (sample <= points.first['sample']) {
    return (points.first['value'] as num).toDouble();
  }
  for (var i = 1; i < points.length; i++) {
    final left = points[i - 1], right = points[i];
    if (sample < right['sample']) {
      if (envelope['interpolation'] == 'hold') {
        return (left['value'] as num).toDouble();
      }
      final fraction =
          (sample - left['sample']) / (right['sample'] - left['sample']);
      return (left['value'] as num).toDouble() +
          fraction * ((right['value'] as num) - (left['value'] as num));
    }
  }
  return (points.last['value'] as num).toDouble();
}
