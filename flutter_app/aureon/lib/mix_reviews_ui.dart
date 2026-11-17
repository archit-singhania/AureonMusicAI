import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'studio_model.dart';

class MixReviewInbox extends StatefulWidget {
  const MixReviewInbox({super.key});
  @override
  State<MixReviewInbox> createState() => _MixReviewInboxState();
}

class _MixReviewInboxState extends State<MixReviewInbox> {
  List<Json> reviews = [];
  String? message;
  bool busy = false;

  Future<void> load() async {
    final rows = await context.read<StudioModel>().request(
      'GET',
      '/mix-reviews',
    );
    if (mounted) {
      setState(
        () => reviews = (rows as List).map((r) => Json.from(r)).toList(),
      );
    }
  }

  Future<void> run(Future<void> Function() work) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> feedback(Json review, String action, {String? comment}) async {
    final model = context.read<StudioModel>();
    String text = '', start = '0', end = '';
    if ({'comment', 'reply', 'request_changes', 'revoke'}.contains(action)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            action == 'revoke'
                ? 'Revoke access to this version?'
                : action.replaceAll('_', ' '),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action == 'comment') ...[
                  TextFormField(
                    initialValue: start,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Start in milliseconds',
                    ),
                    onChanged: (v) => start = v,
                  ),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'End in milliseconds (optional)',
                    ),
                    onChanged: (v) => end = v,
                  ),
                ],
                if (action != 'revoke')
                  TextFormField(
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Feedback'),
                    onChanged: (v) => text = v,
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
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    await run(() async {
      await model.request(
        'POST',
        '/mix-reviews/${review['id']}/feedback',
        data: {
          'revision': review['revision'],
          'action': action,
          'text': text,
          'comment_id': comment,
          'start_ms': int.parse(start),
          'end_ms': end.isEmpty ? null : int.parse(end),
        },
      );
      if (mounted) {
        await load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<StudioModel>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared mix reviews',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await load();
                      if (mounted && reviews.isEmpty) {
                        setState(
                          () => message =
                              'No reviews are shared with this account.',
                        );
                      }
                    }),
              child: const Text('Load review inbox'),
            ),
            if (busy) const LinearProgressIndicator(),
            if (message != null)
              Semantics(liveRegion: true, child: Text(message!)),
            for (final r in reviews)
              ExpansionTile(
                key: ValueKey(r['id']),
                title: Text('${r['version_name']} · ${r['reviewer_name']}'),
                subtitle: Text(
                  r['revoked'] == true
                      ? 'Revoked'
                      : '${r['decision']} · ${r['duration_ms']} ms',
                ),
                children: [
                  if (r['revoked'] != true)
                    Wrap(
                      children: [
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  final link = await model.request(
                                    'GET',
                                    '/mix-reviews/${r['id']}/audition',
                                  );
                                  await model.playPreview(
                                    link['url'],
                                    r['version_name'],
                                  );
                                }),
                          child: const Text('Audition shared version'),
                        ),
                        for (final action in [
                          'comment',
                          if (r['reviewer_id'] == model.account?['id']) ...[
                            'approve',
                            'request_changes',
                          ],
                          if (r['owner_id'] == model.account?['id']) 'revoke',
                        ])
                          TextButton(
                            onPressed: busy ? null : () => feedback(r, action),
                            child: Text(action.replaceAll('_', ' ')),
                          ),
                      ],
                    ),
                  for (final c in r['comments'])
                    ListTile(
                      title: Text(
                        '${c['start_ms']}–${c['end_ms']} ms · ${c['text']}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c['author']} · ${c['resolved'] == true ? 'Resolved' : 'Open'}',
                          ),
                          for (final reply in c['replies'])
                            Text('${reply['author']}: ${reply['text']}'),
                          if (r['revoked'] != true)
                            Wrap(
                              children: [
                                for (final action in [
                                  'reply',
                                  c['resolved'] == true ? 'reopen' : 'resolve',
                                ])
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => feedback(
                                            r,
                                            action,
                                            comment: c['id'],
                                          ),
                                    child: Text(action),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
