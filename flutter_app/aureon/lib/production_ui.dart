import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'studio_model.dart';
import 'liquid_glass.dart';

class ProductionPanel extends StatefulWidget {
  const ProductionPanel({super.key});
  @override
  State<ProductionPanel> createState() => _ProductionPanelState();
}

class ReleaseVideoPreview extends StatefulWidget {
  const ReleaseVideoPreview({super.key, required this.url});
  final String url;
  @override
  State<ReleaseVideoPreview> createState() => _ReleaseVideoPreviewState();
}

class _ReleaseVideoPreviewState extends State<ReleaseVideoPreview> {
  late final VideoPlayerController controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  late final Future<void> ready = controller.initialize();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'Video preview unavailable. Download the file or retry.',
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (ctx, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            TextButton(
              onPressed: () =>
                  value.isPlaying ? controller.pause() : controller.play(),
              child: Text(value.isPlaying ? 'Pause video' : 'Play video'),
            ),
          ],
        ),
      );
    },
  );
}

class _ProductionPanelState extends State<ProductionPanel> {
  String? bankId, takeId, projectId;
  String problem = '';
  String uid() => 'take-${DateTime.now().microsecondsSinceEpoch}';
  List<dynamic> banks(StudioModel m) =>
      jsonDecode(jsonEncode(m.current?['take_groups'] ?? []));
  void commit(StudioModel m, List<dynamic> next) {
    m.edit('take_groups', next);
    setState(() => problem = '');
  }

