import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'studio_model.dart';

class MidiStudioPanel extends StatefulWidget {
  const MidiStudioPanel({super.key});
  @override
  State<MidiStudioPanel> createState() => _MidiStudioPanelState();
}

class _MidiStudioPanelState extends State<MidiStudioPanel> {
  int division = 4;
  bool snap = true;
  String feedback = '';
  Json? beforeQuantize;
  Json? afterQuantize;
  final defaults = <String, dynamic>{
    'version': 1,
    'ppq': 480,
    'preset': 'keys',
    'notes': [],
    'tempos': [],
    'sustain': [],
    'loop_start': 0,
    'loop_end': 0,
    'loop_repeats': 1,
  };
  void save(StudioModel model, Json score) {
    model.edit('midi', score);
    setState(() {
      beforeQuantize = null;
      afterQuantize = null;
    });
  }

  Future<void> numbers(
    String title,
    Map<String, int> initial,
    void Function(Map<String, int>) apply,
  ) async {
    final values = initial.map((k, v) => MapEntry(k, v.toString()));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in initial.entries)
                TextFormField(
                  initialValue: entry.value.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: entry.key),
                  onChanged: (s) => values[entry.key] = s,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    try {
      apply(values.map((k, v) => MapEntry(k, int.parse(v))));
    } on FormatException catch (e) {
      setState(() => feedback = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<StudioModel>();
    final score = Json.from(model.current?['midi'] ?? defaults);
    final notes = (score['notes'] as List).map((n) => Json.from(n)).toList();
    final ppq = score['ppq'] as int;
    final step = math.max(1, (ppq / division).round());
    final end = notes.fold<int>(
      ppq * 4,
      (maxTick, n) => math.max(maxTick, (n['start'] + n['length']) as int),
    );
    void note(int tick, int pitch, {int? index}) {
      final n = index == null
          ? {
              'start': tick,
              'pitch': pitch,
              'length': step,
              'velocity': 96,
              'channel': 0,
            }
          : notes[index];
      numbers(
        'Note editor',
        {
          for (final k in ['start', 'length', 'pitch', 'velocity', 'channel'])
            k: n[k] as int,
        },
        (v) {
          if (v['start']! < 0 ||
              v['length']! < 1 ||
              v['start']! + v['length']! > 8000000 ||
              v['pitch']! < 0 ||
              v['pitch']! > 127 ||
              v['velocity']! < 1 ||
              v['velocity']! > 127 ||
              v['channel']! < 0 ||
              v['channel']! > 15) {
            throw const FormatException(
              'Enter valid tick bounds, pitch 0–127, velocity 1–127 and channel 0–15.',
            );
          }
          final changed = [...notes];
          final updated = {
            ...v,
            'start': snap ? (v['start']! / step).round() * step : v['start'],
          };
          if (index == null) {
            changed.add(updated);
          } else {
            changed[index] = updated;
          }
          save(model, {...score, 'notes': changed});
        },
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MIDI composition',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '$ppq ticks per quarter note · ${notes.length} notes · ${score['tempos'].length} tempo events · ${score['sustain'].length} sustain events',
            ),
            const Text(
              'Tap the grid to compose or use the numeric note editor. Render the score for playback and arrangement use.',
            ),
            LayoutBuilder(
              builder: (context, box) => Semantics(
                label: 'Piano roll. Use Add note for keyboard editing.',
                child: GestureDetector(
                  onTapDown: (e) => note(
                    (e.localPosition.dx / box.maxWidth * end).round(),
                    72 - (e.localPosition.dy / 144 * 24).floor().clamp(0, 23),
                  ),
                  child: CustomPaint(
                    size: Size(box.maxWidth, 144),
                    painter: _Roll(notes, end, Theme.of(context).colorScheme),
                  ),
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: score['preset'],
              decoration: const InputDecoration(
                labelText: 'Synthesized instrument',
              ),
              items: [
                for (final p in ['keys', 'bass', 'pad', 'pluck'])
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (p) {
                if (p != null) save(model, {...score, 'preset': p});
              },
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: notes.length >= 2048 ? null : () => note(0, 60),
                  child: const Text('Add note'),
                ),
                FilterChip(
                  label: const Text('Snap to grid'),
                  selected: snap,
                  onSelected: (v) => setState(() => snap = v),
                ),
                DropdownButton<int>(
                  isExpanded: true,
                  value: division,
                  items: [
                    for (final d in [1, 2, 4, 8])
                      DropdownMenuItem(
                        value: d,
                        child: Text(
                          '$d divisions per beat',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (d) => setState(() => division = d!),
                ),
                OutlinedButton(
                  onPressed: notes.isEmpty
                      ? null
                      : () {
                          final next = {
                            ...score,
                            'notes': [
                              for (final n in notes)
                                {
                                  ...n,
                                  'start':
                                      ((n['start'] as int) / step).round() *
                                      step,
                                },
                            ],
                          };
                          model.edit('midi', next);
                          setState(() {
                            beforeQuantize = score;
                            afterQuantize = next;
                          });
                        },
                  child: const Text('Quantize starts'),
                ),
                OutlinedButton(
                  onPressed:
                      beforeQuantize == null ||
                          jsonEncode(model.current?['midi']) !=
                              jsonEncode(afterQuantize)
                      ? null
                      : () => save(model, beforeQuantize!),
                  child: const Text('Undo quantize'),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('All notes · numeric editor'),
              children: [
                for (final (i, n) in notes.indexed)
                  ListTile(
                    title: Text('Pitch ${n['pitch']} · tick ${n['start']}'),
                    subtitle: Text(
                      'Length ${n['length']} · velocity ${n['velocity']}',
                    ),
                    onTap: () => note(0, 0, index: i),
                    trailing: IconButton(
                      tooltip: 'Remove note ${i + 1}',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => save(model, {
                        ...score,
                        'notes': [...notes]..removeAt(i),
                      }),
                    ),
                  ),
              ],
            ),
            OutlinedButton(
              onPressed: () => numbers(
                'Rendered loop',
                {
                  'Start tick': score['loop_start'],
                  'End tick': score['loop_end'],
                  'Repetitions': score['loop_repeats'],
                },
                (v) {
                  final a = v['Start tick']!,
                      b = v['End tick']!,
                      r = v['Repetitions']!;
                  if (a < 0 ||
                      b < 0 ||
                      b > 8000000 ||
                      r < 1 ||
                      r > 8 ||
                      ((a != 0 || b != 0 || r > 1) && b <= a)) {
                    throw const FormatException(
                      'Choose an ordered loop range and 1–8 repetitions.',
                    );
                  }
                  save(model, {
                    ...score,
                    'loop_start': a,
                    'loop_end': b,
                    'loop_repeats': r,
                  });
                },
              ),
              child: Text(
                'Loop ${score['loop_start']}–${score['loop_end']} · ${score['loop_repeats']}×',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: model.busy
                      ? null
                      : () => model.guard(() async {
                          final chosen = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['mid', 'midi'],
                            withData: true,
                          );
                          if (chosen == null) return;
                          final file = chosen.files.single;
                          if (file.bytes == null || file.size > 262144) {
                            throw const FormatException(
                              'Choose a MIDI file up to 256 KiB.',
                            );
                          }
                          final pid = model.current!['id'];
                          final result = await model.request(
                            'POST',
                            '/projects/$pid/midi/import',
                            data: FormData.fromMap({
                              'file': MultipartFile.fromBytes(
                                file.bytes!,
                                filename: file.name,
                              ),
                            }),
                          );
                          if (!context.mounted || model.current?['id'] != pid) {
                            return;
                          }
                          final accepted = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Replace current score?'),
                              content: Text(
                                '${result['midi']['notes'].length} imported notes. Unsupported events: ${result['unsupported']}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Use imported score'),
                                ),
                              ],
                            ),
                          );
                          if (accepted == true &&
                              mounted &&
                              model.current?['id'] == pid) {
                            save(model, Json.from(result['midi']));
                          }
                        }),
                  child: const Text('Import MIDI'),
                ),
                OutlinedButton(
                  onPressed: model.dirty || model.saving || notes.isEmpty
                      ? null
                      : () => model.download(
                          '/api/v1/projects/${model.current!['id']}/midi/export',
                          'composition.mid',
                        ),
                  child: const Text('Export saved MIDI'),
                ),
                FilledButton(
                  onPressed: model.busy || model.rendering || notes.isEmpty
                      ? null
                      : () => model.generate('midi_render'),
                  child: const Text('Render instrument'),
                ),
              ],
            ),
            if (feedback.isNotEmpty)
              Semantics(liveRegion: true, child: Text(feedback)),
          ],
        ),
      ),
    );
  }
}

class _Roll extends CustomPainter {
  final List<Json> notes;
  final int end;
  final ColorScheme colors;
  _Roll(this.notes, this.end, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colors.surfaceContainerHighest;
    canvas.drawRect(Offset.zero & size, paint);
    paint.color = colors.outlineVariant;
    for (var i = 0; i <= 24; i++) {
      final y = size.height * i / 24;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var i = 0; i <= 16; i++) {
      final x = size.width * i / 16;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    paint.color = colors.primary;
    for (final n in notes) {
      final row = 72 - (n['pitch'] as int);
      if (row < 0 || row >= 24) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * n['start'] / end,
          row * size.height / 24,
          math.max(2.0, size.width * n['length'] / end),
          size.height / 24,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Roll old) => true;
}
