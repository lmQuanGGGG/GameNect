import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../../core/providers/moment_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui';
import 'package:logger/logger.dart';
import '../../../core/utils/video_thumbnail_helper.dart';
import 'dart:developer' as developer;
import '../../../core/services/firestore_service.dart';
import '../../widgets/glass_button.dart';
import 'camera_preview_view.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart' show PreviewSize, VideoOptions;
import 'camera_dialogs.dart';

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
        state.setSensorType(0, SensorType.ultraWideAngle, _sensorDeviceData!.ultraWideAngle!.uid);
      } else {
        // Cam trước (hoặc cam sau k có lens): góc rộng nhất là mức zoom 0.0
        await state.sensorConfig.setZoom(0.0);
      }
    } else if (label == 1.0) {
      if (!_isFrontCamera) {
        // Cam sau: về wide-angle chính nếu có
        if (_sensorDeviceData?.wideAngle != null) {
          state.setSensorType(0, SensorType.wideAngle, _sensorDeviceData!.wideAngle!.uid);
        }
        await state.sensorConfig.setZoom(0.0);
      } else {
        // Cam trước: 1× dùng nguyên bản phần cứng (không digital zoom, nét nhất)
        await state.sensorConfig.setZoom(0.0);
      }
    } else if (label == 2.0) {
      if (!_isFrontCamera && _sensorDeviceData?.telephoto != null) {
        state.setSensorType(0, SensorType.telephoto, _sensorDeviceData!.telephoto!.uid);
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
    state.when(
      onPhotoMode: (photoState) => photoState.takePhoto(),
    );
  }

  Future<void> _startRecording(CameraState state) async {
    await state.when(
      onVideoMode: (videoState) async {
        await videoState.startRecording();
        if (mounted) {
          setState(() {
            _isRecording = true;
            _recordingSeconds = 0;
          });
          _recordingTimer =
              Timer.periodic(const Duration(seconds: 1), (timer) {
            setState(() => _recordingSeconds++);
            if (_recordingSeconds >= 15) _stopRecording(state);
          });
        }
      },
    );
  }

  Future<void> _stopRecording(CameraState state) async {
    _recordingTimer?.cancel();
    await state.when(
      onVideoRecordingMode: (recState) async {
        await recState.stopRecording();
        if (mounted) {
          setState(() {
            _isRecording = false;
            _recordingSeconds = 0;
          });
        }
      },
    );
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
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Chọn loại file',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 20),
                      GlassButton(
                          icon: Icons.photo_rounded,
                          label: 'Ảnh',
                          onTap: () => Navigator.pop(ctx, 'image')),
                      const SizedBox(height: 12),
                      GlassButton(
                          icon: Icons.videocam_rounded,
                          label: 'Video (≤ 15s)',
                          onTap: () => Navigator.pop(ctx, 'video')),
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
        pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 800,
        );
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
          final vc =
              VideoPlayerController.file(File(pickedFile.path));
          await vc.initialize();
          final dur = vc.value.duration.inSeconds;
          await vc.dispose();
          if (dur > 15) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Video phải ngắn hơn hoặc bằng 15 giây!'),
                backgroundColor: Colors.red));
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

    try {
      final canPost = await FirestoreService().canPostMoment(userId);
      if (!canPost) {
        await showCameraPremiumUpsellDialog();
        return;
      }
    } catch (e) {
      developer.log('Check limit error: $e', name: 'Camera');
    }

    final caption = await showCameraCaptionDialog();
    if (caption == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
    );

    try {
      String? mediaUrl;
      String? thumbnailUrl;

      if (kIsWeb) {
        // === WEB: dùng putData(bytes) thay vì putFile(File) ===
        final bytes = await _capturedMedia!.readAsBytes();
        if (_isVideo) {
          final ref = FirebaseStorage.instance
              .ref()
              .child('moments/$userId/video_${DateTime.now().millisecondsSinceEpoch}.mp4');
          await ref.putData(bytes, SettableMetadata(contentType: 'video/mp4'));
          mediaUrl = await ref.getDownloadURL();
          // Thumbnail cho video web: dùng placeholder vì video_thumbnail không chạy trên web
          thumbnailUrl = null;
        } else {
          final imageRef = FirebaseStorage.instance
              .ref()
              .child('moments/$userId/image_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await imageRef.putData(bytes, SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'quality': 'high'}));
          mediaUrl = await imageRef.getDownloadURL();
        }
      } else {
        // === MOBILE: dùng putFile như cũ ===
        if (_isVideo) {
          final ref = FirebaseStorage.instance
              .ref()
              .child('moments/$userId/video_${DateTime.now().millisecondsSinceEpoch}.mp4');
          await ref.putFile(File(_capturedMedia!.path));
          mediaUrl = await ref.getDownloadURL();

          if (_localThumbnailPath != null) {
            final thumbRef = FirebaseStorage.instance
                .ref()
                .child('moments/$userId/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await thumbRef.putFile(File(_localThumbnailPath!));
            thumbnailUrl = await thumbRef.getDownloadURL();
          }
        } else {
          final imageRef = FirebaseStorage.instance
              .ref()
              .child('moments/$userId/image_${DateTime.now().millisecondsSinceEpoch}.jpg');
          final metadata = SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'quality': 'high'});
          await imageRef.putFile(File(_capturedMedia!.path), metadata);
          mediaUrl = await imageRef.getDownloadURL();
        }
      }

      if (!mounted) return;
      final mp = Provider.of<MomentProvider>(context, listen: false);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã đăng khoảnh khắc!'),
          backgroundColor: Colors.green));
    } catch (e) {
      developer.log('Upload error: $e', name: 'Camera', error: e);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final msg = e.toString();
      if (msg.contains('LIMIT_EXCEEDED')) {
        await showCameraPremiumUpsellDialog();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }


  // ── Custom Camera UI builder ──────────────────────────────────────────────────
  Widget _buildCameraOverlay(CameraState state) {
    // Load sensors once
    if (_sensorDeviceData == null) {
      state.getSensors().then((data) {
        if (mounted) setState(() => _sensorDeviceData = data);
      });
    }

    final isFront = state.sensorConfig.sensors.first.position ==
        SensorPosition.front;
    if (isFront != _isFrontCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isFrontCamera = isFront;
            _currentZoomLabel = 1.0; // reset zoom label on switch
          });
          // Set zoom 0.0 và giữ nguyên độ sáng tự nhiên cho cả 2 cam
          if (isFront) {
            state.sensorConfig.setZoom(0.0);
          } else {
            state.sensorConfig.setZoom(0.0);
          }
          state.sensorConfig.setBrightness(_brightnessValue);
        }
      });
    }

    if (_needsLensReset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetRearLensIfNeeded(state);
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Top bar ────────────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close
                _GlassCircleBtn(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                // Recording timer (center)
                if (_isRecording) _buildRecordingBadge(),

                // Flash button
                StreamBuilder<FlashMode>(
                  stream: state.sensorConfig.flashMode$,
                  builder: (_, snap) {
                    final flash = snap.data ?? FlashMode.none;
                    return _GlassCircleBtn(
                      icon: _flashIcon(flash),
                      onTap: () => state.sensorConfig.switchCameraFlash(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // ── Bottom bar ─────────────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 20,
              right: 20,
              top: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.70),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Zoom presets ───────────────────────────────────────────────
                _buildZoomPresets(state),
                const SizedBox(height: 14),
                _buildExposureSlider(state),
                const SizedBox(height: 24),

                // ── Main action row ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery
                    _GlassCircleBtn(
                      icon: Icons.photo_library_rounded,
                      size: 50,
                      onTap: _pickFromGallery,
                    ),

                    // Capture button
                    _buildCaptureButton(state),

                    // Flip camera
                    _GlassCircleBtn(
                      icon: Icons.flip_camera_ios_rounded,
                      size: 50,
                      onTap: () {
                        state.switchCameraSensor();
                        setState(() {
                          _currentZoomLabel = 1.0;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Photo / Video mode toggle ──────────────────────────────────
                _buildModeToggle(state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoomPresets(CameraState state) {
    // Cam sau: 0.5, 1, 2, 5 — Cam trước: 1, 2
    final labels = _isFrontCamera
        ? [1.0, 2.0]
        : [0.5, 1.0, 2.0, 5.0];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.12), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: labels.map((label) {
              final isActive = _currentZoomLabel == label;
              final labelStr =
                  label == 1.0 ? '1×' : label == 0.5 ? '0.5×' : '${label.toInt()}×';
              return GestureDetector(
                onTap: () => _setZoomPreset(label, state),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(3),
                  width: isActive ? 48 : 36,
                  height: isActive ? 36 : 28,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      labelStr,
                      style: TextStyle(
                        color: isActive
                            ? Colors.black
                            : Colors.white.withValues(alpha: 0.9),
                        fontSize: isActive ? 12 : 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(CameraState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModeBtn(
          label: 'Ảnh',
          isActive: !_isVideoMode,
          onTap: () {
            if (_isVideoMode) {
              state.when(
                onVideoMode: (vs) => vs.setState(CaptureMode.photo),
                onVideoRecordingMode: (_) {},
              );
              setState(() => _isVideoMode = false);
            }
          },
        ),
        const SizedBox(width: 6),
        _ModeBtn(
          label: 'Video',
          isActive: _isVideoMode,
          onTap: () {
            if (!_isVideoMode) {
              state.when(
                onPhotoMode: (ps) => ps.setState(CaptureMode.video),
              );
              setState(() => _isVideoMode = true);
            }
          },
        ),
      ],
    );
  }

  Widget _buildExposureSlider(CameraState state) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.wb_sunny_rounded,
                color: Colors.white,
                size: 18,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
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
        ),
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.red
                      .withValues(alpha: 0.5 + 0.3 * _pulseController.value),
                  blurRadius: 20 + 10 * _pulseController.value,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
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
          scale: 1.0 - 0.06 * _shutterController.value,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12, width: 2.5),
                  color: _isVideoMode ? Colors.red : Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withValues(
              alpha: 0.7 + 0.25 * _pulseController.value),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white)),
            const SizedBox(width: 6),
            Text(
              '${_recordingSeconds}s',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  IconData _flashIcon(FlashMode mode) {
    return switch (mode) {
      FlashMode.on => Icons.flash_on_rounded,
      FlashMode.auto => Icons.flash_auto_rounded,
      FlashMode.always => Icons.flashlight_on_rounded,
      FlashMode.none => Icons.flash_off_rounded,
    };
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
        body: Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraAwesomeBuilder.custom(
        saveConfig: SaveConfig.photoAndVideo(
          initialCaptureMode: CaptureMode.photo,
          mirrorFrontCamera: false,
          videoOptions: VideoOptions(enableAudio: true),
        ),
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(SensorPosition.back),
          flashMode: FlashMode.none,
          // ratio_4_3 in portrait = 3:4 visual frame
          aspectRatio: CameraAspectRatios.ratio_4_3,
          zoom: 0.0,
        ),
        // contain = preview fills the 3:4 area without cropping
        previewFit: CameraPreviewFit.contain,
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
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _GlassCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _GlassCircleBtn({
    required this.icon,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.48),
          ),
        ),
      ),
    );
  }
}


class _ModeBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.55),
            fontSize: 14,
            fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
