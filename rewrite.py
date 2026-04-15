import re

with open('lib/user/screens/camera/camera_capture_screen.dart', 'r') as f:
    content = f.read()

# We need to completely replace _CameraCaptureScreenState inside camera_capture_screen.dart, except the dialogs and upload functions.
# Actually, the file is so long, we can just replace everything in one go.

replacement = """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/moment_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:ui';
import 'package:logger/logger.dart';
import '../../../core/utils/video_thumbnail_helper.dart';
import 'dart:developer' as developer;
import '../../../core/services/firestore_service.dart';
import '../premium/subscription_screen.dart';

import '../../widgets/glass_button.dart';
import 'camera_preview_view.dart';
// Note: Removed old camera_top_bar.dart and camera_controls.dart

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  XFile? _capturedMedia;
  bool _isVideo = false;
  String? _localThumbnailPath;
  bool _isGeneratingThumbnail = false;
  
  final Logger _logger = Logger();
  final ImagePicker _picker = ImagePicker();

  Future<void> _generateThumbnail(String videoPath) async {
    setState(() => _isGeneratingThumbnail = true);
    try {
      final thumbnailPath = await VideoThumbnailHelper.generateThumbnail(videoPath);
      if (mounted && thumbnailPath != null) {
        setState(() {
          _localThumbnailPath = thumbnailPath;
          _isGeneratingThumbnail = false;
        });
      }
    } catch (e) {
      _logger.e('Error generating thumbnail: $e');
      if (mounted) setState(() => _isGeneratingThumbnail = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Chọn loại file', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 20),
                      GlassButton(icon: Icons.photo_rounded, label: 'Ảnh', onTap: () => Navigator.pop(ctx, 'image')),
                      const SizedBox(height: 12),
                      GlassButton(icon: Icons.videocam_rounded, label: 'Video (≤ 15s)', onTap: () => Navigator.pop(ctx, 'video')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if (choice == null) return;
      XFile? pickedFile;
      if (choice == 'image') {
        pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          setState(() {
            _capturedMedia = pickedFile;
            _isVideo = false;
            _localThumbnailPath = null;
          });
        }
      } else {
        pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
        if (pickedFile != null) {
          final videoController = VideoPlayerController.file(File(pickedFile.path));
          await videoController.initialize();
          final duration = videoController.value.duration.inSeconds;
          await videoController.dispose();

          if (duration > 15) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video phải ngắn hơn hoặc bằng 15 giây!'), backgroundColor: Colors.red));
            return;
          }

          setState(() {
            _capturedMedia = pickedFile;
            _isVideo = true;
          });
          await _generateThumbnail(pickedFile.path);
        }
      }
    } catch (e) {
      _logger.e('Pick from gallery error: $e');
    }
  }

  Future<void> _uploadAndPost() async {
    if (_capturedMedia == null) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final canPost = await FirestoreService().canPostMoment(userId);
      if (!canPost) {
        await _showPremiumUpsellDialog();
        return;
      }
    } catch (e) {
      developer.log('Check limit error: $e', name: 'CameraCapture');
    }

    final caption = await _showCaptionDialog();
    if (caption == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
    );

    try {
      String? mediaUrl;
      String? thumbnailUrl;

      if (_isVideo) {
        final videoRef = FirebaseStorage.instance.ref().child('moments/$userId/video_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await videoRef.putFile(File(_capturedMedia!.path));
        mediaUrl = await videoRef.getDownloadURL();

        if (_localThumbnailPath != null) {
          final thumbRef = FirebaseStorage.instance.ref().child('moments/$userId/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await thumbRef.putFile(File(_localThumbnailPath!));
          thumbnailUrl = await thumbRef.getDownloadURL();
        }
      } else {
        XFile imageToUpload = _capturedMedia!;
        final imageRef = FirebaseStorage.instance.ref().child('moments/$userId/image_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final metadata = SettableMetadata(contentType: 'image/jpeg', customMetadata: {'quality': 'high'});
        await imageRef.putFile(File(imageToUpload.path), metadata);
        mediaUrl = await imageRef.getDownloadURL();
      }

      if (!mounted) return;
      final momentProvider = Provider.of<MomentProvider>(context, listen: false);
      final matchedUserIds = await momentProvider.getMatchedUserIds(userId);

      await momentProvider.postMoment(
        userId: userId,
        mediaUrl: mediaUrl,
        isVideo: _isVideo,
        matchIds: matchedUserIds,
        caption: caption.isEmpty ? null : caption,
        thumbnailUrl: thumbnailUrl,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đăng khoảnh khắc!'), backgroundColor: Colors.green));
    } catch (e) {
      developer.log('Error uploading moment: $e', name: 'CameraCapture', error: e);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final msg = e.toString();
      if (msg.contains('LIMIT_EXCEEDED')) {
        await _showPremiumUpsellDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _showPremiumUpsellDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.deepOrange.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.85)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 56),
                    ),
                    const SizedBox(height: 20),
                    const Text('Nâng cấp Premium', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text('Bạn đã đăng đủ 20 khoảnh khắc trong tháng này!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, height: 1.5)),
                    const SizedBox(height: 6),
                    Text('Nâng cấp để đăng không giới hạn', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5))),
                            child: Text('Để sau', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 8, shadowColor: Colors.deepOrange.withValues(alpha: 0.5)),
                            child: const Text('Nâng cấp ngay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _showCaptionDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5)),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thêm chú thích', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1)),
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        maxLines: 4,
                        decoration: InputDecoration(hintText: 'Bạn đang nghĩ gì?', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16), border: InputBorder.none, contentPadding: const EdgeInsets.all(16)),
                        autofocus: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                          child: Text('Hủy', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          child: const Text('Đăng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedMedia != null) {
      return CameraPreviewView(
        isVideo: _isVideo,
        localThumbnailPath: _localThumbnailPath,
        isGeneratingThumbnail: _isGeneratingThumbnail,
        isFrontCamera: false, // Not needed anymore as image is straight
        capturedMedia: _capturedMedia,
        onRetake: () {
          if (_localThumbnailPath != null) {
            try { File(_localThumbnailPath!).deleteSync(); } catch (_) {}
          }
          setState(() {
            _capturedMedia = null;
            _localThumbnailPath = null;
          });
        },
        onPost: _uploadAndPost,
        onClose: () {
          if (_localThumbnailPath != null) {
            try { File(_localThumbnailPath!).deleteSync(); } catch (_) {}
          }
          setState(() {
            _capturedMedia = null;
            _localThumbnailPath = null;
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraAwesomeBuilder.awesome(
        saveConfig: SaveConfig.photoAndVideo(
          initialCaptureMode: CaptureMode.photo,
          mirrorFrontCamera: true, // Auto mirror for selfies
        ),
        sensorConfig: SensorConfig.multiple(
          sensors: [
            Sensor.position(SensorPosition.back),
            Sensor.position(SensorPosition.front),
          ],
          flashMode: FlashMode.none,
          aspectRatio: CameraAspectRatios.ratio_16_9,
        ),
        onMediaCaptureEvent: (event) {
          switch ((event.status, event.isPicture, event.isVideo)) {
            case (MediaCaptureStatus.capturing, _, _):
              developer.log('Capturing...', name: 'CameraAwesome');
            case (MediaCaptureStatus.success, true, false):
              event.captureRequest.when(single: (single) {
                if (single.file != null && mounted) {
                  setState(() {
                    _isVideo = false;
                    _capturedMedia = XFile(single.file!.path);
                  });
                }
              });
            case (MediaCaptureStatus.success, false, true):
              event.captureRequest.when(single: (single) {
                if (single.file != null && mounted) {
                  setState(() {
                    _isVideo = true;
                    _capturedMedia = XFile(single.file!.path);
                  });
                  _generateThumbnail(single.file!.path);
                }
              });
            case (MediaCaptureStatus.failure, _, _):
              developer.log('Failed to capture: ${event.exception}', name: 'CameraAwesome');
            default:
              developer.log('Unknown media event', name: 'CameraAwesome');
          }
        },
        topActionsBuilder: (state) => AwesomeTopActions(
          padding: EdgeInsets.zero,
          state: state,
          children: [
            AwesomeFlashButton(state: state),
            if (state is VideoRecordingCameraState)
              AwesomePauseResumeButton(state: state),
          ],
        ),
        bottomActionsBuilder: (state) => AwesomeBottomActions(
          state: state,
          left: AwesomeCameraSwitchButton(state: state, scale: 1.0),
          right: IconButton(
            icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 30),
            onPressed: _pickFromGallery,
          ),
        ),
      ),
      floatingActionButton: Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 10,
        child: SafeArea(
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ).child,
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
    );
  }
}
"""

with open('lib/user/screens/camera/camera_capture_screen.dart', 'w') as f:
    f.write(replacement)

