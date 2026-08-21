import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  static const List<Map<String, dynamic>> _communityTracks = [
    {
      "id": "comm_1",
      "title": "Midnight Cyber 808",
      "artist": "DJ NeonFlux",
      "genre": "Trap",
      "bpm": 140,
      "likes": 248,
      "stems": true,
    },
    {
      "id": "comm_2",
      "title": "South London Heat",
      "artist": "VocalistPrime",
      "genre": "Drill",
      "bpm": 142,
      "likes": 189,
      "stems": true,
    },
    {
      "id": "comm_3",
      "title": "Monsoon Velvet Rain",
      "artist": "AuraVoice",
      "genre": "R&B",
      "bpm": 88,
      "likes": 312,
      "stems": true,
    },
    {
      "id": "comm_4",
      "title": "Shibuya Sunset Pop",
      "artist": "SynthWaveMaster",
      "genre": "Pop",
      "bpm": 124,
      "likes": 275,
      "stems": true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'COMMUNITY SHOWCASE',
          style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: _communityTracks.length,
          itemBuilder: (context, idx) {
            final t = _communityTracks[idx];
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF11111E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF222238)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.music_note, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t["title"],
                          style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t["artist"]} • ${t["genre"]} • ${t["bpm"]} BPM',
                          style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, color: Color(0xFFFF6584), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${t["likes"]}',
                        style: GoogleFonts.spaceMono(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF6C63FF), size: 30),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Streaming ${t["title"]}...')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
