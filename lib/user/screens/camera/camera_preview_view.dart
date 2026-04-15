import 'package:flutter/material.dart';
import 'dart:io';

import 'package:camera/camera.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/preview_button.dart';

class CameraPreviewView extends StatelessWidget {
  final bool isVideo;
  final String? localThumbnailPath;
  final bool isGeneratingThumbnail;
  final bool isFrontCamera;
  final XFile? capturedMedia;
  
  final VoidCallback onRetake;
  final VoidCallback onPost;
  final VoidCallback onClose;

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
  });

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onPressed}) {
    return GlassIconButton(icon: icon, onPressed: onPressed);
  }

  Widget _buildPreviewButton({required IconData icon, required String label, required VoidCallback onPressed, required bool isPrimary}) {
    return PreviewButton(
      icon: icon,
      label: label,
      onPressed: onPressed,
      isPrimary: isPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (capturedMedia == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Preview media
          Center(
            child: isVideo
                ? (localThumbnailPath != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(localThumbnailPath!),
                              fit: BoxFit.contain,
                            ),
                            // Icon play
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color: Colors.black,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isGeneratingThumbnail)
                                  const CircularProgressIndicator(
                                    color: Colors.deepOrange,
                                  )
                                else
                                  const Icon(
                                    Icons.videocam_rounded,
                                    color: Colors.white54,
                                    size: 80,
                                  ),
                                const SizedBox(height: 16),
                                Text(
                                  isGeneratingThumbnail
                                      ? 'Đang xử lý...'
                                      : 'Video đã quay',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))
                : (isFrontCamera
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                        child: Image.file(
                          File(capturedMedia!.path),
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.file(
                        File(capturedMedia!.path),
                        fit: BoxFit.contain,
                      )),
          ),

          // Top bar với nút hủy
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                top: 50,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGlassIconButton(
                    icon: Icons.close,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          ),

          // Bottom actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                bottom: 40,
                left: 20,
                right: 20,
                top: 30,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPreviewButton(
                    icon: Icons.refresh_rounded,
                    label: 'Chụp lại',
                    onPressed: onRetake,
                    isPrimary: false,
                  ),
                  _buildPreviewButton(
                    icon: Icons.arrow_forward_rounded,
                    label: 'Đăng',
                    onPressed: onPost,
                    isPrimary: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
