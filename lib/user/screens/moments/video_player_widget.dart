// lib/user/widgets/neo_video_player.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const _kNeoYellow = Color(0xFFFFD54F);

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
        if (!mounted) return;
        setState(() => _isInitialized = true);
        _videoController.setLooping(true);
        _videoController.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: _kNeoYellow, strokeWidth: 3),
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

        // Nút Play Neo-Brutalism (Khối đặc, viền dày, bóng gắt)
        if (!_videoController.value.isPlaying)
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kNeoYellow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 4),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 60,
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