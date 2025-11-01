import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:ui';

class VoicePreviewScreen extends StatefulWidget {
  final File audioFile;
  final int duration;

  const VoicePreviewScreen({
    super.key,
    required this.audioFile,
    required this.duration,
  });

  @override
  State<VoicePreviewScreen> createState() => _VoicePreviewScreenState();
}

class _VoicePreviewScreenState extends State<VoicePreviewScreen> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setFilePath(widget.audioFile.path);
    
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    const Color(0xFFFF453A).withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Waveform animation (placeholder)
                Container(
                  width: 200,
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(20, (index) {
                      final height = 20.0 + (index % 3) * 20.0;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 4,
                        height: _isPlaying ? height : 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 40),

                // Play/Pause button
                GestureDetector(
                  onTap: () {
                    if (_isPlaying) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF453A), Color(0xFFFF6961)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF453A).withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Duration
                Text(
                  '${_position.inSeconds}s / ${widget.duration}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Bottom buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Nút hủy
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Hủy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Nút gửi
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF453A), Color(0xFFFF6961)],
                          ),
                        ),
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Gửi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}