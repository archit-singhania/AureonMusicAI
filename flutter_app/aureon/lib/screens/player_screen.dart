import 'dart:io';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:just_audio/just_audio.dart';

import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/generator_provider.dart';

import '../widgets/spectral_visualizer.dart';

import '../widgets/spectrogram_3d.dart';

import '../widgets/time_travel_slider.dart';

import '../widgets/node_graph_editor.dart';



import '../widgets/stem_player_widget.dart';

import '../widgets/studio_effects_rack.dart';

import '../widgets/mixing_copilot_modal.dart';

import '../widgets/video_export_dialog.dart';



class PlayerScreen extends StatefulWidget {

  final String audioPath;

  final String jobId;



  const PlayerScreen({

    super.key,

    required this.audioPath,

    required this.jobId,

  });



  @override

  State<PlayerScreen> createState() => _PlayerScreenState();

}



class _PlayerScreenState extends State<PlayerScreen>

    with SingleTickerProviderStateMixin {

  final _player = AudioPlayer();

  late TabController _tabController;



  bool _isPlaying = false;

  bool _isLoading = true;

  Duration _duration = Duration.zero;

  Duration _position = Duration.zero;

  int _userRating = 0;



  @override

  void initState() {

    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _initPlayer();

    _loadExistingRating();

  }



  Future<void> _initPlayer() async {

    try {

      await _player.setFilePath(widget.audioPath);

      setState(() {

        _isLoading = false;

        _duration = _player.duration ?? Duration.zero;

      });



      _player.positionStream.listen((pos) {

        if (mounted) setState(() => _position = pos);

      });



      _player.durationStream.listen((dur) {

        if (mounted && dur != null) setState(() => _duration = dur);

      });



      _player.playerStateStream.listen((state) {

        if (mounted) {

          setState(() => _isPlaying = state.playing);

          if (state.processingState == ProcessingState.completed) {

            _player.seek(Duration.zero);

            _player.pause();

          }

        }

      });

    } catch (e) {

      if (mounted) {

        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to load audio: $e')),

        );

      }

    }

  }



  Future<void> _loadExistingRating() async {

    final prefs = await SharedPreferences.getInstance();

    final rating = prefs.getInt('rating_${widget.jobId}') ?? 0;

    if (mounted) setState(() => _userRating = rating);

  }



  Future<void> _saveRating(int rating) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('rating_${widget.jobId}', rating);

    setState(() => _userRating = rating);



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          'Rating saved! (${rating} / 5 stars)',

          style: GoogleFonts.spaceMono(fontSize: 12),

        ),

        backgroundColor: const Color(0xFF1C1C30),

      ),

    );

  }



  Future<void> _togglePlay() async {

    if (_isPlaying) {

      await _player.pause();

    } else {

      await _player.play();

    }

  }



  Future<void> _seekTo(double value) async {

    final target = Duration(milliseconds: value.toInt());

    await _player.seek(target);

  }



  String _formatDuration(Duration d) {

    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');

    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$m:$s';

  }



  void _openMixingCopilot() {

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) => MixingCopilotModal(

        onInstructionApplied: (instruction) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text('AI Producer adjusted: $instruction'),

              backgroundColor: const Color(0xFF6C63FF),

            ),

          );

        },

      ),

    );

  }



  void _openVideoExport() {

    showDialog(

      context: context,

      builder: (_) => VideoExportDialog(

        jobId: widget.jobId,

        genre: 'TRAP',

        onExportVideo: () {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(

              content: Text('Rendering 9:16 vertical video visualizer...'),

              backgroundColor: Color(0xFF6C63FF),

            ),

          );

        },

      ),

    );

  }



  @override

  void dispose() {

    _player.dispose();

    _tabController.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final generatorProvider = context.watch<GeneratorProvider>();

    final stems = generatorProvider.downloadedStems;



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

          'AUREON MASTER',

          style: GoogleFonts.spaceMono(

            color: Colors.white,

            fontSize: 14,

            fontWeight: FontWeight.bold,

            letterSpacing: 3,

          ),

        ),

        centerTitle: true,

        bottom: TabBar(

          controller: _tabController,

          indicatorColor: const Color(0xFF6C63FF),

          indicatorWeight: 3,

          labelColor: Colors.white,

          unselectedLabelColor: const Color(0xFF8888AA),

          labelStyle: GoogleFonts.spaceMono(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),

          tabs: const [

            Tab(text: 'MASTER'),

            Tab(text: '4-STEM DAW'),

            Tab(text: 'FX & COPILOT'),

          ],

        ),

      ),

      body: TabBarView(

        controller: _tabController,

        children: [

          // ── TAB 1: Master Track Player ────────────────────────────────────

          SingleChildScrollView(

            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),

            child: Column(

              children: [

                // Spectral Glowing Artwork Box

                Container(

                  width: double.infinity,

                  height: 220,

                  decoration: BoxDecoration(

                    borderRadius: BorderRadius.circular(24),

                    gradient: const LinearGradient(

                      begin: Alignment.topLeft,

                      end: Alignment.bottomRight,

                      colors: [Color(0xFF15152A), Color(0xFF0E0E1E)],

                    ),

                    border: Border.all(

                      color: const Color(0xFF6C63FF).withOpacity(0.4),

                      width: 1.5,

                    ),

                    boxShadow: [

                      BoxShadow(

                        color: const Color(0xFF6C63FF).withOpacity(_isPlaying ? 0.25 : 0.1),

                        blurRadius: 35,

                        spreadRadius: 2,

                      ),

                    ],

                  ),

                  child: Column(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      Icon(

                        Icons.album_rounded,

                        color: _isPlaying ? const Color(0xFFFF6584) : const Color(0xFF6C63FF),

                        size: 50,

                      ),

                      const SizedBox(height: 14),

                      Spectrogram3D(),

                    ],

                  ),

                ),



                const SizedBox(height: 20),



                // Track Info

                Text(

                  'Aureon AI Production',

                  style: GoogleFonts.spaceMono(

                    color: Colors.white,

                    fontSize: 18,

                    fontWeight: FontWeight.bold,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  'JOB: ${widget.jobId.substring(0, 8).toUpperCase()} • -14 LUFS MASTER',

                  style: GoogleFonts.spaceMono(

                    color: const Color(0xFF38F9D7),

                    fontSize: 10,

                    letterSpacing: 2,

                  ),

                ),



                const SizedBox(height: 20),



                // Audio Slider

                SliderTheme(

                  data: SliderTheme.of(context).copyWith(

                    activeTrackColor: const Color(0xFF6C63FF),

                    inactiveTrackColor: const Color(0xFF1A1A2E),

                    thumbColor: const Color(0xFF6C63FF),

                    overlayColor: const Color(0xFF6C63FF).withOpacity(0.2),

                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),

                    trackHeight: 3,

                  ),

                  child: Slider(

                    value: _position.inMilliseconds

                        .clamp(0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1)

                        .toDouble(),

                    max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,

                    onChanged: _seekTo,

                  ),

                ),



                Padding(

                  padding: const EdgeInsets.symmetric(horizontal: 6),

                  child: Row(

                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [

                      Text(

                        _formatDuration(_position),

                        style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 11),

                      ),

                      Text(

                        _formatDuration(_duration),

                        style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 11),

                      ),

                    ],

                  ),

                ),



                const SizedBox(height: 16),

                  const TimeTravelSlider(),

                  const SizedBox(height: 16),



                // Playback Controls

                Row(

                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [

                    IconButton(

                      icon: const Icon(Icons.replay_10, color: Color(0xFF8888AA)),

                      iconSize: 32,

                      onPressed: () {

                        final target = _position - const Duration(seconds: 10);

                        _player.seek(target < Duration.zero ? Duration.zero : target);

                      },

                    ),

                    const SizedBox(width: 20),

                    GestureDetector(

                      onTap: _isLoading ? null : _togglePlay,

                      child: Container(

                        width: 68,

                        height: 68,

                        decoration: BoxDecoration(

                          shape: BoxShape.circle,

                          gradient: const LinearGradient(

                            colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],

                          ),

                          boxShadow: [

                            BoxShadow(

                              color: const Color(0xFF6C63FF).withOpacity(0.45),

                              blurRadius: 20,

                              spreadRadius: 2,

                            ),

                          ],

                        ),

                        child: _isLoading

                            ? const Padding(

                                padding: EdgeInsets.all(18),

                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),

                              )

                            : Icon(

                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,

                                color: Colors.white,

                                size: 38,

                              ),

                      ),

                    ),

                    const SizedBox(width: 20),

                    IconButton(

                      icon: const Icon(Icons.forward_10, color: Color(0xFF8888AA)),

                      iconSize: 32,

                      onPressed: () {

                        final target = _position + const Duration(seconds: 10);

                        _player.seek(target > _duration ? _duration : target);

                      },

                    ),

                  ],

                ),



                const SizedBox(height: 24),



                // Social Export & Stems Bar

                Row(

                  children: [

                    Expanded(

                      child: OutlinedButton.icon(

                        icon: const Icon(Icons.video_collection_rounded, size: 16, color: Color(0xFFFF6584)),

                        label: Text(

                          '9:16 VIDEO',

                          style: GoogleFonts.spaceMono(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold),

                        ),

                        onPressed: _openVideoExport,

                        style: OutlinedButton.styleFrom(

                          foregroundColor: Colors.white,

                          side: const BorderSide(color: Color(0xFF2A2A3E)),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                          padding: const EdgeInsets.symmetric(vertical: 12),

                        ),

                      ),

                    ),

                    const SizedBox(width: 10),

                    Expanded(

                      child: OutlinedButton.icon(

                        icon: const Icon(Icons.folder_zip_rounded, size: 16, color: Color(0xFF38F9D7)),

                        label: Text(

                          'STEMS .ZIP',

                          style: GoogleFonts.spaceMono(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold),

                        ),

                        onPressed: () {

                          ScaffoldMessenger.of(context).showSnackBar(

                            const SnackBar(content: Text('Downloading 4-Stem DAW ZIP package...')),

                          );

                        },

                        style: OutlinedButton.styleFrom(

                          foregroundColor: Colors.white,

                          side: const BorderSide(color: Color(0xFF2A2A3E)),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                          padding: const EdgeInsets.symmetric(vertical: 12),

                        ),

                      ),

                    ),

                  ],

                ),



                const SizedBox(height: 20),



                // Rating Box

                Container(

                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(

                    color: const Color(0xFF11111E),

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(color: const Color(0xFF222238)),

                  ),

                  child: Row(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: List.generate(5, (i) {

                      final star = i + 1;

                      return GestureDetector(

                        onTap: () => _saveRating(star),

                        child: Padding(

                          padding: const EdgeInsets.symmetric(horizontal: 6),

                          child: Icon(

                            star <= _userRating ? Icons.star_rounded : Icons.star_outline_rounded,

                            color: star <= _userRating ? const Color(0xFFFFBE0B) : const Color(0xFF33334D),

                            size: 28,

                          ),

                        ),

                      );

                    }),

                  ),

                ),

              ],

            ),

          ),



          // ── TAB 2: 4-Stem Mini-DAW ────────────────────────────────────────

          SingleChildScrollView(

            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),

            child: stems.isNotEmpty

                ? StemPlayerWidget(stemPaths: stems)

                : Container(

                    padding: const EdgeInsets.all(28),

                    decoration: BoxDecoration(

                      color: const Color(0xFF11111E),

                      borderRadius: BorderRadius.circular(20),

                      border: Border.all(color: const Color(0xFF222238)),

                    ),

                    child: Column(

                      children: [

                        const Icon(Icons.tune_rounded, color: Color(0xFF6C63FF), size: 44),

                        const SizedBox(height: 12),

                        Text(

                          '4-Stem Isolation Ready',

                          style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),

                        ),

                        const SizedBox(height: 6),

                        Text(

                          'Vocals, Drums, Bass, and Melody channels are ready for solo/mute mixing.',

                          textAlign: TextAlign.center,

                          style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 11),

                        ),

                      ],

                    ),

                  ),

          ),



          // ── TAB 3: DSP FX & Copilot ───────────────────────────────────────

          SingleChildScrollView(

            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),

            child: Column(

              children: [

                // Floating AI Copilot Card

                InkWell(

                  onTap: _openMixingCopilot,

                  borderRadius: BorderRadius.circular(18),

                  child: Container(

                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(

                      gradient: LinearGradient(

                        colors: [const Color(0xFF6C63FF).withOpacity(0.2), const Color(0xFFFF6584).withOpacity(0.15)],

                      ),

                      borderRadius: BorderRadius.circular(18),

                      border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),

                    ),

                    child: Row(

                      children: [

                        const Icon(Icons.smart_toy_rounded, color: Color(0xFF6C63FF), size: 28),

                        const SizedBox(width: 14),

                        Expanded(

                          child: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              Text(

                                'AI Mixing Engineer Copilot',

                                style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),

                              ),

                              Text(

                                'Tap to instruct adjustments by text or voice...',

                                style: GoogleFonts.spaceMono(color: const Color(0xFF8888AA), fontSize: 10),

                              ),

                            ],

                          ),

                        ),

                        const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),

                      ],

                    ),

                  ),

                ),



                const SizedBox(height: 16),



                // Studio Effects Hardware Rack

                Container(height: 300, child: const NodeGraphEditor()),

                const SizedBox(height: 16),

                StudioEffectsRack(

                  jobId: widget.jobId,

                  onApplyEffects: (params) {

                    ScaffoldMessenger.of(context).showSnackBar(

                      const SnackBar(

                        content: Text('Master re-rendered through DSP Effects Rack!'),

                        backgroundColor: Color(0xFF43E97B),

                      ),

                    );

                  },

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}

