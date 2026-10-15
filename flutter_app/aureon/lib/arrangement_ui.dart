import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'arrangement_edits.dart';
import 'studio_model.dart';
import 'liquid_glass.dart';

class ArrangementPanel extends StatefulWidget {
  const ArrangementPanel({super.key});
  @override
  State<ArrangementPanel> createState() => _ArrangementPanelState();
}

class _ArrangementPanelState extends State<ArrangementPanel> {
  String? selected, selectedTrack, project;
  int cursor = 0, serial = 0;
  double zoom = 12;
  bool snap = true;
  bool followPreview = false;
  String error = '';
  final Map<String, double> dragDistances = {};
  String uid() => 'edit-${DateTime.now().microsecondsSinceEpoch}-${serial++}';
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          zoom = p.getDouble('arrangement_zoom') ?? 12;
          snap = p.getBool('arrangement_snap') ?? true;
        });
      }
    });
  }

  void preference() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('arrangement_zoom', zoom);
    await p.setBool('arrangement_snap', snap);
  }

  ArrangementJson document(StudioModel m) => m.current?['arrangement'] == null
      ? emptyArrangement()
      : cloneArrangement(Map<String, dynamic>.from(m.current!['arrangement']));
  void commit(StudioModel m, ArrangementJson doc) {
    m.edit('document_version', 2);
    m.edit('arrangement', doc);
    setState(() {
      error = '';
    });
  }

  List<dynamic> tracks(ArrangementJson doc) => doc['tracks'] as List;
  Future<void> fields(
    String title,
    Map<String, String> initial,
    void Function(Map<String, String>) accept,
  ) async {
    final controls = Map<String, String>.from(initial);
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      animationStyle:
          context.read<StudioModel>().reduceMotion ||
              MediaQuery.of(context).disableAnimations
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 220),
              reverseDuration: Duration(milliseconds: 180),
            ),
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: controls.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          initialValue: e.value,
                          onChanged: (v) {
                            controls[e.key] = v;
                          },
                          decoration: InputDecoration(labelText: e.key),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter a value'
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Apply edit'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      try {
        accept(controls.map((k, v) => MapEntry(k, v.trim())));
      } catch (e) {
        setState(() {
          error = e is FormatException
              ? e.message.toString()
              : 'Invalid edit. Check the entered values.';
        });
      }
    }
  }

  Future<void> addSource(StudioModel m, Json source) async {
    var metrics = Json.from(source['metrics'] ?? {});
    if (metrics['sample_count'] == null) {
      try {
        metrics = Json.from(
          await m.request(
            'GET',
            '/assets/${source['id']}/arrangement-metadata',
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            error = 'Audio metadata is unavailable. Retry after reconnecting.';
          });
        }
        return;
      }
    }
    if (!mounted) return;
    final count = (metrics['sample_count'] as num?)?.toInt();
    if (count == null || count <= 0) {
      setState(() {
        error =
            'Re-analyze this audio to obtain exact sample boundaries before adding it.';
      });
      return;
    }
    final doc = document(m);
    if (tracks(doc).length >= 16) {
      setState(() {
        error = 'This arrangement supports up to 16 tracks.';
      });
      return;
    }
    final tid = uid(), cid = uid();
    tracks(doc).add({
      'id': tid,
      'name': source['name'] ?? 'Audio',
      'gain': 1.0,
      'pan': 0.0,
      'mute': false,
      'automation': [],
      'clips': [
        {
          'id': cid,
          'asset_id': source['id'],
          'start': 0,
          'source_start': 0,
          'length': count,
          'repeats': 1,
          'fade_in': 0,
          'fade_out': 0,
        },
      ],
    });
    selected = cid;
    selectedTrack = tid;
    commit(m, doc);
  }

  void clipEdit(StudioModel m, Json clip) {
    fields(
      'Clip inspector · integer samples',
      {
        'Timeline start': '${clip['start']}',
        'Source start': '${clip['source_start']}',
        'Length': '${clip['length']}',
        'Repetitions': '${clip['repeats'] ?? 1}',
        'Fade in': '${clip['fade_in'] ?? 0}',
        'Fade out': '${clip['fade_out'] ?? 0}',
      },
      (v) {
        final numbers = v.map((k, value) => MapEntry(k, int.parse(value)));
        final start = numbers['Timeline start']!,
            source = numbers['Source start']!,
            length = numbers['Length']!,
            repeat = numbers['Repetitions']!,
            fi = numbers['Fade in']!,
            fo = numbers['Fade out']!;
        if (start < 0 ||
            source < 0 ||
            length <= 0 ||
            repeat < 1 ||
            repeat > 16 ||
            fi < 0 ||
            fo < 0 ||
            fi + fo > length ||
            start + length * repeat > arrangementLimit) {
          throw const FormatException(
            'Use valid sample bounds, repetitions 1–16, and fades within the clip.',
          );
        }
        final doc = document(m);
        for (final t in tracks(doc)) {
          for (final c in t['clips']) {
            if (c['id'] == clip['id']) {
              c.addAll({
                'start': start,
                'source_start': source,
                'length': length,
                'repeats': repeat,
                'fade_in': fi,
                'fade_out': fo,
              });
            }
          }
        }
        commit(m, doc);
      },
    );
  }

  void move(StudioModel m, String id, int next) {
    final doc = document(m);
    for (final t in tracks(doc)) {
      for (final c in t['clips']) {
        if (c['id'] == id) {
          final value = snappedSample(
            next,
            (m.current!['bpm'] as num).toDouble(),
            snap,
          );
          if (value + c['length'] * (c['repeats'] ?? 1) > arrangementLimit) {
            setState(() {
              error = 'Moving this clip would exceed 180 seconds.';
            });
            return;
          }
          c['start'] = value;
        }
      }
    }
    commit(m, doc);
  }

  void envelopeEdit(
    StudioModel m,
    String trackId,
    String parameter, [
    int? index,
  ]) {
    final doc = document(m);
    final t = tracks(doc).firstWhere((t) => t['id'] == trackId);
    final envs = t['automation'] as List;
    var env = envs
        .cast<Json>()
        .where((e) => e['parameter'] == parameter)
        .firstOrNull;
    final point = index == null ? null : env!['points'][index];
    fields(
      '$parameter automation point',
      {
        'Sample': '${point?['sample'] ?? cursor}',
        'Value': '${point?['value'] ?? (parameter == 'volume' ? 1 : 0)}',
      },
      (v) {
        final sample = int.parse(v['Sample']!),
            value = double.parse(v['Value']!);
        if (sample < 0 ||
            sample > arrangementLimit ||
            !value.isFinite ||
            value < (parameter == 'volume' ? 0 : -1) ||
            value > (parameter == 'volume' ? 2 : 1)) {
          throw const FormatException(
            'Enter a valid sample and parameter value.',
          );
        }
        env ??= {
          'parameter': parameter,
          'interpolation': 'linear',
          'points': <dynamic>[],
        };
        if (!envs.contains(env)) envs.add(env);
        final points = env!['points'] as List;
        if (points.asMap().entries.any(
          (e) => e.key != index && e.value['sample'] == sample,
        )) {
          throw const FormatException(
            'Each point needs a unique sample position.',
          );
        }
        if (index == null) {
          points.add({'sample': sample, 'value': value});
        } else {
          points[index] = {'sample': sample, 'value': value};
        }
        points.sort(
          (a, b) => (a['sample'] as int).compareTo(b['sample'] as int),
        );
        commit(m, doc);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    if (project != m.current?['id']) {
      project = m.current?['id'];
      selected = null;
      selectedTrack = null;
      cursor = 0;
      followPreview = false;
    }
    final doc = document(m), list = tracks(doc);
    Json? clip, track;
    for (final t in list) {
      if (t['id'] == selectedTrack) track = Json.from(t);
      for (final c in t['clips']) {
        if (c['id'] == selected) {
          clip = Json.from(c);
          track = Json.from(t);
        }
      }
    }
    if (m.playing || followPreview) {
      cursor = (m.position.inMicroseconds * arrangementRate ~/ 1000000).clamp(
        0,
        arrangementLimit,
      );
      followPreview = true;
    }
    final sample = cursor;
    final end = list
        .expand((t) => t['clips'] as List)
        .fold<int>(
          0,
          (v, c) => math.max(
            v,
            (c['start'] as int) +
                (c['length'] as int) * ((c['repeats'] ?? 1) as int),
          ),
        );
    final width = math.max(
      800.0,
      math.max(10, end / arrangementRate + 2) * zoom,
    );
    final sources = m.assets
        .where((a) => (a['media_type'] as String? ?? '').startsWith('audio/'))
        .toList();
    if (m.master != null && !sources.any((a) => a['id'] == m.master!['id'])) {
      sources.add(m.master!);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arrangement timeline',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Non-destructive editing · 44,100 samples/second. Preview plays the last completed render; render again after edits to hear the updated arrangement and curves.',
            ),
            if (error.isNotEmpty)
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            LiquidGlass(
              reduceMotion: m.reduceMotion,
              reduceTransparency: m.reduceTransparency,
              highContrast: m.highContrast,
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PopupMenuButton<Json>(
                    tooltip: 'Add audio track',
                    itemBuilder: (context) => sources
                        .map(
                          (a) => PopupMenuItem(
                            value: a,
                            child: Text(a['name'] ?? 'Audio'),
                          ),
                        )
                        .toList(),
                    onSelected: (a) => addSource(m, a),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Add audio track'),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Snap to 1/16 beat'),
                    selected: snap,
                    onSelected: (v) {
                      setState(() {
                        snap = v;
                      });
                      preference();
                    },
                  ),
                  SizedBox(
                    width: 160,
                    child: Slider(
                      semanticFormatterCallback: (v) =>
                          'Timeline zoom ${v.round()} pixels per second',
                      min: 4,
                      max: 40,
                      value: zoom.clamp(4, 40),
                      onChanged: (v) {
                        setState(() {
                          zoom = v;
                        });
                        preference();
                      },
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => fields(
                      'Edit cursor',
                      {'Sample': '$cursor'},
                      (v) {
                        final value = int.parse(v['Sample']!);
                        if (value < 0 || value > arrangementLimit) {
                          throw const FormatException(
                            'Cursor must be within 180 seconds.',
                          );
                        }
                        setState(() {
                          cursor = value;
                          followPreview = false;
                        });
                        if (m.playing) {
                          m.seek(
                            Duration(
                              microseconds: cursor * 1000000 ~/ arrangementRate,
                            ),
                          );
                        }
                      },
                    ),
                    child: Text('Cursor $sample samples'),
                  ),
                  FilledButton.icon(
                    onPressed: m.rendering || m.busy || end == 0
                        ? null
                        : () => m.generate('arrangement_render'),
                    icon: const Icon(Icons.multitrack_audio),
                    label: const Text('Render arrangement'),
                  ),
                  OutlinedButton(
                    onPressed: m.master == null
                        ? null
                        : () {
                            setState(() {
                              followPreview = true;
                            });
                            m.togglePlay();
                          },
                    child: Text(
                      m.playing
                          ? 'Pause rendered preview'
                          : 'Play rendered preview',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Text(
                'No tracks yet. Add an owned audio asset or reopen a completed project to initialize its original master.',
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: math.max(70, list.length * 82 + 40).toDouble(),
                child: GestureDetector(
                  onTapDown: (d) {
                    final value = snappedSample(
                      (d.localPosition.dx / zoom * arrangementRate).round(),
                      (m.current!['bpm'] as num).toDouble(),
                      snap,
                    );
                    setState(() {
                      cursor = value.clamp(0, arrangementLimit);
                      followPreview = false;
                    });
                    if (m.playing) {
                      m.seek(
                        Duration(
                          microseconds: cursor * 1000000 ~/ arrangementRate,
                        ),
                      );
                    }
                  },
                  child: Stack(
                    children: [
                      for (var second = 0; second <= width / zoom; second++)
                        Positioned(
                          left: second * zoom,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 18,
                                  child:
                                      second %
                                              math.max(1, (80 / zoom).ceil()) ==
                                          0
                                      ? Text(
                                          '${(second * (m.current!['bpm'] as num) / 60).toStringAsFixed(1)} beats',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                        )
                                      : null,
                                ),
                                Expanded(
                                  child: Container(
                                    width: 1,
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      for (var i = 0; i < list.length; i++) ...[
                        Positioned(
                          left: 4,
                          top: 25 + i * 82,
                          child: Text(
                            '${i + 1}. ${list[i]['name']}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        for (final c in list[i]['clips'])
                          Positioned(
                            left: math.max(
                              0,
                              (c['start'] as int) / arrangementRate * zoom +
                                  (dragDistances[c['id']] ?? 0),
                            ),
                            top: 44 + i * 82,
                            width: math.max(
                              48,
                              (c['length'] as int) *
                                  ((c['repeats'] ?? 1) as int) /
                                  arrangementRate *
                                  zoom,
                            ),
                            height: 48,
                            child: GestureDetector(
                              dragStartBehavior: DragStartBehavior.down,
                              onHorizontalDragStart: (_) {
                                setState(() {
                                  selected = c['id'];
                                  selectedTrack = list[i]['id'];
                                  dragDistances[c['id']] = 0;
                                });
                              },
                              onHorizontalDragUpdate: (d) {
                                setState(() {
                                  dragDistances[c['id']] =
                                      (dragDistances[c['id']] ?? 0) +
                                      d.delta.dx;
                                });
                              },
                              onHorizontalDragEnd: (d) {
                                final distance =
                                    dragDistances.remove(c['id']) ?? 0;
                                move(
                                  m,
                                  c['id'],
                                  (c['start'] as int) +
                                      (distance / zoom * arrangementRate)
                                          .round(),
                                );
                              },
                              onHorizontalDragCancel: () {
                                setState(() {
                                  dragDistances.remove(c['id']);
                                });
                              },
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: c['id'] == selected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                ),
                                onPressed: () => setState(() {
                                  selected = c['id'];
                                  selectedTrack = list[i]['id'];
                                }),
                                child: Text(
                                  '${c['id'] == selected ? 'Selected · ' : ''}${(c['length'] / arrangementRate).toStringAsFixed(2)}s ×${c['repeats'] ?? 1}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                      ],
                      for (final marker in doc['markers'])
                        Positioned(
                          left: marker['sample'] / arrangementRate * zoom,
                          top: 18,
                          child: Text(
                            '◆ ${marker['name']}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      Positioned(
                        left: sample / arrangementRate * zoom,
                        top: 20,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ExpansionTile(
              title: const Text('Accessible track and clip list'),
              children: [
                for (final t in list) ...[
                  ListTile(
                    title: Text(t['name']),
                    subtitle: Text('${(t['clips'] as List).length} clips'),
                    onTap: () => setState(() {
                      selectedTrack = t['id'];
                      selected = null;
                    }),
                  ),
                  for (final c in t['clips'])
                    ListTile(
                      title: Text(
                        'Clip ${(t['clips'] as List).indexOf(c) + 1} · ${t['name']}',
                      ),
                      subtitle: Text(
                        'Start ${c['start']} · source ${c['source_start']} · length ${c['length']} samples · repeats ${c['repeats'] ?? 1}',
                      ),
                      onTap: () => setState(() {
                        selectedTrack = t['id'];
                        selected = c['id'];
                      }),
                    ),
                ],
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => fields(
                    'Section marker',
                    {'Name': 'Section', 'Sample': '$cursor'},
                    (v) {
                      final pos = int.parse(v['Sample']!);
                      if (pos < 0 || pos > arrangementLimit) {
                        throw const FormatException('Invalid marker position.');
                      }
                      final next = document(m);
                      (next['markers'] as List).add({
                        'name': v['Name'],
                        'sample': pos,
                      });
                      commit(m, next);
                    },
                  ),
                  child: const Text('Add section marker'),
                ),
                for (final marker in doc['markers'])
                  InputChip(
                    label: Text('${marker['name']} · ${marker['sample']}'),
                    onDeleted: () {
                      final next = document(m);
                      (next['markers'] as List).removeWhere(
                        (x) =>
                            x['name'] == marker['name'] &&
                            x['sample'] == marker['sample'],
                      );
                      commit(m, next);
                    },
                  ),
              ],
            ),
            if (clip != null)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => clipEdit(m, clip!),
                    child: const Text('Inspect / trim / loop / fades'),
                  ),
                  OutlinedButton(
                    onPressed: () => move(
                      m,
                      clip!['id'],
                      (clip['start'] as int) -
                          (arrangementRate *
                                  60 /
                                  (m.current!['bpm'] as num) /
                                  4)
                              .round(),
                    ),
                    child: const Text('Move clip left'),
                  ),
                  OutlinedButton(
                    onPressed: () => move(
                      m,
                      clip!['id'],
                      (clip['start'] as int) +
                          (arrangementRate *
                                  60 /
                                  (m.current!['bpm'] as num) /
                                  4)
                              .round(),
                    ),
                    child: const Text('Move clip right'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      try {
                        final next = document(m);
                        splitArrangementClip(next, clip!['id'], cursor, uid());
                        commit(m, next);
                      } catch (e) {
                        setState(() {
                          error = e.toString();
                        });
                      }
                    },
                    child: const Text('Split clip at cursor'),
                  ),
                  TextButton(
                    onPressed: () {
                      final next = document(m);
                      for (final t in tracks(next)) {
                        (t['clips'] as List).removeWhere(
                          (c) => c['id'] == selected,
                        );
                      }
                      selected = null;
                      commit(m, next);
                    },
                    child: const Text('Remove clip'),
                  ),
                ],
              ),
            if (track != null) ...[
              Text(
                'Track inspector · ${track['name']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => fields(
                      'Track settings',
                      {
                        'Name': track!['name'],
                        'Gain': '${track['gain'] ?? 1}',
                        'Pan': '${track['pan'] ?? 0}',
                      },
                      (v) {
                        final gain = double.parse(v['Gain']!),
                            pan = double.parse(v['Pan']!);
                        if (!gain.isFinite ||
                            !pan.isFinite ||
                            gain < 0 ||
                            gain > 2 ||
                            pan < -1 ||
                            pan > 1) {
                          throw const FormatException(
                            'Gain must be 0–2 and pan −1–1.',
                          );
                        }
                        final next = document(m);
                        tracks(
                          next,
                        ).firstWhere((t) => t['id'] == track!['id']).addAll({
                          'name': v['Name'],
                          'gain': gain,
                          'pan': pan,
                        });
                        commit(m, next);
                      },
                    ),
                    child: const Text('Track settings'),
                  ),
                  TextButton(
                    onPressed: () {
                      final next = document(m);
                      tracks(next).removeWhere((t) => t['id'] == track!['id']);
                      selected = null;
                      selectedTrack = null;
                      commit(m, next);
                    },
                    child: const Text('Remove track'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final parameter in ['volume', 'pan'])
                    OutlinedButton(
                      onPressed: () => envelopeEdit(m, track!['id'], parameter),
                      child: Text('Add $parameter point'),
                    ),
                  FilterChip(
                    label: const Text('Mute track'),
                    selected: track['mute'] ?? false,
                    onSelected: (v) {
                      final next = document(m);
                      tracks(
                        next,
                      ).firstWhere((t) => t['id'] == track!['id'])['mute'] = v;
                      commit(m, next);
                    },
                  ),
                ],
              ),
              for (final envelope in track['automation']) ...[
                Text(
                  '${envelope['parameter']} at cursor: ${automationValue(Json.from(envelope), sample).toStringAsFixed(3)} · applied during render',
                ),
                DropdownButton<String>(
                  value: envelope['interpolation'],
                  items: ['linear', 'hold']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text('$v interpolation'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final next = document(m);
                    final env =
                        (tracks(next).firstWhere(
                                  (t) => t['id'] == track!['id'],
                                )['automation']
                                as List)
                            .firstWhere(
                              (e) => e['parameter'] == envelope['parameter'],
                            );
                    env['interpolation'] = v;
                    commit(m, next);
                  },
                ),
                SizedBox(
                  height: 90,
                  width: double.infinity,
                  child: EditableEnvelope(
                    key: ValueKey('${track['id']}:${envelope['parameter']}'),
                    envelope: Json.from(envelope),
                    end: math.max(end, arrangementRate),
                    bpm: (m.current!['bpm'] as num).toDouble(),
                    snap: snap,
                    onError: (message) => setState(() {
                      error = message;
                    }),
                    onChanged: (edited) {
                      final next = document(m);
                      final envs =
                          tracks(next).firstWhere(
                                (t) => t['id'] == track!['id'],
                              )['automation']
                              as List;
                      envs[envs.indexWhere(
                            (e) => e['parameter'] == edited['parameter'],
                          )] =
                          edited;
                      commit(m, next);
                    },
                  ),
                ),
                for (var i = 0; i < (envelope['points'] as List).length; i++)
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        'Sample ${envelope['points'][i]['sample']} → ${envelope['points'][i]['value']}',
                      ),
                      TextButton(
                        onPressed: () => envelopeEdit(
                          m,
                          track!['id'],
                          envelope['parameter'],
                          i,
                        ),
                        child: const Text('Edit point'),
                      ),
                      TextButton(
                        onPressed: () {
                          final next = document(m);
                          final envs =
                              tracks(next).firstWhere(
                                    (t) => t['id'] == track!['id'],
                                  )['automation']
                                  as List;
                          final env = envs.firstWhere(
                            (e) => e['parameter'] == envelope['parameter'],
                          );
                          (env['points'] as List).removeAt(i);
                          if ((env['points'] as List).isEmpty) envs.remove(env);
                          commit(m, next);
                        },
                        child: const Text('Remove point'),
                      ),
                    ],
                  ),
              ],
            ],
            const SizedBox(height: 8),
            const Text(
              'Crossfades: overlap two clips and give the outgoing clip a fade-out and incoming clip a fade-in. Set repetitions to one before splitting; split outside fade regions. All controls have keyboard alternatives.',
            ),
          ],
        ),
      ),
    );
  }
}

class EnvelopePainter extends CustomPainter {
  EnvelopePainter(this.envelope, this.end, this.color);
  final Json envelope;
  final int end;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final low = envelope['parameter'] == 'volume' ? 0.0 : -1.0;
    final range = envelope['parameter'] == 'volume' ? 2.0 : 2.0;
    for (var x = 0; x <= size.width; x++) {
      final value = automationValue(envelope, (x / size.width * end).round());
      final y = size.height - 8 - (value - low) / range * (size.height - 16);
      if (x == 0) {
        path.moveTo(x.toDouble(), y);
      } else {
        path.lineTo(x.toDouble(), y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (final p in envelope['points']) {
      canvas.drawCircle(
        Offset(
          (p['sample'] as int) / end * size.width,
          size.height -
              8 -
              ((p['value'] as num) - low) / range * (size.height - 16),
        ),
        4,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(EnvelopePainter oldDelegate) => true;
}

class EditableEnvelope extends StatefulWidget {
  const EditableEnvelope({
    super.key,
    required this.envelope,
    required this.end,
    required this.bpm,
    required this.snap,
    required this.onChanged,
    required this.onError,
  });
  final Json envelope;
  final int end;
  final double bpm;
  final bool snap;
  final void Function(Json) onChanged;
  final void Function(String) onError;
  @override
  State<EditableEnvelope> createState() => _EditableEnvelopeState();
}

class _EditableEnvelopeState extends State<EditableEnvelope> {
  Json? draft;
  int? index;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final end = (widget.envelope['points'] as List).fold<int>(
        widget.end,
        (value, p) => math.max(value, p['sample'] as int),
      );
      final low = widget.envelope['parameter'] == 'volume' ? 0.0 : -1.0;
      Offset position(dynamic p) => Offset(
        p['sample'] / end * c.maxWidth,
        82 - ((p['value'] as num) - low) / 2 * 74,
      );
      return Semantics(
        label:
            '${widget.envelope['parameter']} automation curve. Drag handles or use the Edit point buttons below.',
        child: GestureDetector(
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (d) {
            final points = widget.envelope['points'] as List;
            var distance = 24.0;
            int? found;
            for (var i = 0; i < points.length; i++) {
              final delta = (position(points[i]) - d.localPosition).distance;
              if (delta < distance) {
                distance = delta;
                found = i;
              }
            }
            if (found != null) {
              setState(() {
                index = found;
                draft = cloneArrangement(widget.envelope);
              });
            }
          },
          onPanUpdate: (d) {
            if (index == null) return;
            final sample = snappedSample(
              (d.localPosition.dx / c.maxWidth * end).round(),
              widget.bpm,
              widget.snap,
            ).clamp(0, arrangementLimit);
            final value = (low + (82 - d.localPosition.dy) / 74 * 2).clamp(
              low,
              low + 2,
            );
            setState(() {
              (draft!['points'] as List)[index!] = {
                'sample': sample,
                'value': value,
              };
            });
          },
          onPanEnd: (_) {
            if (draft == null) return;
            final result = draft!;
            final points = result['points'] as List;
            final unique =
                points.map((p) => p['sample']).toSet().length == points.length;
            setState(() {
              draft = null;
              index = null;
            });
            if (!unique) {
              widget.onError(
                'Each automation point needs a unique sample position.',
              );
              return;
            }
            points.sort(
              (a, b) => (a['sample'] as int).compareTo(b['sample'] as int),
            );
            widget.onChanged(result);
          },
          onPanCancel: () => setState(() {
            draft = null;
            index = null;
          }),
          child: CustomPaint(
            painter: EnvelopePainter(
              draft ?? widget.envelope,
              end,
              Theme.of(context).colorScheme.primary,
            ),
            size: Size(c.maxWidth, 90),
          ),
        ),
      );
    },
  );
}
