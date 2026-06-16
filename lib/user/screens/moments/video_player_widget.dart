// lib/user/widgets/neo_video_player.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';

const _kNeoYellow = Color(0xFFFFD54F);

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool handleTap;
  final bool muted;
  final bool compactControls;
  final bool webAutoplayFallback;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.handleTap = true,
    this.muted = false,
    this.compactControls = false,
    this.webAutoplayFallback = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _wasPlaying = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
          ..addListener(_handlePlaybackChange)
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() => _isInitialized = true);
            _videoController.setLooping(true);
            _isMuted = widget.muted || (kIsWeb && widget.webAutoplayFallback);
            _videoController.setVolume(_isMuted ? 0 : 1);
            _videoController.play();
          });
  }

  void _handleTap() {
    if (_isMuted && !widget.muted) {
      _videoController.setVolume(1);
      setState(() => _isMuted = false);
      if (!_videoController.value.isPlaying) {
        _videoController.play();
      }
      return;
    }

    setState(() {
      _videoController.value.isPlaying
          ? _videoController.pause()
          : _videoController.play();
    });
  }

  void _handlePlaybackChange() {
    final isPlaying = _videoController.value.isPlaying;
    if (!mounted || isPlaying == _wasPlaying) return;
    _wasPlaying = isPlaying;
    setState(() {});
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
            child: widget.handleTap
                ? GestureDetector(
                    onTap: _handleTap,
                    child: VideoPlayer(_videoController),
                  )
                : VideoPlayer(_videoController),
          ),
        ),

        if (_isMuted && !widget.muted)
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: _handleTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),

        // Nút Play Neo-Brutalism (Khối đặc, viền dày, bóng gắt)
        if (!_videoController.value.isPlaying)
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _videoController.play();
                });
              },
              child: Container(
                padding: EdgeInsets.all(widget.compactControls ? 8 : 20),
                decoration: BoxDecoration(
                  color: _kNeoYellow,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black,
                    width: widget.compactControls ? 3 : 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(
                        widget.compactControls ? 3 : 6,
                        widget.compactControls ? 3 : 6,
                      ),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: widget.compactControls ? 28 : 60,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _videoController.removeListener(_handlePlaybackChange);
    _videoController.dispose();
    super.dispose();
  }
}
