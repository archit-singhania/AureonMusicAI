import '../theme/premium_theme.dart';
import '../widgets/glass_card.dart';
import 'package:flutter/foundation.dart';

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';

import '../services/api_service.dart';

import '../services/generator_provider.dart';

import '../models/models.dart';

import '../models/preset_beats.dart';

import '../widgets/genre_chip.dart';

import '../widgets/waveform_bar.dart';

import '../widgets/syllable_counter_bar.dart';

import '../widgets/voice_assistant_modal.dart';

import 'status_screen.dart';

import 'community_feed_screen.dart';

import 'history_screen.dart';



class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key});



  @override

  State<HomeScreen> createState() => _HomeScreenState();

}



class _HomeScreenState extends State<HomeScreen> {

  final _lyricsController = TextEditingController();

  final _api = ApiService();



  File? _beatFile;

  PresetBeatItem? _selectedPresetBeat = defaultPresetBeats[0];

  String _selectedGenre = 'trap';

  String _preferredEngine = 'auto'; // auto | sarvam | xtts

  String _languageCode = 'en-IN';

  String _scaleType = 'minor';

  double _retuneSpeed = 0.1; // 0.0 = Hard autotune, 1.0 = Natural

  bool _isSubmitting = false;



  static const _genres = ['trap', 'drill', 'rap', 'rnb', 'pop'];

  static const _scales = ['minor', 'major', 'harmonic_minor', 'pentatonic', 'dorian'];



  @override

  void initState() {

    super.initState();

    _lyricsController.text =

        "Neon lights flashing in the midnight rain\n"

        "Cruising through the city washing out the pain\n"

        "808 vibrating rattling through the frame\n"

        "Aureon on the track they all know the name";

  }



  Future<void> _pickBeat() async {

    final result = await FilePicker.platform.pickFiles(

      type: FileType.audio,

      allowMultiple: false,

    );

    if (result != null && result.files.single.path != null) {

      setState(() {

        _beatFile = File(result.files.single.path!);

        _selectedPresetBeat = null;

      });

    }

  }



