import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'studio_model.dart';
import 'liquid_glass.dart';

class ReferencePanel extends StatefulWidget {
  const ReferencePanel({super.key});
  @override
  State<ReferencePanel> createState() => _ReferencePanelState();
}

class _ReferencePanelState extends State<ReferencePanel> {
  Future<void> queue(StudioModel m, String kind, [String? expectedMaster]) =>
      m.guard(() async {
        await m.save();
        await m.request(
          'POST',
          '/projects/${m.current!['id']}/jobs',
          data: {
            'kind': kind,
            'source_master_asset_id': expectedMaster ?? m.master?['id'],
          },
        );
        m.jobs = m.list(
          await m.request('GET', '/jobs?project_id=${m.current!['id']}'),
        );
      });

  Future<void> apply(StudioModel m, Json result) async {
    final expectedMaster = m.master?['id'] as String?;
    var gain = '${result['suggestion']['gain_db']}';
    var width = '${result['suggestion']['width']}';
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      animationStyle: m.reduceMotion || MediaQuery.of(context).disableAnimations
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 220)),
      builder: (context) => AlertDialog(
        title: const Text('Render a reference adjustment'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Save a new revision and render. Your current master remains available. Lower gain if headroom fails.',
                ),
                TextFormField(
                  initialValue: gain,
                  decoration: const InputDecoration(labelText: 'Gain dB'),
                  onChanged: (v) => gain = v,
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || !n.isFinite || n < -12 || n > 12
                        ? 'Use −12 to 12 dB'
                        : null;
                  },
                ),
                TextFormField(
                  initialValue: width,
                  decoration: const InputDecoration(
                    labelText: 'Mid/side width',
                  ),
                  onChanged: (v) => width = v,
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || !n.isFinite || n < 0 || n > 2
                        ? 'Use 0 to 2'
                        : null;
                  },
                ),
              ],
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
            child: const Text('Confirm new render'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    m.edit('reference', {
      ...Json.from(m.current!['reference'] ?? {}),
      'gain_db': double.parse(gain),
      'width': double.parse(width),
    });
    await queue(m, 'reference_render', expectedMaster);
  }

  Future<void> audition(
    StudioModel m,
    Json job,
    int index,
  ) => m.guard(() async {
    final asset = Json.from(
      await m.request('GET', '/assets/${job['audition_asset_ids'][index]}'),
    );
    // These two files were normalized together; don't apply a second playback gain.
    await m.playPreview(
      asset['url'],
      index == 0 ? 'Matched master' : 'Matched reference',
    );
  });

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final config = Json.from(m.current?['reference'] ?? {});
    final eligible = m.assets
        .where((a) => (a['media_type'] ?? '').toString().startsWith('audio/'))
        .toList();
    final id = config['asset_id'];
    final completed = m.jobs.where(
      (j) => j['job_kind'] == 'reference_analysis' && j['status'] == 'done',
    );
    final job = completed.isEmpty ? null : completed.first;
    final result = job?['comparison'];
    const labels = {
      'integrated_lufs': 'Integrated loudness (LUFS)',
      'crest_db': 'Crest factor (dB)',
      'stereo_width': 'Side / mid energy ratio',
    };
    String measured(dynamic value) =>
        value is num ? value.toStringAsFixed(3) : '$value';
    final fresh =
        job != null &&
        job['source_master_asset_id'] == m.master?['id'] &&
        job['reference_asset_id'] == id;
    final active = m.jobs.any(
      (j) =>
          ['reference_analysis', 'reference_render'].contains(j['job_kind']) &&
          !['done', 'failed', 'cancelled'].contains(j['status']),
    );
    final failure = m.jobs
        .where(
          (j) =>
              [
                'reference_analysis',
                'reference_render',
              ].contains(j['job_kind']) &&
              j['status'] == 'failed',
        )
        .firstOrNull;
    return LiquidGlass(
      tint: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.all(20),
      reduceMotion: m.reduceMotion,
      reduceTransparency: m.reduceTransparency,
      highContrast: m.highContrast,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reference listening room',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Private, measured comparison. Frequency balance is descriptive; matching a reference does not certify quality or usage rights.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('${m.current?['id']}-$id'),
              initialValue: eligible.any((a) => a['id'] == id) ? id : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Private reference'),
              items: eligible
                  .map(
                    (a) => DropdownMenuItem<String>(
                      value: a['id'],
                      child: Text(
                        a['name'] ?? 'Audio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: m.busy
                  ? null
                  : (v) => m.edit('reference', {...config, 'asset_id': v}),
            ),
            if (eligible.isEmpty)
              const Text('Import audio using Library to choose a reference.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: m.busy || active || m.master == null || id == null
                      ? null
                      : () => queue(m, 'reference_analysis'),
                  child: const Text('Compare reference'),
                ),
                if (active)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Processing · view Activity to cancel/retry'),
                  ),
                if (job != null)
                  OutlinedButton(
                    onPressed: m.busy ? null : () => audition(m, job, 0),
                    child: const Text('Audition matched master'),
                  ),
                if (job != null)
                  OutlinedButton(
                    onPressed: m.busy ? null : () => audition(m, job, 1),
                    child: const Text('Audition matched reference'),
                  ),
                if (job != null)
                  OutlinedButton(
                    onPressed: m.busy || !m.previewing
                        ? null
                        : () => m.toggleTransport(),
                    child: Text(m.playing ? 'Pause audition' : 'Play audition'),
                  ),
                if (result != null)
                  FilledButton.tonal(
                    onPressed: m.busy || active || !fresh
                        ? null
                        : () => apply(m, Json.from(result)),
                    child: const Text('Review adjustment'),
                  ),
              ],
            ),
            if (failure != null)
              Text(
                'Previous job failed: ${failure['error']} · retry in Activity.',
              ),
            if (job == null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Choose a reference and compare a completed master. Results persist with their source snapshots.',
                ),
              ),
            if (job != null && !fresh)
              const Text(
                'Historical comparison: the master or reference changed. Compare again before applying.',
              ),
            if (result != null) ...[
              const SizedBox(height: 12),
              Text('Shared audition target: ${result['audition_lufs']} LUFS'),
              for (final field in [
                'integrated_lufs',
                'crest_db',
                'stereo_width',
              ])
                Text(
                  '${labels[field]} · master ${measured(result['master'][field])} / reference ${measured(result['reference'][field])}',
                ),
              const SizedBox(height: 8),
              for (final band in Json.from(
                result['band_delta_percent'],
              ).entries)
                Text(
                  '${band.key} · reference minus master ${band.value} percentage points',
                ),
              Text(result['explanation']),
            ],
          ],
        ),
      ),
    );
  }
}
