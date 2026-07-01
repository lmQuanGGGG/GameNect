// lib/user/screens/camera/camera_preview_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

const _kNeoAccent = Color(0xFFFF6E40);
const _kNeoYellow = Color(0xFFFFD54F);

class CameraPreviewView extends StatefulWidget {
  final bool isVideo;
  final String? localThumbnailPath;
  final bool isGeneratingThumbnail;
  final bool isFrontCamera;
  final XFile? capturedMedia;
  final bool isMirrored;
  final Uint8List? webImageBytes;

  final VoidCallback onRetake;
  final VoidCallback onPost;
  final VoidCallback onClose;
  final VoidCallback onToggleMirror;
  final bool isFilterEnabled;
  final VoidCallback onToggleFilter;

  const CameraPreviewView({
    super.key,
    required this.isVideo,
    required this.localThumbnailPath,
    required this.isGeneratingThumbnail,
    required this.isFrontCamera,
    required this.capturedMedia,
    required this.onRetake,
    required this.onPost,
    required this.onClose,
    required this.isMirrored,
    required this.onToggleMirror,
    required this.isFilterEnabled,
    required this.onToggleFilter,
    this.webImageBytes,
  });

  @override
  State<CameraPreviewView> createState() => _CameraPreviewViewState();
}

class _CameraPreviewViewState extends State<CameraPreviewView> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo && widget.capturedMedia != null) {
      if (kIsWeb) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.capturedMedia!.path),
        );
      } else {
        _videoController = VideoPlayerController.file(
          File(widget.capturedMedia!.path),
        );
      }
      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        }
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.capturedMedia == null) return const SizedBox.shrink();

    final letterboxColor = Colors.white;
    final borderColor = Colors.black;
    final shadowColor = Colors.black;

    return Scaffold(
      backgroundColor: letterboxColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 80,
            ), // Dummy top bar để khung camera căn giữa y hệt lúc chụp
            // ── PHẦN 1: KHUNG PREVIEW (3:4) ──
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: borderColor, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            offset: const Offset(4, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Hình ảnh / Video Cover
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: widget.isVideo
                                ? _buildVideoPreview()
                                : _buildImagePreview(),
                          ),

                          // Nút Close góc trên cùng bên trái
                          Positioned(
                            top: 16,
                            left: 16,
                            child: _NeoBtn(
                              icon: Icons.close_rounded,
                              bgColor: Colors.white,
                              onTap: widget.onClose,
                            ),
                          ),

                          // Nút Lật ảnh & Bật/tắt Filter (chỉ hiển thị nếu không phải video)
                          if (!widget.isVideo)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Column(
                                children: [
                                  _NeoBtn(
                                    icon: Icons.flip_rounded,
                                    bgColor: widget.isMirrored
                                        ? _kNeoYellow
                                        : Colors.white,
                                    onTap: widget.onToggleMirror,
                                  ),
                                  const SizedBox(height: 16),
                                  _NeoBtn(
                                    icon: widget.isFilterEnabled
                                        ? Icons.auto_awesome_rounded
                                        : Icons.auto_awesome_outlined,
                                    bgColor: widget.isFilterEnabled
                                        ? _kNeoYellow
                                        : Colors.white,
                                    onTap: widget.onToggleFilter,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── PHẦN 2: KHU VỰC NÚT BẤM DƯỚI ──
            Container(
              height:
                  176, // Tương đương chiều cao bottom bar bên kia để Center() tính toán không gian còn lại y hệt
              color: letterboxColor,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Nút CHỤP LẠI
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onRetake,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.refresh_thick,
                                  color: Colors.black,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'CHỤP LẠI',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Nút ĐĂNG NGAY
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onPost,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: _kNeoAccent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'ĐĂNG NGAY',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  CupertinoIcons.paperplane_fill,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Preview dành cho Ảnh - Đã tối ưu màu Locket Cam
  Widget _buildImagePreview() {
    final Widget imageWidget;
    if (kIsWeb) {
      imageWidget = Image.network(
        widget.capturedMedia!.path,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = Image.file(
        File(widget.capturedMedia!.path),
        fit: BoxFit.cover,
      );
    }

    Widget processedImage = imageWidget;

    // Bộ lọc chuẩn Locket: Tăng tương phản mạnh (hết bệt), bù sáng và giữ tone lạnh (hết vàng)
    // Áp dụng bộ lọc Locket nếu bật
    if (widget.isFilterEnabled) {
      processedImage = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          1.12, 0.0, 0.0, 0.0, 5.0, // Kéo dãn dải Đỏ, cộng thêm 5 điểm sáng
          0.0, 1.12, 0.0, 0.0, 5.0, // Kéo dãn dải Xanh lá, cộng thêm 5 điểm sáng
          0.0, 0.0, 1.18, 0.0, 15.0, // Bơm mạnh Xanh dương và cộng thêm 15 điểm sáng để da trắng sáng
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]),
        child: processedImage,
      );
    }

    // Trên Mobile, Image.file đã tự động áp dụng thông số lật gương từ EXIF của ảnh
    // Chỉ lật lại thủ công bằng Transform nếu là Web (do Web không có EXIF)
    if (widget.isMirrored) {
      processedImage = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.141592653589793), // pi
        child: processedImage,
      );
    }

    return processedImage;
  }

  // Preview dành cho Video
  Widget _buildVideoPreview() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      Widget videoWidget = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      );

      if (widget.isMirrored) {
        videoWidget = Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(3.141592653589793), // pi
          child: videoWidget,
        );
      }

      return Stack(fit: StackFit.expand, children: [videoWidget]);
    }

    // Trạng thái đang load hoặc xử lý video
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isGeneratingThumbnail)
              const CircularProgressIndicator(
                color: _kNeoAccent,
                strokeWidth: 4,
              )
            else
              const Icon(
                CupertinoIcons.videocam_fill,
                color: Colors.white,
                size: 64,
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                ],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.isGeneratingThumbnail
                    ? 'ĐANG XỬ LÝ...'
                    : 'VIDEO ĐÃ QUAY',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CUSTOM COMPONENT ──
class _NeoBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color bgColor;

  const _NeoBtn({
    required this.icon,
    required this.onTap,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(4, 4)),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 28),
      ),
    );
  }
}
