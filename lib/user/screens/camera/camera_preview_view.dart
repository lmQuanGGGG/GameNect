// lib/user/screens/camera_preview_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

const _kNeoAccent = Color(0xFFFF6E40);
const _kNeoYellow = Color(0xFFFFD54F);

class CameraPreviewView extends StatelessWidget {
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
    this.webImageBytes,
  });

  @override
  Widget build(BuildContext context) {
    if (capturedMedia == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final letterboxColor = isDark ? Colors.black : const Color(0xFFF4F4F0);
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;

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
                            child: isVideo
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
                              onTap: onClose,
                            ),
                          ),

                          // Nút Lật ảnh (chỉ hiển thị nếu không phải video)
                          if (!isVideo)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: _NeoBtn(
                                icon: Icons.flip_rounded,
                                bgColor: isMirrored
                                    ? _kNeoYellow
                                    : Colors.white,
                                onTap: onToggleMirror,
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
                          onTap: onRetake,
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
                          onTap: onPost,
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
      imageWidget = Image.network(capturedMedia!.path, fit: BoxFit.cover);
    } else {
      imageWidget = Image.file(File(capturedMedia!.path), fit: BoxFit.cover);
    }

    Widget processedImage = imageWidget;

    if (isFrontCamera) {
      processedImage = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          1.00,
          0.0,
          0.0,
          0.0,
          18.0, // R: Giữ nguyên tỷ lệ 1.0 để không phóng đại noise, chỉ cộng sáng
          0.0, 1.00, 0.0, 0.0, 18.0, // G: Giữ nguyên tỷ lệ 1.0 để ảnh mịn màng
          0.0,
          0.0,
          1.10,
          0.0,
          40.0, // B: Hạ scale từ 1.25 xuống 1.10 để chặn hạt, bù offset lên 40.0 để giữ độ trong
          0.0, 0.0, 0.0, 1.0, 0.0, // A
        ]),
        child: processedImage,
      );
    }

    if (isMirrored) {
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
    if (localThumbnailPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(localThumbnailPath!), fit: BoxFit.cover),
          // Nút Play Video Neo-Brutalism
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kNeoYellow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 4),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                ],
              ),
              child: const Icon(
                CupertinoIcons.play_fill,
                color: Colors.black,
                size: 36,
              ),
            ),
          ),
        ],
      );
    }

    // Trạng thái đang load hoặc xử lý video
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGeneratingThumbnail)
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
                isGeneratingThumbnail ? 'ĐANG XỬ LÝ...' : 'VIDEO ĐÃ QUAY',
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
