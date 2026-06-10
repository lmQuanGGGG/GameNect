import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'video_player_bubble.dart';

class FullScreenMediaViewer extends StatelessWidget {
  final String mediaUrl;
  final bool isVideo;

  const FullScreenMediaViewer({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 10)]),
      ),
      body: Center(
        child: isVideo
            ? SafeArea(child: VideoPlayerBubble(videoUrl: mediaUrl))
            : InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6E40)),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 40),
                  ),
                ),
              ),
      ),
    );
  }
}
