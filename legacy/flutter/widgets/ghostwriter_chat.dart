import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GhostwriterChat extends StatefulWidget {
  const GhostwriterChat({Key? key}) : super(key: key);

  @override
  State<GhostwriterChat> createState() => _GhostwriterChatState();
}

class _GhostwriterChatState extends State<GhostwriterChat> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    String userMsg = _controller.text;
    setState(() {
      _messages.add("You: $userMsg");
      _controller.clear();
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5000/api/advanced/lyrics'));
      request.fields['prompt'] = userMsg;
      request.fields['context'] = _messages.join("\n");
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var resString = await response.stream.bytesToString();
        var json = jsonDecode(resString);
        setState(() {
          _messages.add("AI: ${json['lyrics']}");
        });
      } else {
        setState(() => _messages.add("System: Failed to generate lyrics"));
      }
    } catch (e) {
      setState(() => _messages.add("System: Error connecting to AI Writer"));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PremiumTheme.surfaceDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text("Ghostwriter Copilot", style: TextStyle(color: PremiumTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _messages[index].startsWith("You:");
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? PremiumTheme.surfaceElevated : PremiumTheme.backgroundBlack,
                    borderRadius: BorderRadius.circular(12),
                    border: isUser ? null : Border.all(color: PremiumTheme.accentNeonPurple.withOpacity(0.3)),
                  ),
                  child: Text(_messages[index], style: TextStyle(color: isUser ? PremiumTheme.textPrimary : PremiumTheme.textSecondary)),
                );
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: PremiumTheme.accentNeonPurple)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "E.g. Write a chorus about late nights...",
                    filled: true,
                    fillColor: PremiumTheme.backgroundBlack,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: PremiumTheme.accentNeonPurple),
                onPressed: _sendMessage,
              )
            ],
          )
        ],
      ),
    );
  }
}
