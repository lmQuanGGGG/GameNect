import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';

/// Widget phát video với điều khiển play/pause bằng cách tap.
/// Tự động play và loop khi khởi tạo.
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _videoController.setLooping(true);
        _videoController.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepOrange, strokeWidth: 3),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _videoController.value.aspectRatio,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _videoController.value.isPlaying
                      ? _videoController.pause()
                      : _videoController.play();
                });
              },
              child: VideoPlayer(_videoController),
            ),
          ),
        ),

        // Overlay play button khi pause
        if (!_videoController.value.isPlaying)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }
}
