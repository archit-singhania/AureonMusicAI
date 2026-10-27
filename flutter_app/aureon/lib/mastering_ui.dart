import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'studio_model.dart';
import 'liquid_glass.dart';

class MasteringQualityPanel extends StatelessWidget {
  const MasteringQualityPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    final settings = Json.from(
      m.current?['mastering_quality'] ??
          {'target_lufs': -14.0, 'ceiling_dbtp': -1.0, 'silence_seconds': 2.0},
    );
    final jobs = m.jobs.where((j) => j['job_kind'] == 'mastering_analysis');
    final active = jobs.any(
      (j) => !['done', 'failed', 'cancelled'].contains(j['status']),
    );
    final completed = jobs.where((j) => j['status'] == 'done').firstOrNull;
    final failed = jobs.where((j) => j['status'] == 'failed').firstOrNull;
    final report = completed?['quality_report'];
    String number(dynamic value) =>
        value is num ? value.toStringAsFixed(2) : 'Not measurable';
    Widget control(String key, String label, double min, double max) =>
        TextFormField(
          key: ValueKey('${m.current?['id']}-$key'),
          initialValue: '${settings[key]}',
          decoration: InputDecoration(
            labelText: label,
            helperText: '$min to $max',
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) {
            final n = double.tryParse(v ?? '');
            return n == null || !n.isFinite || n < min || n > max
                ? 'Enter a value from $min to $max'
                : null;
          },
          onChanged: (v) {
            final n = double.tryParse(v);
            if (n != null && n.isFinite && n >= min && n <= max) {
              m.edit('mastering_quality', {...settings, key: n});
            }
          },
        );
    return LiquidGlass(
      padding: const EdgeInsets.all(20),
      reduceMotion: m.reduceMotion,
      reduceTransparency: m.reduceTransparency,
      highContrast: m.highContrast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mastering quality',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Measure a saved master without changing its audio. Targets are your preferences; findings are not a quality certification.',
          ),
          const SizedBox(height: 16),
          Form(
            child: Builder(
              builder: (formContext) => Column(
                children: [
                  control('target_lufs', 'Loudness target (LUFS)', -30, -5),
                  control(
                    'ceiling_dbtp',
                    'Estimated true-peak ceiling (dBTP)',
                    -12,
                    0,
                  ),
                  control(
                    'silence_seconds',
                    'Flag silence longer than (seconds)',
                    .5,
                    30,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: m.busy || active || m.master == null
                        ? null
                        : () {
                            if (!Form.of(formContext).validate()) return;
                            m.guard(() async {
                              await m.save();
                              await m.request(
                                'POST',
                                '/projects/${m.current!['id']}/jobs',
                                data: {
                                  'kind': 'mastering_analysis',
                                  'source_master_asset_id': m.master?['id'],
                                },
                              );
                              m.jobs = m.list(
                                await m.request(
                                  'GET',
                                  '/jobs?project_id=${m.current!['id']}',
                                ),
                              );
                            });
                          },
                    child: const Text('Analyze saved master'),
                  ),
                ],
              ),
            ),
          ),
          if (m.master == null)
            const Text('Render a master first to enable analysis.'),
          if (active)
            const Text('Analyzing audio · cancel or retry in Activity.'),
          if (failed != null)
            Text('Previous analysis failed: ${failed['error']}'),
          if (report != null) ...[
            const SizedBox(height: 16),
            if (completed!['source_master_asset_id'] != m.master?['id'])
              const Text('Historical report: the current master has changed.'),
            Text(
              'Report targets: ${report['profile']['target_lufs']} LUFS · ${report['profile']['ceiling_dbtp']} dBTP',
            ),
            Text(
              'Integrated loudness: ${number(report['integrated_lufs'])} LUFS',
            ),
            Text(
              'Estimated true peak: ${number(report['estimated_true_peak_dbtp'])} dBTP',
            ),
            Text('Clipped frames: ${report['clipped_frames']}'),
            Text('Stereo correlation: ${number(report['stereo_correlation'])}'),
            Text(
              'Mono energy change: ${number(report['mono_energy_delta_db'])} dB',
            ),
            if ((report['findings'] as List).isEmpty)
              const Text(
                'No configured thresholds triggered. Audition and review remain necessary.',
              ),
            for (final finding in report['findings'])
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${finding['message']}'),
                    for (final range in finding['ranges'] ?? [])
                      Text(
                        'Samples ${range['start_sample']}–${range['end_sample']} at ${report['sample_rate']} Hz',
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text('${report['limitations']}'),
            OutlinedButton(
              onPressed: m.busy
                  ? null
                  : () async {
                      await m.guard(() async {
                        final asset = Json.from(
                          await m.request(
                            'GET',
                            '/assets/${completed['report_asset_id']}',
                          ),
                        );
                        await m.download(asset['url'], 'mastering-report.json');
                      });
                    },
              child: const Text('Download measured report'),
            ),
          ],
        ],
      ),
    );
  }
}
