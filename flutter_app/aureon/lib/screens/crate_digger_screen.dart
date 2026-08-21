import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CrateDiggerScreen extends StatefulWidget {
  const CrateDiggerScreen({Key? key}) : super(key: key);

  @override
  State<CrateDiggerScreen> createState() => _CrateDiggerScreenState();
}

class _CrateDiggerScreenState extends State<CrateDiggerScreen> {
  List<dynamic> _samples = [];
  bool _isLoading = false;

  Future<void> _scanLocalFolder() async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5000/api/ultimate/cratedigger'));
      request.fields['path'] = './outputs'; // Example local path
      var response = await request.send();
      if (response.statusCode == 200) {
        var resString = await response.stream.bytesToString();
        var json = jsonDecode(resString);
        setState(() {
          _samples = json['samples'] ?? [];
        });
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crate Digger (Local)")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_search),
              label: const Text("Scan Local Directory"),
              onPressed: _scanLocalFolder,
            ),
            const SizedBox(height: 16),
            if (_isLoading) const CircularProgressIndicator(color: PremiumTheme.accentNeonPurple),
            Expanded(
              child: ListView.builder(
                itemCount: _samples.length,
                itemBuilder: (context, index) {
                  var s = _samples[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.music_note, color: PremiumTheme.accentNeonGreen),
                      title: Text(s['filename'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                      subtitle: Text("BPM: ${s['bpm']}  Key: ${s['key']}", style: const TextStyle(color: Colors.grey)),
                      trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
