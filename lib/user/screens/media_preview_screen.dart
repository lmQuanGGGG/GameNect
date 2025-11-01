import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:ui';

class MediaPreviewScreen extends StatefulWidget {
  final File file;
  final bool isVideo;

  const MediaPreviewScreen({
    super.key,
    required this.file,
    required this.isVideo,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Preview media
          Positioned.fill(
            child: widget.isVideo && _videoController != null
                ? Center(
                    child: _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const CircularProgressIndicator(
                            color: Color(0xFFFF453A),
                          ),
                  )
                : Center(
                    child: Image.file(
                      widget.file,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),

          // Top bar với nút back
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom bar với caption và nút gửi
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _captionController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Thêm chú thích...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF453A),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                fillColor: Colors.black.withValues(alpha: 0.3),
                                filled: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFF453A),
                                  Color(0xFFFF6961),
                                ],
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  _captionController.text.trim(),
                                );
                              },
                            ),
                          ),
                        ],
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
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }
}