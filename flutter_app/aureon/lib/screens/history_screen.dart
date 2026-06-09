import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'player_screen.dart';

/// Phase 6 — Quality Loop
/// Shows all past generated tracks with ratings and metadata.
/// Data is persisted via SharedPreferences (saved by PlayerScreen).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<_HistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jobIds = prefs.getStringList('job_history') ?? [];

    final entries = <_HistoryEntry>[];
    for (final id in jobIds.reversed) {
      final raw = prefs.getString('job_meta_$id');
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          entries.add(_HistoryEntry.fromJson(json));
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _deleteEntry(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('job_history') ?? [];
    ids.remove(jobId);
    await prefs.setStringList('job_history', ids);
    await prefs.remove('job_meta_$jobId');
    await prefs.remove('rating_$jobId');
    setState(() => _entries.removeWhere((e) => e.jobId == jobId));
  }

  String _starString(int rating) {
    if (rating <= 0) return 'Unrated';
    return List.generate(rating, (_) => '★').join() +
        List.generate(5 - rating, (_) => '☆').join();
  }

  Color _starColor(int rating) {
    if (rating <= 0) return const Color(0xFF444455);
    if (rating >= 4) return const Color(0xFFFFBE0B);
    if (rating >= 3) return const Color(0xFFFF9F43);
    return const Color(0xFFFF6584);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'HISTORY',
          style: GoogleFonts.spaceMono(
            color: Colors.white,
            fontSize: 16,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_entries.isNotEmpty)
            TextButton(
              onPressed: _showExportSheet,
              child: Text(
                'EXPORT',
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFF6C63FF),
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _entries.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_rounded,
            color: const Color(0xFF2A2A3E),
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'No tracks yet',
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF444455),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a song and rate it\nto build your history',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF333344),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Stats summary
    final rated = _entries.where((e) => e.rating > 0).toList();
    final avgRating = rated.isEmpty
        ? 0.0
        : rated.map((e) => e.rating).reduce((a, b) => a + b) / rated.length;

    return Column(
      children: [
        // Stats banner
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF111118),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A2A3E)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'TRACKS', value: '${_entries.length}'),
                _Stat(label: 'RATED', value: '${rated.length}'),
                _Stat(
                  label: 'AVG SCORE',
                  value: rated.isEmpty
                      ? '—'
                      : '${avgRating.toStringAsFixed(1)}/5',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: _entries.length,
            itemBuilder: (context, i) => _HistoryTile(
              entry: _entries[i],
              starString: _starString(_entries[i].rating),
              starColor: _starColor(_entries[i].rating),
              onDelete: () => _deleteEntry(_entries[i].jobId),
              onTap: () => _openTrack(_entries[i]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openTrack(_HistoryEntry entry) async {
    final file = File(entry.path);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio file not found on device')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(audioPath: entry.path, jobId: entry.jobId),
      ),
    );
  }

  void _showExportSheet() {
    // Build a simple CSV for the feedback dataset
    final csv = StringBuffer('jobId,rating,timestamp,path\n');
    for (final e in _entries) {
      csv.writeln('${e.jobId},${e.rating},${e.timestamp},${e.path}');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FEEDBACK DATASET',
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF555577),
                fontSize: 10,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_entries.length} tracks · '
              '${_entries.where((e) => e.rating > 0).length} rated',
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Export this CSV to your outputs folder\nto use as a training feedback dataset.',
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF555577),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    final dir = await getApplicationDocumentsDirectory();
                    final file = File(
                        '${dir.path}/aureon_feedback_${DateTime.now().millisecondsSinceEpoch}.csv');
                    await file.writeAsString(csv.toString());
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Exported to ${file.path.split('/').last}'),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'EXPORT CSV',
                  style: GoogleFonts.spaceMono(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _HistoryEntry {
  final String jobId;
  final int rating;
  final String timestamp;
  final String path;

  _HistoryEntry({
    required this.jobId,
    required this.rating,
    required this.timestamp,
    required this.path,
  });

  factory _HistoryEntry.fromJson(Map<String, dynamic> json) => _HistoryEntry(
        jobId: json['jobId'] as String? ?? '',
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        timestamp: json['timestamp'] as String? ?? '',
        path: json['path'] as String? ?? '',
      );

  String get shortId => jobId.length >= 8 ? jobId.substring(0, 8).toUpperCase() : jobId;

  String get formattedDate {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }
}

class _HistoryTile extends StatelessWidget {
  final _HistoryEntry entry;
  final String starString;
  final Color starColor;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.entry,
    required this.starString,
    required this.starColor,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(entry.jobId),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4444).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline,
              color: Color(0xFFFF4444), size: 24),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF111118),
              title: Text(
                'Delete track?',
                style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 14),
              ),
              content: Text(
                'This removes it from your history.',
                style: GoogleFonts.spaceMono(
                    color: const Color(0xFF555577), fontSize: 12),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel',
                      style: GoogleFonts.spaceMono(
                          color: const Color(0xFF555577))),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Delete',
                      style: GoogleFonts.spaceMono(
                          color: const Color(0xFFFF4444))),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => onDelete(),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111118),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A3E)),
            ),
            child: Row(
              children: [
                // Play icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Color(0xFF6C63FF), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Track ${entry.shortId}',
                        style: GoogleFonts.spaceMono(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.formattedDate,
                        style: GoogleFonts.spaceMono(
                          color: const Color(0xFF444455),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating
                Text(
                  starString,
                  style: TextStyle(
                    color: starColor,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.spaceMono(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: const Color(0xFF444455),
            fontSize: 9,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