  Future<Map<String, String>?> form(
    StudioModel m,
    String title,
    Map<String, String> values,
  ) async {
    final next = Map<String, String>.from(values);
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: m.reduceMotion || MediaQuery.of(context).disableAnimations
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 220)),
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: next.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          initialValue: e.value,
                          decoration: InputDecoration(labelText: e.key),
                          maxLines: e.key == 'Credits' ? 4 : 1,
                          onChanged: (v) => next[e.key] = v,
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save edit'),
          ),
        ],
      ),
    );
    return ok == true ? next : null;
  }

  Future<void> newBank(StudioModel m) async {
    final data = await form(m, 'New take bank', {'Name': 'Performance takes'});
    if (data == null || !mounted) return;
    final next = banks(m);
    if (next.length >= 8) {
      setState(() => problem = 'At most eight take banks are supported.');
      return;
    }
    bankId = uid();
    takeId = null;
    next.add({
      'id': bankId,
      'name': data['Name'],
      'asset_ids': [],
      'phrases': [],
    });
    commit(m, next);
  }

  Future<void> phrase(StudioModel m, Json bank, [int? index]) async {
    if (takeId == null && index == null) return;
    final old = index == null ? null : bank['phrases'][index];
    final aid = old?['asset_id'] ?? takeId;
    Json? metadata;
    await m.guard(() async {
      metadata = Json.from(
        await m.request('GET', '/assets/$aid/arrangement-metadata'),
      );
    });
    if (metadata == null || !mounted) return;
    final end = (bank['phrases'] as List).fold<int>(
      0,
      (v, p) => math.max(v, (p['start'] as int) + (p['length'] as int)),
    );
    final data = await form(m, index == null ? 'Select phrase' : 'Edit phrase', {
      'Timeline sample': '${old?['start'] ?? end}',
      'Source sample': '${old?['source_start'] ?? 0}',
      'Length samples':
          '${old?['length'] ?? math.min(metadata!['sample_count'] as int, 44100)}',
      'Fade in samples': '${old?['fade_in'] ?? 0}',
      'Fade out samples': '${old?['fade_out'] ?? 0}',
    });
    if (data == null || !mounted) return;
    try {
      final start = int.parse(data['Timeline sample']!),
          source = int.parse(data['Source sample']!),
          length = int.parse(data['Length samples']!),
          fadeIn = int.parse(data['Fade in samples']!),
          fadeOut = int.parse(data['Fade out samples']!);
      if (start < 0 ||
          source < 0 ||
          length < 1 ||
          start + length > 44100 * 180 ||
          source + length > (metadata!['sample_count'] as int) ||
          fadeIn < 0 ||
          fadeOut < 0 ||
          fadeIn + fadeOut > length) {
        throw const FormatException('Phrase bounds or fades are invalid.');
      }
      final next = banks(m);
      final target = next.firstWhere((b) => b['id'] == bank['id']);
      final p = {
        'id': old?['id'] ?? uid(),
        'asset_id': aid,
        'start': start,
        'source_start': source,
        'length': length,
        'repeats': 1,
        'fade_in': fadeIn,
        'fade_out': fadeOut,
      };
      if (index == null) {
        target['phrases'].add(p);
      } else {
        target['phrases'][index] = p;
      }
      commit(m, next);
    } catch (e) {
      setState(
        () => problem =
            'Use integer samples within the take, with fades fitting the phrase.',
      );
    }
  }

  Future<void> render(StudioModel m) => m.guard(() async {
    await m.save();
    await m.request(
      'POST',
      '/projects/${m.current!['id']}/jobs',
      data: {'kind': 'comp_render', 'take_group_id': bankId},
    );
    m.jobs = m.list(
      await m.request('GET', '/jobs?project_id=${m.current!['id']}'),
    );
  });
  Future<void> editRelease(StudioModel m) async {
    final config = Json.from(m.current!['release_kit'] ?? {});
    final data = await form(m, 'Release identity', {
      'Artist': '${config['artist'] ?? m.account?['name'] ?? ''}',
      'Credits':
          '${config['credits'] ?? 'Original composition and production'}',
      'Teaser start seconds': '${config['teaser_start'] ?? 0}',
      'Teaser length seconds':
          '${config['teaser_seconds'] ?? math.min(15, m.duration.floor()).clamp(1, 30)}',
    });
    if (data == null || !mounted) return;
    try {
      final start = int.parse(data['Teaser start seconds']!),
          length = int.parse(data['Teaser length seconds']!);
      if (start < 0 ||
          length < 1 ||
          length > 30 ||
          start + length > m.duration) {
        throw const FormatException();
      }
      m.edit('release_kit', {
        'artist': data['Artist'],
        'credits': data['Credits'],
        'teaser_start': start,
        'teaser_seconds': length,
      });
      setState(() => problem = '');
    } catch (e) {
      setState(
        () => problem = 'Use a 1–30 second teaser within the current master.',
      );
    }
  }

  Future<void> release(StudioModel m) async {
    final masterId = m.master?['id'];
    final config = Json.from(m.current!['release_kit'] ?? {});
    final accepted = await showDialog<bool>(
      context: context,
      animationStyle: m.reduceMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 220)),
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm release credits and rights'),
        content: SingleChildScrollView(
          child: Text(
            '${config['artist'] ?? ''}\n\n${config['credits'] ?? ''}\n\nI have permission to distribute the selected master, artwork and lyrics, and confirm these credits. This creates a private export; it does not publish it.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm and build kit'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await m.guard(() async {
      await m.save();
      await m.request(
        'POST',
        '/projects/${m.current!['id']}/jobs',
        data: {
          'kind': 'release_kit',
          'source_master_asset_id': masterId,
          'confirm_rights': true,
        },
      );
      m.jobs = m.list(
        await m.request('GET', '/jobs?project_id=${m.current!['id']}'),
      );
    });
  }

  Future<void> preview(StudioModel m, String aid, {bool download = false}) =>
      m.guard(() async {
        final a = Json.from(await m.request('GET', '/assets/$aid'));
        if (download) {
          await m.download(a['url'], 'release-kit.zip');
        } else {
          await m.playPreview(a['url'], a['name']);
        }
      });
  Future<void> inspectOutput(StudioModel m, String name, String aid) async {
    Json? asset;
    await m.guard(() async {
      asset = Json.from(await m.request('GET', '/assets/$aid'));
    });
    if (asset == null || !mounted) return;
    if (name.endsWith('.mp4')) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(name),
          content: SizedBox(
            width: 520,
            child: ReleaseVideoPreview(url: m.url(asset!['url'])),
          ),
          actions: [
            TextButton(
              onPressed: () => m.download(asset!['url'], name),
              child: const Text('Download video'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close preview'),
            ),
          ],
        ),
      );
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: SizedBox(
          width: 520,
          child: Image.network(
            m.url(asset!['url']),
            errorBuilder: (_, e, s) =>
                const Text('Preview unavailable. Download or retry.'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close preview'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StudioModel>();
    if (m.current == null) return const SizedBox();
    if (projectId != m.current!['id']) {
      projectId = m.current!['id'];
      bankId = null;
      takeId = null;
      problem = '';
    }
    final groups = banks(m);
    bankId ??= groups.isEmpty ? null : groups.first['id'];
    final found = groups.where((b) => b['id'] == bankId);
    final bank = found.isEmpty ? null : Json.from(found.first);
    final audio = m.assets
        .where((a) => (a['media_type'] ?? '').toString().startsWith('audio/'))
        .toList();
    if (m.master != null && !audio.any((a) => a['id'] == m.master!['id'])) {
      audio.add(m.master!);
    }
    final kit = m.jobs
        .where((j) => j['job_kind'] == 'release_kit' && j['status'] == 'done')
        .firstOrNull;
    final active = m.jobs.any(
      (j) =>
          ['comp_render', 'release_kit'].contains(j['job_kind']) &&
          !['done', 'failed', 'cancelled'].contains(j['status']),
    );
    final config = Json.from(m.current!['release_kit'] ?? {});
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
              'Performance take room',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Originals stay intact. Select source phrases, place them by integer samples, and overlap matching fades for crossfades. Render to audition the composition.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: m.busy ? null : () => newBank(m),
                  child: const Text('New take bank'),
                ),
                if (bank != null)
                  OutlinedButton(
                    onPressed: m.busy
                        ? null
                        : () async {
                            final data = await form(m, 'Rename take bank', {
                              'Name': bank['name'],
                            });
                            if (data != null && mounted) {
                              final next = banks(m);
                              next.firstWhere(
                                (b) => b['id'] == bankId,
                              )['name'] = data['Name'];
                              commit(m, next);
                            }
                          },
                    child: const Text('Rename bank'),
                  ),
              ],
            ),
            if (groups.isEmpty)
              const Text(
                'Create a bank and add imported recordings from Library.',
              ),
            if (groups.isNotEmpty)
              DropdownButtonFormField<String>(
                key: ValueKey('bank-$bankId'),
                initialValue: bank == null ? null : bankId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Take bank'),
                items: groups
                    .map(
                      (b) => DropdownMenuItem<String>(
                        value: b['id'],
                        child: Text(b['name']),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  bankId = v;
                  takeId = null;
                }),
              ),
            if (bank != null) ...[
              PopupMenuButton<String>(
                tooltip: 'Add recording take',
                onSelected: (v) {
                  final next = banks(m);
                  next.firstWhere((b) => b['id'] == bankId)['asset_ids'].add(v);
                  takeId = v;
                  commit(m, next);
                },
                itemBuilder: (ctx) => audio
                    .where((a) => !bank['asset_ids'].contains(a['id']))
                    .map(
                      (a) => PopupMenuItem<String>(
                        value: a['id'],
                        child: Text(a['name'] ?? 'Audio'),
                      ),
                    )
                    .toList(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Add recording take'),
                ),
              ),
              for (final aid in bank['asset_ids'])
                ListTile(
                  dense: true,
                  title: Text(
                    audio.where((a) => a['id'] == aid).firstOrNull?['name'] ??
                        'Saved recording',
                  ),
                  selected: takeId == aid,
                  onTap: m.busy ? null : () => setState(() => takeId = aid),
                  leading: Icon(
                    takeId == aid
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  trailing: IconButton(
                    tooltip: 'Audition original take',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: m.busy ? null : () => preview(m, aid),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: m.busy || takeId == null
                        ? null
                        : () => phrase(m, bank),
                    child: const Text('Select phrase'),
                  ),
                  FilledButton(
                    onPressed:
                        m.busy || active || (bank['phrases'] as List).isEmpty
                        ? null
                        : () => render(m),
                    child: const Text('Render composite'),
                  ),
                  OutlinedButton(
                    onPressed: m.busy
                        ? null
                        : () {
                            final next = banks(m)
                              ..removeWhere((b) => b['id'] == bankId);
                            bankId = null;
                            takeId = null;
                            commit(m, next);
                          },
                    child: const Text('Remove bank'),
                  ),
                ],
              ),
              for (final entry in (bank['phrases'] as List).asMap().entries)
                ListTile(
                  title: Text(
                    'Phrase ${entry.key + 1} · sample ${entry.value['start']}',
                  ),
                  subtitle: Text(
                    'Source ${entry.value['source_start']} · ${entry.value['length']} samples · fades ${entry.value['fade_in']}/${entry.value['fade_out']}',
                  ),
                  onTap: m.busy ? null : () => phrase(m, bank, entry.key),
                  trailing: IconButton(
                    tooltip: 'Remove phrase',
                    icon: const Icon(Icons.close),
                    onPressed: m.busy
                        ? null
                        : () {
                            final next = banks(m);
                            next
                                .firstWhere((b) => b['id'] == bankId)['phrases']
                                .removeAt(entry.key);
                            commit(m, next);
                          },
                  ),
                ),
            ],
            if (active)
              const Text(
                'Processing · Activity provides cancellation, retry and actual errors.',
              ),
            if (problem.isNotEmpty)
              Text(
                problem,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Divider(height: 32),
            Text(
              'Release kit atelier',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Square artwork, lyric cards, square/portrait audio teasers, credits and a hashed ZIP manifest. The artwork editor controls template and palette.',
            ),
            Text(
              'Artist: ${config['artist'] ?? 'Not set'} · teaser ${config['teaser_start'] ?? 0}s / ${config['teaser_seconds'] ?? 15}s',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: m.busy || m.master == null
                      ? null
                      : () => editRelease(m),
                  child: const Text('Edit release identity'),
                ),
                FilledButton(
                  onPressed:
                      m.busy ||
                          active ||
                          m.master == null ||
                          (config['artist'] ?? '').toString().trim().isEmpty
                      ? null
                      : () => release(m),
                  child: const Text('Review release kit'),
                ),
              ],
            ),
            if (kit == null)
              const Text(
                'No kit yet. Save identity and review credits and usage rights before export.',
              ),
            if (kit != null) ...[
              OutlinedButton(
                onPressed: m.busy
                    ? null
                    : () => preview(m, kit['bundle_asset_id'], download: true),
                child: const Text('Download release ZIP'),
              ),
              for (final e in Json.from(kit['output_asset_ids']).entries)
                TextButton(
                  onPressed: m.busy
                      ? null
                      : () => inspectOutput(m, e.key, e.value),
                  child: Text(
                    e.key.endsWith('.mp4')
                        ? 'Preview ${e.key}'
                        : 'Preview ${e.key}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
