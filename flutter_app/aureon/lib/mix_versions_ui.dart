import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'studio_model.dart';

class MixVersionsPanel extends StatefulWidget {
  const MixVersionsPanel({super.key});
  @override
  State<MixVersionsPanel> createState() => _MixVersionsPanelState();
}

class _MixVersionsPanelState extends State<MixVersionsPanel> {
  final name = TextEditingController();
  final email = TextEditingController();
  String? invitation;
  List<Json> versions = [];
  String? renderId, left, right, error;
  Json? comparison;
  bool busy = false, match = false;
  StudioModel get model => context.read<StudioModel>();
  String get path => '/projects/${model.current!['id']}/mix-versions';

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final rows = await model.request('GET', path);
    if (mounted) {
      setState(
        () => versions = (rows as List).map((r) => Json.from(r)).toList(),
      );
    }
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget selector(
    String label,
    String? value,
    List<Json> options,
    String Function(Json) title,
    ValueChanged<String?> change,
  ) => DropdownButtonFormField<String>(
    initialValue: options.any((o) => o['id'] == value) ? value : null,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items: options
        .map(
          (o) => DropdownMenuItem<String>(
            value: o['id'],
            child: Text(title(o), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: busy ? null : change,
  );
  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final renders = m.jobs
        .where(
          (j) =>
              j['status'] == 'done' &&
              j['master_asset_id'] != null &&
              {
                'generate',
                'remix',
                'arrangement_render',
                'reference_render',
                'comp_render',
                'midi_render',
              }.contains(j['job_kind']),
        )
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mix listening room',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Name a completed render to preserve its audio and the settings that produced it.',
            ),
            OutlinedButton(
              onPressed: busy ? null : () => run(load),
              child: const Text('Load saved mix versions'),
            ),
            if (busy) const LinearProgressIndicator(),
            if (left != null) ...[
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Reviewer account email for version A',
                ),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        final review = await model.request(
                          'POST',
                          '/projects/${model.current!['id']}/mix-reviews',
                          data: {
                            'reviewer_email': email.text,
                            'version_id': left,
                          },
                        );
                        if (mounted) {
                          setState(
                            () => invitation =
                                '${review['reviewer_name']} can review ${review['version_name']} in Library.',
                          );
                        }
                      }),
                child: const Text('Share version A for review'),
              ),
              if (invitation != null)
                Semantics(liveRegion: true, child: Text(invitation!)),
            ],
            if (error != null) Semantics(liveRegion: true, child: Text(error!)),
            if (renders.isEmpty)
              const Text('Complete a render to save your first mix version.'),
            selector(
              'Completed render',
              renderId,
              renders,
              (j) => '${j['job_kind']} · ${j['id']}',
              (v) => setState(() => renderId = v),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Mix version name'),
            ),
            OutlinedButton(
              onPressed: busy || renderId == null
                  ? null
                  : () => run(() async {
                      await model.request(
                        'POST',
                        path,
                        data: {'name': name.text, 'job_id': renderId},
                      );
                      await load();
                    }),
              child: const Text('Save named mix'),
            ),
            selector(
              'Version A',
              left,
              versions,
              (v) => v['name'],
              (v) => setState(() {
                left = v;
                comparison = null;
              }),
            ),
            selector(
              'Version B',
              right,
              versions,
              (v) => v['name'],
              (v) => setState(() {
                right = v;
                comparison = null;
              }),
            ),
            CheckboxListTile(
              value: match,
              title: const Text('Render loudness-matched audition files'),
              onChanged: busy
                  ? null
                  : (v) => setState(() => match = v ?? false),
            ),
            OutlinedButton(
              onPressed: busy || left == null || right == null || left == right
                  ? null
                  : () => run(() async {
                      final result = await model.request(
                        'POST',
                        '$path/compare',
                        data: {
                          'left': left,
                          'right': right,
                          'match_audio': match,
                        },
                      );
                      if (mounted) {
                        setState(() => comparison = Json.from(result));
                      }
                    }),
              child: const Text('Compare selected versions'),
            ),
            if (comparison != null) ...[
              if ((comparison!['changes'] as List).isEmpty)
                const Text('The saved settings are identical.'),
              for (final change in comparison!['changes'])
                ExpansionTile(
                  title: Text(change['field']),
                  children: [
                    SelectableText(
                      'A: ${change['before']}\nB: ${change['after']}',
                    ),
                  ],
                ),
              for (final (i, a) in (comparison!['audio'] as List).indexed)
                OutlinedButton(
                  onPressed: () =>
                      m.playPreview(a['url'], 'Mix ${i == 0 ? 'A' : 'B'}'),
                  child: Text('Play original ${i == 0 ? 'A' : 'B'}'),
                ),
              if (comparison!['job_id'] != null)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          final job = await m.request(
                            'GET',
                            '/jobs/${comparison!['job_id']}',
                          );
                          if (job['status'] != 'done') {
                            throw StateError(
                              'Matching: ${job['status']} ${job['error'] ?? ''}',
                            );
                          }
                          final audio = <Json>[];
                          for (final aid in job['audition_asset_ids']) {
                            audio.add(
                              Json.from(await m.request('GET', '/assets/$aid')),
                            );
                          }
                          if (mounted) {
                            setState(() => comparison!['matched'] = audio);
                          }
                        }),
                  child: const Text('Load matched audition when ready'),
                ),
              for (final (i, a)
                  in ((comparison!['matched'] as List?) ?? []).indexed)
                OutlinedButton(
                  onPressed: () =>
                      m.playPreview(a['url'], 'Matched ${i == 0 ? 'A' : 'B'}'),
                  child: Text('Play matched ${i == 0 ? 'A' : 'B'}'),
                ),
            ],
            OutlinedButton(
              onPressed: busy || left == null || m.dirty
                  ? null
                  : () => run(() => m.restoreNamedMix(left!)),
              child: const Text('Restore A as new project revision'),
            ),
            if (m.dirty)
              const Text('Save current project edits before restoring.'),
          ],
        ),
      ),
    );
  }
}
