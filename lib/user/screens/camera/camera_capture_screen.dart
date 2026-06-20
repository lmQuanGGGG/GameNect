import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../../core/providers/moment_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'dart:async';
import 'package:logger/logger.dart';
import '../../../core/utils/video_thumbnail_helper.dart';
import 'dart:developer' as developer;
import '../../../core/services/firestore_service.dart';
import 'camera_preview_view.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart' show PreviewSize, VideoOptions, VideoRecordingQuality;
import 'camera_dialogs.dart';

const _kNeoAccent = Color(0xFFFF6E40);
const _kNeoRed = Color(0xFFFF2D55);
const _kNeoYellow = Color(0xFFFFD54F);

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with TickerProviderStateMixin, CameraDialogsMixin {
  // ── Captured media ──────────────────────────────────────────────────────────
  XFile? _capturedMedia;
  bool _isVideo = false;
  String? _localThumbnailPath;
  bool _isGeneratingThumbnail = false;
  bool _isMirrored = false;
  Uint8List? _webImageBytes;

  // ── Camera UI state ──────────────────────────────────────────────────────────
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  bool _isFrontCamera = false;
  bool _isVideoMode = false;
  double _brightnessValue = 0.5;
  bool _needsLensReset = false;

  // Zoom: we store the label (0.5, 1, 2, 5) for UI, not camerawesome 0-1 scale
  double _currentZoomLabel = 1.0;

  // Sensor data (for ultra-wide detection)
  SensorDeviceData? _sensorDeviceData;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _shutterController;

  final Logger _logger = Logger();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _shutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickFromGallery().then((_) {
          if (_capturedMedia == null && mounted) {
            Navigator.pop(context); // Đóng nếu user cancel picker
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _shutterController.dispose();
    super.dispose();
  }

  // ── Zoom preset ──────────────────────────────────────────────────────────────
  Future<void> _setZoomPreset(double label, CameraState state) async {
    if (label == 0.5) {
      // Cam sau: có lens siêu rộng thật thì dùng
      if (!_isFrontCamera && _sensorDeviceData?.ultraWideAngle != null) {
        state.setSensorType(
          0,
          SensorType.ultraWideAngle,
          _sensorDeviceData!.ultraWideAngle!.uid,
        );
      } else {
        // Cam trước (hoặc cam sau k có lens): góc rộng nhất là mức zoom 0.0
        await state.sensorConfig.setZoom(0.0);
      }
    } else if (label == 1.0) {
      if (!_isFrontCamera) {
        // Cam sau: về wide-angle chính nếu có
        if (_sensorDeviceData?.wideAngle != null) {
          state.setSensorType(
            0,
            SensorType.wideAngle,
            _sensorDeviceData!.wideAngle!.uid,
          );
        }
        await state.sensorConfig.setZoom(0.0);
      } else {
        // Cam trước: 1× dùng nguyên bản phần cứng (không digital zoom, nét nhất)
        await state.sensorConfig.setZoom(0.0);
      }
    } else if (label == 2.0) {
      if (!_isFrontCamera && _sensorDeviceData?.telephoto != null) {
        state.setSensorType(
          0,
          SensorType.telephoto,
          _sensorDeviceData!.telephoto!.uid,
        );
      } else {
        await state.sensorConfig.setZoom(0.3);
      }
    } else if (label == 5.0) {
      await state.sensorConfig.setZoom(0.7);
    } else {
      await state.sensorConfig.setZoom(0.0);
    }
    if (mounted) setState(() => _currentZoomLabel = label);
  }

  // ── Capture actions ───────────────────────────────────────────────────────────
  void _takePicture(CameraState state) {
    _shutterController.forward(from: 0);
    state.when(onPhotoMode: (photoState) => photoState.takePhoto());
  }

  Future<void> _startRecording(CameraState state) async {
    try {
      await state.when(
        onVideoMode: (videoState) async {
          await videoState.startRecording();
          if (mounted) {
            setState(() {
              _isRecording = true;
              _recordingSeconds = 0;
            });
            _recordingTimer = Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) {
              setState(() => _recordingSeconds++);
              if (_recordingSeconds >= 5) _stopRecording(state);
            });
          }
        },
      );
    } catch (e) {
      _logger.e('Start recording error: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingSeconds = 0;
        });
      }
    }
  }

  Future<void> _stopRecording(CameraState state) async {
    _recordingTimer?.cancel();
    try {
      await state.when(
        onVideoRecordingMode: (recState) async {
          await recState.stopRecording();
        },
      );
    } catch (e) {
      _logger.w('Stop recording error: $e');
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });
    }
  }

  Future<void> _focusOnPreviewTap(
    CameraState state,
    Offset position,
    PreviewSize flutterPreviewSize,
    PreviewSize pixelPreviewSize,
  ) async {
    await state.when(
      onPhotoMode: (photoState) => photoState.focusOnPoint(
        flutterPosition: position,
        flutterPreviewSize: flutterPreviewSize,
        pixelPreviewSize: pixelPreviewSize,
      ),
      onVideoMode: (videoState) => videoState.focusOnPoint(
        flutterPosition: position,
        flutterPreviewSize: flutterPreviewSize,
        pixelPreviewSize: pixelPreviewSize,
      ),
      onVideoRecordingMode: (recordState) => recordState.focusOnPoint(
        flutterPosition: position,
        flutterPreviewSize: flutterPreviewSize,
        pixelPreviewSize: pixelPreviewSize,
      ),
      onPreviewMode: (previewState) => previewState.focusOnPoint(
        flutterPosition: position,
        flutterPreviewSize: flutterPreviewSize,
        pixelPreviewSize: pixelPreviewSize,
      ),
    );
  }

  Future<void> _resetRearLensIfNeeded(CameraState state) async {
    if (!_needsLensReset) return;
    _needsLensReset = false;

    if (_isFrontCamera) {
      if (mounted) setState(() => _currentZoomLabel = 1.0);
      await state.sensorConfig.setZoom(0.0);
      return;
    }

    try {
      if (_sensorDeviceData?.wideAngle != null) {
        state.setSensorType(
          0,
          SensorType.wideAngle,
          _sensorDeviceData!.wideAngle!.uid,
        );
      }
      await state.sensorConfig.setZoom(0.0);
      if (mounted) setState(() => _currentZoomLabel = 1.0);
    } catch (e) {
      _logger.w('Reset lens error: $e');
    }
  }

  // ── Media capture event ───────────────────────────────────────────────────────
  void _onMediaCaptureEvent(MediaCapture event) {
    if (event.status != MediaCaptureStatus.success) return;
    event.captureRequest.when(
      single: (single) {
        if (single.file == null || !mounted) return;
        if (event.isPicture) {
          setState(() {
            _isVideo = false;
            _capturedMedia = XFile(single.file!.path);
          });
        } else if (event.isVideo) {
          setState(() {
            _isVideo = true;
            _capturedMedia = XFile(single.file!.path);
          });
          _generateThumbnail(single.file!.path);
        }
      },
    );
  }

  // ── Thumbnail ─────────────────────────────────────────────────────────────────
  Future<void> _generateThumbnail(String videoPath) async {
    setState(() => _isGeneratingThumbnail = true);
    try {
      final path = await VideoThumbnailHelper.generateThumbnail(videoPath);
      if (mounted && path != null) {
        setState(() {
          _localThumbnailPath = path;
          _isGeneratingThumbnail = false;
        });
      }
    } catch (e) {
      _logger.e('Thumbnail error: $e');
      if (mounted) setState(() => _isGeneratingThumbnail = false);
    }
  }

  // ── Gallery picker ─────────────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;

    try {
      final choice = await showDialog<String>(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => Dialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 3),
          ),
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: shadowColor, offset: const Offset(4, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CHỌN LOẠI FILE',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 24),
                _NeoDialogButton(
                  icon: Icons.photo_rounded,
                  label: 'Ảnh',
                  bgColor: _kNeoYellow,
                  borderColor: borderColor,
                  textColor: Colors.black,
                  shadowColor: shadowColor,
                  onTap: () => Navigator.pop(ctx, 'image'),
                ),
                const SizedBox(height: 16),
                _NeoDialogButton(
                  icon: Icons.videocam_rounded,
                  label: 'Video (≤ 15s)',
                  bgColor: _kNeoAccent,
                  borderColor: borderColor,
                  textColor: Colors.black,
                  shadowColor: shadowColor,
                  onTap: () => Navigator.pop(ctx, 'video'),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Text(
                    'HỦY BỎ',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (choice == null) return;
      XFile? pickedFile;
      if (choice == 'image') {
        pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 1080,
        );
        if (pickedFile != null) {
          Uint8List? bytes;
          if (kIsWeb) {
            bytes = await pickedFile.readAsBytes();
          }
          setState(() {
            _capturedMedia = pickedFile;
            _webImageBytes = bytes;
            _isVideo = false;
            _localThumbnailPath = null;
            if (kIsWeb) {
              _isMirrored = true;
            }
          });
        }
      } else {
        pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
        if (pickedFile != null) {
          final vc = VideoPlayerController.file(File(pickedFile.path));
          await vc.initialize();
          final dur = vc.value.duration.inSeconds;
          await vc.dispose();
          if (dur > 5) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video phải ngắn hơn hoặc bằng 5 giây!'),
                backgroundColor: Colors.red,
              ),
            );
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
      _logger.e('Pick gallery error: $e');
    }
  }

  // ── Upload & post ─────────────────────────────────────────────────────────────
  Future<void> _uploadAndPost() async {
    if (_capturedMedia == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final mp = Provider.of<MomentProvider>(context, listen: false);

    // Check quota TRƯỚC KHI upload lên Storage
    try {
      final canPost = await mp.canPostMoment(userId: userId, isVideo: _isVideo);

      if (!canPost) {
        if (!mounted) return;

        if (_isVideo) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bạn chỉ được đăng tối đa 2 video/tháng hoặc đã hết 20 moment/tháng!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              backgroundColor: _kNeoRed,
            ),
          );
        } else {
          await showCameraPremiumUpsellDialog();
        }

        return;
      }
    } catch (e) {
      developer.log('Check limit error: $e', name: 'Camera');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không kiểm tra được giới hạn đăng moment. Vui lòng thử lại!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          backgroundColor: _kNeoRed,
        ),
      );
      return;
    }

    final caption = await showCameraCaptionDialog();
    if (caption == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.deepOrange),
      ),
    );

    Reference? uploadedMediaRef;
    Reference? uploadedThumbRef;

    try {
      String? mediaUrl;
      String? thumbnailUrl;

      if (kIsWeb) {
        // === WEB: dùng putData(bytes) thay vì putFile(File) ===
        var bytes = await _capturedMedia!.readAsBytes();

        if (_isVideo) {
          final ref = FirebaseStorage.instance.ref().child(
            'moments/$userId/video_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );

          uploadedMediaRef = ref;

          await ref.putData(
            bytes,
            SettableMetadata(
              contentType: 'video/mp4',
              cacheControl: 'public, max-age=31536000',
            ),
          );

          mediaUrl = await ref.getDownloadURL();
          thumbnailUrl = null;
        } else {
          final imageRef = FirebaseStorage.instance.ref().child(
            'moments/$userId/image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

          uploadedMediaRef = imageRef;

          if (_isFrontCamera) {
            bytes = await compute(_applyBeautyFilterIsolate, bytes);
          }

          if (_isMirrored) {
            bytes = await compute(_applyMirrorIsolate, bytes);
          }

          await imageRef.putData(
            bytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              cacheControl: 'public, max-age=31536000',
              customMetadata: {'quality': 'high'},
            ),
          );

          mediaUrl = await imageRef.getDownloadURL();
        }
      } else {
        // === MOBILE: dùng putFile như cũ ===
        if (_isVideo) {
          final ref = FirebaseStorage.instance.ref().child(
            'moments/$userId/video_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );

          uploadedMediaRef = ref;

          await ref.putFile(
            File(_capturedMedia!.path),
            SettableMetadata(
              contentType: 'video/mp4',
              cacheControl: 'public, max-age=31536000',
            ),
          );

          mediaUrl = await ref.getDownloadURL();

          if (_localThumbnailPath != null) {
            final thumbRef = FirebaseStorage.instance.ref().child(
              'moments/$userId/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );

            uploadedThumbRef = thumbRef;

            await thumbRef.putFile(
              File(_localThumbnailPath!),
              SettableMetadata(
                contentType: 'image/jpeg',
                cacheControl: 'public, max-age=31536000',
              ),
            );

            thumbnailUrl = await thumbRef.getDownloadURL();
          }
        } else {
          final imageRef = FirebaseStorage.instance.ref().child(
            'moments/$userId/image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

          uploadedMediaRef = imageRef;

          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'public, max-age=31536000',
            customMetadata: {'quality': 'high'},
          );

          // Nén cho TẤT CẢ các ảnh để tiết kiệm dung lượng
          final file = File(_capturedMedia!.path);
          var bytes = await file.readAsBytes();

          bytes = await compute(_applyBeautyFilterIsolate, bytes);

          if (_isMirrored) {
            bytes = await compute(_applyMirrorIsolate, bytes);
          }

          await file.writeAsBytes(bytes);

          await imageRef.putFile(File(_capturedMedia!.path), metadata);
          mediaUrl = await imageRef.getDownloadURL();
        }
      }

      if (!mounted) return;

      final matchedIds = await mp.getMatchedUserIds(userId);

      await mp.postMoment(
        userId: userId,
        mediaUrl: mediaUrl,
        isVideo: _isVideo,
        matchIds: matchedIds,
        caption: caption.isEmpty ? null : caption,
        thumbnailUrl: thumbnailUrl,
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ĐÃ ĐĂNG LÊN FEED!',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      developer.log('Upload error: $e', name: 'Camera', error: e);

      // Nếu upload lên Storage rồi nhưng tạo moment thất bại thì xóa file rác
      try {
        if (uploadedThumbRef != null) {
          await uploadedThumbRef!.delete();
        }
      } catch (_) {}

      try {
        if (uploadedMediaRef != null) {
          await uploadedMediaRef!.delete();
        }
      } catch (_) {}

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      final msg = e.toString();

      if (msg.contains('VIDEO_LIMIT_EXCEEDED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn chỉ được đăng tối đa 2 video/tháng!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: _kNeoRed,
          ),
        );
      } else if (msg.contains('LIMIT_EXCEEDED')) {
        await showCameraPremiumUpsellDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'LỖI: $e',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: _kNeoRed,
          ),
        );
      }
    }
  }

  // ── Custom Camera UI builder ──────────────────────────────────────────────────
  Widget _buildCameraOverlay(CameraState state) {
    // Load sensors once
    if (_sensorDeviceData == null) {
      state.getSensors().then((data) {
        if (mounted) {
          setState(() => _sensorDeviceData = data);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Set correct aspect ratio on launch
              state.sensorConfig.setAspectRatio(
                _isVideoMode
                    ? CameraAspectRatios.ratio_16_9
                    : CameraAspectRatios.ratio_4_3,
              );
              // Fix orientation and set default sensor to wideAngle immediately on launch
              if (!_isFrontCamera && data.wideAngle != null) {
                state.setSensorType(
                  0,
                  SensorType.wideAngle,
                  data.wideAngle!.uid,
                );
              }
              state.sensorConfig.setZoom(0.0);
              state.sensorConfig.setBrightness(_brightnessValue);
            }
          });
        }
      });
    }

    final isFront =
        state.sensorConfig.sensors.first.position == SensorPosition.front;
    if (isFront != _isFrontCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isFrontCamera = isFront;
            _currentZoomLabel = 1.0; // reset zoom label on switch
          });
          state.sensorConfig.setAspectRatio(
            _isVideoMode
                ? CameraAspectRatios.ratio_16_9
                : CameraAspectRatios.ratio_4_3,
          );
          state.sensorConfig.setZoom(0.0);
          state.sensorConfig.setBrightness(_brightnessValue);
        }
      });
    }

    if (_needsLensReset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetRearLensIfNeeded(state);
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── TOP BAR CONSOLE CARD ──
        Positioned(
          top: -8,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: borderColor, width: 3),
              boxShadow: [
                BoxShadow(color: shadowColor, offset: const Offset(0, 4)),
              ],
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 28,
              bottom: 12,
              left: 20,
              right: 20,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NeoCircleBtn(
                  icon: CupertinoIcons.xmark,
                  bgColor: Colors.white,
                  onTap: () {
                    if (_localThumbnailPath != null) {
                      try {
                        File(_localThumbnailPath!).deleteSync();
                      } catch (_) {}
                    }
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildExposureSlider(state),
                  ),
                ),
                StreamBuilder<FlashMode>(
                  stream: state.sensorConfig.flashMode$,
                  initialData: state.sensorConfig.flashMode,
                  builder: (context, snapshot) {
                    final flashMode = snapshot.data ?? FlashMode.none;
                    IconData icon;
                    switch (flashMode) {
                      case FlashMode.none:
                        icon = Icons.flash_off_rounded;
                        break;
                      case FlashMode.on:
                        icon = Icons.flash_on_rounded;
                        break;
                      case FlashMode.auto:
                        icon = Icons.flash_auto_rounded;
                        break;
                      case FlashMode.always:
                        icon = Icons.flash_on_rounded;
                        break;
                    }
                    return _NeoCircleBtn(
                      icon: icon,
                      bgColor: _kNeoYellow,
                      onTap: () => state.sensorConfig.switchCameraFlash(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // ── BOTTOM CONSOLE PANEL (Full-width Neo bottom sheet contains Controls and Mode Toggle, Zoom presets float above it) ──
        Positioned(
          bottom: -28,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom presets (Floats above the card, outside of it!)
              _buildZoomPresets(state),
              const SizedBox(height: 4),

              // The Floating Neo Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: borderColor, width: 3),
                  boxShadow: [
                    BoxShadow(color: shadowColor, offset: const Offset(0, -4)),
                  ],
                ),
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Capture controls row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Gallery
                          _NeoCircleBtn(
                            icon: CupertinoIcons.photo,
                            bgColor: Colors.white,
                            onTap: _pickFromGallery,
                          ),

                          // Shutter
                          _buildCaptureButton(state),

                          // Flip Camera
                          _NeoCircleBtn(
                            icon: CupertinoIcons.arrow_2_circlepath,
                            bgColor: Colors.white,
                            onTap: () {
                              state.switchCameraSensor();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Mode Toggle (Ảnh / Video)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: borderColor, width: 3),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            offset: const Offset(4, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              if (_isVideoMode) {
                                await state.sensorConfig.setAspectRatio(
                                  CameraAspectRatios.ratio_4_3,
                                );
                                state.when(
                                  onVideoMode: (vs) =>
                                      vs.setState(CaptureMode.photo),
                                  onVideoRecordingMode: (_) {},
                                );
                                setState(() => _isVideoMode = false);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: !_isVideoMode
                                    ? _kNeoAccent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'ẢNH',
                                style: TextStyle(
                                  color: !_isVideoMode
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () async {
                              if (!_isVideoMode) {
                                await state.sensorConfig.setAspectRatio(
                                  CameraAspectRatios.ratio_16_9,
                                );
                                state.when(
                                  onPhotoMode: (ps) =>
                                      ps.setState(CaptureMode.video),
                                );
                                setState(() => _isVideoMode = true);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _isVideoMode
                                    ? _kNeoAccent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'VIDEO',
                                style: TextStyle(
                                  color: _isVideoMode
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Recording timer
        if (_isRecording)
          Positioned(
            top: MediaQuery.of(context).padding.top + 110,
            left: 0,
            right: 0,
            child: Center(child: _buildRecordingBadge()),
          ),
      ],
    );
  }

  Widget _buildZoomPresets(CameraState state) {
    // Cam sau: 0.5, 1, 2, 5 — Cam trước: 1, 2
    final labels = _isFrontCamera ? [1.0, 2.0] : [0.5, 1.0, 2.0, 5.0];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: labels.map((label) {
          final isActive = _currentZoomLabel == label;
          final labelStr = label == 1.0
              ? '1×'
              : label == 0.5
              ? '0.5×'
              : '${label.toInt()}×';
          return GestureDetector(
            onTap: () => _setZoomPreset(label, state),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                labelStr,
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  shadows: isActive
                      ? null
                      : const [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                            blurRadius: 3,
                          ),
                        ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExposureSlider(CameraState state) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.sun_max_fill,
            color: Colors.black,
            size: 22,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                activeTrackColor: _kNeoAccent,
                inactiveTrackColor: Colors.black12,
                thumbColor: _kNeoAccent,
              ),
              child: Slider(
                value: _brightnessValue,
                min: 0,
                max: 1,
                onChanged: (value) {
                  setState(() => _brightnessValue = value);
                  state.sensorConfig.setBrightness(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton(CameraState state) {
    if (_isRecording) {
      // Pulsing red stop button
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (_, __) => GestureDetector(
          onTap: () => _stopRecording(state),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(4, 4)),
              ],
            ),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _kNeoRed,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Normal capture button
    return GestureDetector(
      onTap: () {
        if (_isVideoMode) {
          _startRecording(state);
        } else {
          _takePicture(state);
        }
      },
      onLongPress: () {
        if (!_isVideoMode) _startRecording(state);
      },
      child: AnimatedBuilder(
        animation: _shutterController,
        builder: (_, __) => Transform.scale(
          scale: 1.0 - 0.08 * _shutterController.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(4, 4)),
              ],
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isVideoMode ? _kNeoRed : _kNeoYellow,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingBadge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _kNeoRed,
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(4, 4)),
          ],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: _pulseController.value,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '00:${_recordingSeconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // If media captured → show preview
    if (_capturedMedia != null) {
      return CameraPreviewView(
        isVideo: _isVideo,
        localThumbnailPath: _localThumbnailPath,
        isGeneratingThumbnail: _isGeneratingThumbnail,
        isFrontCamera: _isFrontCamera,
        capturedMedia: _capturedMedia,
        isMirrored: _isMirrored,
        webImageBytes: _webImageBytes,
        onToggleMirror: () {
          setState(() {
            _isMirrored = !_isMirrored;
          });
        },
        onRetake: () {
          if (_localThumbnailPath != null) {
            try {
              File(_localThumbnailPath!).deleteSync();
            } catch (_) {}
          }
          setState(() {
            _capturedMedia = null;
            _localThumbnailPath = null;
            _needsLensReset = true;
            _isMirrored = false;
            _webImageBytes = null;
          });
          if (kIsWeb && mounted) {
            _pickFromGallery().then((_) {
              if (_capturedMedia == null && mounted) {
                Navigator.pop(context);
              }
            });
          }
        },
        onPost: _uploadAndPost,
        onClose: () {
          if (_localThumbnailPath != null) {
            try {
              File(_localThumbnailPath!).deleteSync();
            } catch (_) {}
          }
          setState(() {
            _capturedMedia = null;
            _localThumbnailPath = null;
            _needsLensReset = true;
            _isMirrored = false;
            _webImageBytes = null;
          });
          if (kIsWeb && mounted) {
            Navigator.pop(context);
          }
        },
      );
    }

    if (kIsWeb) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepOrange),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraAwesomeBuilder.custom(
            saveConfig: SaveConfig.photoAndVideo(
              initialCaptureMode: _isVideoMode
                  ? CaptureMode.video
                  : CaptureMode.photo,
              mirrorFrontCamera:
                  true, // Natively mirror front camera photo and video
              videoOptions: VideoOptions(enableAudio: true, quality: VideoRecordingQuality.sd),
            ),
            sensorConfig: SensorConfig.single(
              sensor: Sensor.position(SensorPosition.back),
              flashMode: FlashMode.none,
              aspectRatio: _isVideoMode
                  ? CameraAspectRatios.ratio_16_9
                  : CameraAspectRatios.ratio_4_3,
              zoom: 0.0,
            ),
            previewFit: CameraPreviewFit
                .contain, // Show entire sensor viewport without cropping
            onPreviewTapBuilder: (state) => OnPreviewTap(
              onTap: (position, flutterPreviewSize, pixelPreviewSize) {
                _focusOnPreviewTap(
                  state,
                  position,
                  flutterPreviewSize,
                  pixelPreviewSize,
                );
              },
            ),
            onMediaCaptureEvent: _onMediaCaptureEvent,
            builder: (state, _) => _buildCameraOverlay(state),
          ),
          // Processing overlay removed for instant transition
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _NeoCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color bgColor;

  const _NeoCircleBtn({
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
        child: Icon(icon, color: Colors.black, size: 26),
      ),
    );
  }
}

class _NeoDialogButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final Color shadowColor;

  const _NeoDialogButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: shadowColor, offset: const Offset(4, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 10),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Beauty Filter Helper (Runs in isolate via compute) ──
Uint8List _applyBeautyFilterIsolate(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;

  // 1. Bake EXIF orientation to ensure consistent rotation
  final oriented = img.bakeOrientation(image);

  // 2. Resize immediately to feed-ready resolution (max 1440px) using high-quality average interpolation to smooth noise/grain
  img.Image resized;
  if (oriented.width > oriented.height) {
    resized = oriented.width > 1440
        ? img.copyResize(
            oriented,
            width: 1440,
            interpolation: img.Interpolation.average,
          )
        : oriented;
  } else {
    resized = oriented.height > 1440
        ? img.copyResize(
            oriented,
            height: 1440,
            interpolation: img.Interpolation.average,
          )
        : oriented;
  }

  // 3. Apply exact color matrix from preview (100% match) for bright, clear Locket style
  for (final pixel in resized) {
    pixel.r = (pixel.r * 1.00 + 18.0).round().clamp(0, 255);
    pixel.g = (pixel.g * 1.00 + 18.0).round().clamp(0, 255);
    pixel.b = (pixel.b * 1.10 + 40.0).round().clamp(0, 255);
  }

  return img.encodeJpg(resized, quality: 80);
}

// ── Mirror Filter Helper (Runs in isolate via compute) ──
Uint8List _applyMirrorIsolate(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;
  final flipped = img.copyFlip(image, direction: img.FlipDirection.horizontal);
  return img.encodeJpg(flipped, quality: 95);
}
