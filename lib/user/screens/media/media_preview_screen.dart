// lib/user/screens/media_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

const _kNeoAccent = Color(0xFFFF6E40);

// Màn hình preview ảnh hoặc video trước khi gửi trong chat
// Neo-Brutalism Style
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
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lấy chiều cao của bàn phím để đẩy Bottom Bar lên
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black, // Nền đen để tôn Media lên
      body: Stack(
        children: [
          // ── 1. VÙNG PREVIEW MEDIA ──
          Positioned.fill(
            child: widget.isVideo && _videoController != null
                ? Center(
                    child: _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const CircularProgressIndicator(color: _kNeoAccent),
                  )
                : Center(
                    child: Image.file(
                      widget.file,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),

          // ── 2. TOP BAR (Nút Đóng) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                ),
                child: const Icon(Icons.close_rounded, color: Colors.black, size: 28),
              ),
            ),
          ),

          // ── 3. BOTTOM BAR (Nhập Caption & Gửi) ──
          Positioned(
            bottom: bottomInset > 0 ? bottomInset + 16 : MediaQuery.of(context).padding.bottom + 24,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Ô nhập Caption
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                    ),
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(
                        color: Colors.black, 
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'THÊM CHÚ THÍCH...',
                        hintStyle: TextStyle(
                          color: Colors.black.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Nút Gửi
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context, _captionController.text.trim());
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _kNeoAccent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.black, size: 26),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}