  void _openVoiceAssistant() {

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) => VoiceAssistantModal(

        onPromptApplied: (transcript, inferredGenre) {

          setState(() {

            _lyricsController.text =

                "$transcript\n"

                "Rhythm in my soul and the bassline hitting right\n"

                "Making timeless music taking over the night";

            _selectedGenre = inferredGenre;

          });

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text('Voice prompt applied! ($inferredGenre flow)'),

              backgroundColor: PremiumTheme.neonCyan,

            ),

          );

        },

      ),

    );

  }



  void _autoGenerateLyrics() {

    final templates = {

      'trap': "Sliding in the shadows stacking up the racks\n"

          "Diamond on the wrist never looking back\n"

          "Heavy sub kicking hitting on the count\n"

          "Leveling the score watch the numbers mount",

      'drill': "Slide on the beat no hesitation\n"

          "Big moves only in the generation\n"

          "London to Mumbai cross the station\n"

          "Cold in the winter pure elevation",

      'rap': "Spitting truth sharp like a guillotine\n"

          "Living out the dream from a magazine\n"

          "Rhyme scheme locked in the time machine\n"

          "Mastering the craft keep the vision clean",

      'rnb': "Lost inside your eyes in the candlelight\n"

          "Whispers in the dark till the morning light\n"

          "Holding on to you everything feels right\n"

          "Melody divine shining starry bright",

      'pop': "Dancing through the shadows under neon glow\n"

          "Feel the rhythm take you let the energy flow\n"

          "Higher than the sky putting on a show\n"

          "This is our time now here we go",

    };



    setState(() {

      _lyricsController.text = templates[_selectedGenre] ?? templates['rap']!;

    });

  }



  Future<void> _generate() async {

    if (_beatFile == null && _selectedPresetBeat == null) {

      _showSnack('Please select a preset beat or upload an audio beat.');

      return;

    }

    if (_lyricsController.text.trim().isEmpty) {

      _showSnack('Please enter your lyrics or generate some with AI.');

      return;

    }



    setState(() => _isSubmitting = true);



    try {

      final response = await _api.generateSong(

        beatFile: _beatFile,

        presetBeatId: _selectedPresetBeat?.id,

        lyrics: _lyricsController.text.trim(),

        genre: _selectedGenre,

        preferredEngine: _preferredEngine,

        languageCode: _languageCode,

        scaleType: _scaleType,

        retuneSpeed: _retuneSpeed,

      );



      if (!mounted) return;



      final provider = context.read<GeneratorProvider>();

      provider.reset();

      provider.startLiveTracking(response.jobId);



      Navigator.push(

        context,

        MaterialPageRoute(builder: (_) => StatusScreen()),

      );

    } catch (e) {

      _showSnack('Error: ${e.toString()}');

    } finally {

      if (mounted) setState(() => _isSubmitting = false);

    }

  }



  void _showSnack(String msg) {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  }



  @override

  void dispose() {

    _lyricsController.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFF0A0A12),

      floatingActionButton: FloatingActionButton.extended(

        onPressed: _openVoiceAssistant,

        backgroundColor: PremiumTheme.neonCyan,

        icon: const Icon(Icons.mic, color: Colors.white),

        label: Text(

          'VOICE PRODUCER',

          style: GoogleFonts.spaceMono(

            color: Colors.white,

            fontWeight: FontWeight.bold,

            letterSpacing: 1.5,

            fontSize: 12,

          ),

        ),

      ),


      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.6),
            radius: 1.5,
            colors: [PremiumTheme.deepSpace, PremiumTheme.abyssalBackground],
          ),
        ),
        child: SafeArea(


        child: SingleChildScrollView(

          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // Header

              Row(

                children: [

                  Container(

                    width: 44,

                    height: 44,

                    decoration: BoxDecoration(

                      gradient: const LinearGradient(

                        colors: [PremiumTheme.neonCyan, PremiumTheme.neonMagenta],

                      ),

                      borderRadius: BorderRadius.circular(14),

                      boxShadow: [

                        BoxShadow(

                          color: PremiumTheme.neonCyan.withOpacity(0.4),

                          blurRadius: 12,

                          spreadRadius: 1,

                        ),

                      ],

                    ),

                    child: const Icon(Icons.graphic_eq, color: Colors.white, size: 24),

                  ),

                  const SizedBox(width: 14),

                  Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        'Aureon Studio',

                        style: GoogleFonts.spaceMono(

                          color: Colors.white,

                          fontSize: 22,

                          fontWeight: FontWeight.bold,

                          letterSpacing: 2,

                        ),

                      ),

                      Text(

                        'AI Music & Sarvam Producer',

                        style: GoogleFonts.spaceMono(

                          color: PremiumTheme.neonCyan,

                          fontSize: 11,

                          letterSpacing: 2,

                        ),

                      ),

                    ],

                  ),

                  const Spacer(),

                  IconButton(

                    tooltip: 'Community Showcase',

                    icon: const Icon(Icons.explore_rounded, color: PremiumTheme.neonCyan, size: 24),

                    onPressed: () => Navigator.push(

                      context,

                      MaterialPageRoute(builder: (_) => CommunityFeedScreen()),

                    ),

                  ),

                  IconButton(

                    tooltip: 'History',

                    icon: const Icon(Icons.history_rounded, color: Color(0xFF8888AA), size: 24),

                    onPressed: () => Navigator.push(

                      context,

                      MaterialPageRoute(builder: (_) => HistoryScreen()),

                    ),

                  ),

                  const SizedBox(width: 4),

                  const WaveformBar(),

                ],

              ),



              const SizedBox(height: 28),



              // â”€â”€ Beat Selection (Presets + Custom Upload) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

              _SectionLabel(label: '1. SELECT BEAT OR UPLOAD'),

              const SizedBox(height: 10),



              // Preset Beats Carousel

              SizedBox(

                height: 105,

                child: ListView.builder(

                  scrollDirection: Axis.horizontal,

                  itemCount: defaultPresetBeats.length,

                  itemBuilder: (context, idx) {

                    final beat = defaultPresetBeats[idx];

                    final isSelected = _selectedPresetBeat?.id == beat.id && _beatFile == null;



                    return GestureDetector(

                      onTap: () {

                        setState(() {

                          _selectedPresetBeat = beat;

                          _beatFile = null;

                          _selectedGenre = beat.genre;

                        });

                      },

                      child: AnimatedContainer(

                        duration: const Duration(milliseconds: 200),

                        width: 170,

                        margin: const EdgeInsets.only(right: 12),

                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(

                          color: isSelected ? const Color(0xFF1C1C30) : PremiumTheme.deepSpace,

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(

                            color: isSelected ? PremiumTheme.neonCyan : const Color(0xFF222238),

                            width: isSelected ? 2 : 1,

                          ),

                        ),

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Row(

                              children: [

                                Icon(Icons.album_rounded, color: isSelected ? PremiumTheme.neonCyan : Colors.white54, size: 16),

                                const Spacer(),

                                Text(

                                  '${beat.bpm} BPM',

                                  style: GoogleFonts.spaceMono(color: PremiumTheme.neonCyan, fontSize: 10, fontWeight: FontWeight.bold),

                                ),

                              ],

                            ),

                            const Spacer(),

                            Text(

                              beat.title,

                              style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                            ),

                            Text(

                              '${beat.genre.toUpperCase()} â€¢ ${beat.key}',

                              style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 9),

                            ),

                          ],

                        ),

                      ),

                    );

                  },

                ),

              ),



              const SizedBox(height: 12),



              // Custom Beat Upload button

              GestureDetector(

                onTap: _pickBeat,

                child: Container(

                  width: double.infinity,

                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

                  decoration: BoxDecoration(

                    color: _beatFile != null ? const Color(0xFF1E1E34) : PremiumTheme.deepSpace,

                    border: Border.all(

                      color: _beatFile != null ? PremiumTheme.neonMagenta : const Color(0xFF222238),

                      width: 1.5,

                    ),

                    borderRadius: BorderRadius.circular(14),

                  ),

                  child: Row(

                    children: [

                      Icon(

                        _beatFile != null ? Icons.audio_file : Icons.upload_file,

                        color: _beatFile != null ? PremiumTheme.neonMagenta : PremiumTheme.neonCyan,

                        size: 20,

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Text(

                          _beatFile != null

                              ? 'Uploaded: ${_beatFile!.path.split(('/')).last}'

                              : 'Or upload your custom audio beat (MP3, WAV, FLAC)',

                          style: GoogleFonts.spaceMono(

                            color: _beatFile != null ? Colors.white : const Color(0xFF8888AA),

                            fontSize: 11,

                          ),

                          overflow: TextOverflow.ellipsis,

                        ),

                      ),

                      if (_beatFile != null)

                        GestureDetector(

                          onTap: () => setState(() => _beatFile = null),

                          child: const Icon(Icons.close, color: Colors.white54, size: 16),

                        ),

                    ],

                  ),

                ),

              ),



              const SizedBox(height: 24),



              // â”€â”€ Genre Selector â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

              _SectionLabel(label: '2. GENRE & STYLE'),

              const SizedBox(height: 10),

              SizedBox(

                height: 42,

                child: ListView(

                  scrollDirection: Axis.horizontal,

                  children: _genres

                      .map((g) => GenreChip(

                            genre: g,

                            selected: _selectedGenre == g,

                            onTap: () => setState(() => _selectedGenre = g),

                          ))

                      .toList(),

                ),

              ),



              const SizedBox(height: 24),



              // â”€â”€ AI Lyricist Studio â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

              Row(

                children: [

                  _SectionLabel(label: '3. AI LYRICIST STUDIO'),

                  const Spacer(),

                  TextButton.icon(

                    onPressed: _autoGenerateLyrics,

                    icon: const Icon(Icons.auto_awesome, size: 14, color: PremiumTheme.neonCyan),

                    label: Text(

                      'AI Auto-Write',

                      style: GoogleFonts.spaceMono(

                        color: PremiumTheme.neonCyan,

                        fontSize: 11,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 6),



              // Real-time Syllable Flow Meter

              SyllableCounterBar(

                lyrics: _lyricsController.text,

                genre: _selectedGenre,

              ),



              const SizedBox(height: 8),



              Container(

                decoration: BoxDecoration(

                  color: PremiumTheme.deepSpace,

                  border: Border.all(color: const Color(0xFF222238), width: 1.5),

                  borderRadius: BorderRadius.circular(16),

                ),

                child: TextField(

                  controller: _lyricsController,

                  onChanged: (_) => setState(() {}),

                  maxLines: 6,

                  style: GoogleFonts.spaceMono(

                    color: Colors.white,

                    fontSize: 13,

                    height: 1.6,

                  ),

                  decoration: InputDecoration(

                    hintText: 'Enter your lyrics here...\nLine 1\nLine 2\nLine 3',

                    hintStyle: GoogleFonts.spaceMono(

                      color: const Color(0xFF44445A),

                      fontSize: 12,

                    ),

                    contentPadding: const EdgeInsets.all(16),

                    border: InputBorder.none,

                  ),

                ),

              ),



              const SizedBox(height: 24),



              // â”€â”€ Studio Engine & Scale Tuning â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

              _SectionLabel(label: '4. VOCAL ENGINE & AUTO-TUNE'),

              const SizedBox(height: 10),

              Container(

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(

                  color: PremiumTheme.deepSpace,

                  borderRadius: BorderRadius.circular(16),

                  border: Border.all(color: const Color(0xFF222238)),

                ),

                child: Column(

                  children: [

                    // Engine Switcher

                    Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [

                        Text(

                          'Engine:',

                          style: GoogleFonts.spaceMono(color: Colors.white70, fontSize: 11),

                        ),

                        DropdownButton<String>(

                          value: _preferredEngine,

                          dropdownColor: const Color(0xFF1A1A2E),

                          underline: const SizedBox(),

                          style: GoogleFonts.spaceMono(color: PremiumTheme.neonCyan, fontSize: 12, fontWeight: FontWeight.bold),

                          items: const [

                            DropdownMenuItem(value: 'auto', child: Text('Auto (Sarvam / XTTS)')),

                            DropdownMenuItem(value: 'sarvam', child: Text('Sarvam AI (Indian/Global)')),

                            DropdownMenuItem(value: 'xtts', child: Text('Coqui XTTS-v2 (Offline)')),

                          ],

                          onChanged: (v) => setState(() => _preferredEngine = v!),

                        ),

                      ],

                    ),

                    const Divider(color: Color(0xFF222238)),

                    // Scale Selector

                    Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [

                        Text(

                          'Pitch Scale:',

                          style: GoogleFonts.spaceMono(color: Colors.white70, fontSize: 11),

                        ),

                        DropdownButton<String>(

                          value: _scaleType,

                          dropdownColor: const Color(0xFF1A1A2E),

                          underline: const SizedBox(),

                          style: GoogleFonts.spaceMono(color: PremiumTheme.neonMagenta, fontSize: 12, fontWeight: FontWeight.bold),

                          items: _scales

                              .map((s) => DropdownMenuItem(

                                    value: s,

                                    child: Text(s.toUpperCase().replaceAll('_', ' ')),

                                  ))

                              .toList(),

                          onChanged: (v) => setState(() => _scaleType = v!),

                        ),

                      ],

                    ),

                  ],

                ),

              ),



              const SizedBox(height: 32),



              // â”€â”€ Generate Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

              SizedBox(

                width: double.infinity,

                height: 56,

                child: ElevatedButton(

                  onPressed: _isSubmitting ? null : _generate,

                  style: ElevatedButton.styleFrom(

                    backgroundColor: Colors.transparent,

                    shadowColor: Colors.transparent,

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(16),

                    ),

                    padding: EdgeInsets.zero,

                  ),

                  child: Ink(

                    decoration: BoxDecoration(

                      gradient: _isSubmitting

                          ? null

                          : const LinearGradient(

                              colors: [PremiumTheme.neonCyan, PremiumTheme.neonMagenta],

                            ),

                      color: _isSubmitting ? const Color(0xFF2A2A3E) : null,

                      borderRadius: BorderRadius.circular(16),

                      boxShadow: [

                        BoxShadow(

                          color: PremiumTheme.neonCyan.withOpacity(0.4),

                          blurRadius: 16,

                          spreadRadius: 1,

                        ),

                      ],

                    ),

                    child: Center(

                      child: _isSubmitting

                          ? const SizedBox(

                              width: 22,

                              height: 22,

                              child: CircularProgressIndicator(

                                color: Colors.white,

                                strokeWidth: 2,

                              ),

                            )

                          : Text(

                              'GENERATE MASTER TRACK',

                              style: GoogleFonts.spaceMono(

                                color: Colors.white,

                                fontSize: 14,

                                fontWeight: FontWeight.bold,

                                letterSpacing: 2,

                              ),

                            ),

                    ),

                  ),

                ),

              ),



              const SizedBox(height: 60), // Extra space for floating mic button

            ],

          ),

        ),

      ),

      ),

    );

  }

}



class _SectionLabel extends StatelessWidget {

  final String label;

  const _SectionLabel({required this.label});



  @override

  Widget build(BuildContext context) {

    return Text(

      label,

      style: GoogleFonts.spaceMono(

        color: const Color(0xFF8888AA),

        fontSize: 11,

        letterSpacing: 2,

        fontWeight: FontWeight.bold,

      ),

    );

  }

}







