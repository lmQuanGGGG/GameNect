import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';

/// Widget video player bubble
/// Hiển thị video với nút play/pause overlay trong tin nhắn
class VideoPlayerBubble extends StatefulWidget {
  final String videoUrl;
  
  const VideoPlayerBubble({super.key, required this.videoUrl});

  @override
  State<VideoPlayerBubble> createState() => _VideoPlayerBubbleState();
}

class _VideoPlayerBubbleState extends State<VideoPlayerBubble> {
  late VideoPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    // Initialize video player từ URL
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isReady = true);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      // Hiển thị loading khi video chưa initialize
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF453A)),
        ),
      );
    }
    
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        children: [
          VideoPlayer(_controller),
          // Overlay với nút play/pause
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
                // Nút play chỉ hiển thị khi video không phát
                child: _controller.value.isPlaying
                    ? const SizedBox.shrink()
                    : Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
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
    _controller.dispose();
    super.dispose();
  }
}
