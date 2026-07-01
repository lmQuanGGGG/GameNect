import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../../../core/providers/moment_provider.dart';
import '../../../core/services/camera_preload_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/video_thumbnail_helper.dart';
import 'camera_preview_view.dart';
import 'camera_dialogs.dart';

const _kNeoAccent = Color(0xFFFF6E40);
const _kNeoRed = Color(0xFFFF2D55);
const _kNeoYellow = Color(0xFFFFD54F);

class WebRTCCameraScreen extends StatefulWidget {
  const WebRTCCameraScreen({super.key});

  @override
  State<WebRTCCameraScreen> createState() => _WebRTCCameraScreenState();
}

class _WebRTCCameraScreenState extends State<WebRTCCameraScreen>
    with CameraDialogsMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  int _currentCameraIndex = 0;

  XFile? _capturedMedia;
  Uint8List? _webImageBytes;
  bool _isUploading = false;
  bool _isProcessing = false;

  bool _userWantsMirror = false; // Trạng thái gương thực sự
  bool _isFilterEnabled = true; // Trạng thái bật tắt Locket filter
  bool get _isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;

  bool get _shouldTransformPreview {
    if (kIsWeb) {
      // Web luôn là raw video, không tự lật -> lật theo ý user
      return _userWantsMirror;
    } else {
      if (_isFrontCamera) {
        // Mobile cam trước đã TỰ LẬT GƯƠNG sẵn từ OS.
        // Nên nếu user muốn gương -> KHÔNG lật thêm (để giữ nguyên gương của OS).
        // Nếu user KHÔNG muốn gương -> LẬT (để huỷ cái gương của OS).
        return !_userWantsMirror;
      } else {
        // Mobile cam sau mặc định là KHÔNG GƯƠNG.
        return _userWantsMirror;
      }
    }
  }
  bool _isUltraWide = false;
  bool _isFlashOn = false;
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _baseZoomLevel = 1.0;

  bool _isVideo = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _localThumbnailPath;
  bool _isGeneratingThumbnail = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      // ưu tiên lấy controller đã preload sẵn
      final preloaded = await CameraPreloadService.instance.claim();
      if (preloaded != null && preloaded.value.isInitialized) {
        _cameras = CameraPreloadService.instance.cameras.isNotEmpty
            ? CameraPreloadService.instance.cameras
            : await availableCameras();

        // Tìm index của camera hiện tại trong danh sách
        final desc = preloaded.description;
        _currentCameraIndex = _cameras.indexWhere((c) => c.name == desc.name);
        if (_currentCameraIndex == -1) _currentCameraIndex = 0;

        _controller = preloaded;

        try {
          _minAvailableZoom = await _controller!.getMinZoomLevel();
          _maxAvailableZoom = await _controller!.getMaxZoomLevel();
        } catch (_) {}

        if (mounted) setState(() => _isInitializing = false);
        return;
      }

      // Fallback: khởi động bình thường nếu chưa preload xong
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _isInitializing = false);
        return;
      }

      int targetIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (targetIndex == -1) targetIndex = 0;

      _currentCameraIndex = targetIndex;
      await _startCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      debugPrint('Camera Init Error: $e');
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _userWantsMirror = kIsWeb ? false : _isFrontCamera; // Tự động bật gương cho cam trước trên App, Web thì tắt
        });
      }

      try {
        _minAvailableZoom = await _controller!.getMinZoomLevel();
        _maxAvailableZoom = await _controller!.getMaxZoomLevel();
      } catch (e) {
        debugPrint('Lỗi lấy thông số Zoom: $e');
      }
    } catch (e) {
      debugPrint('Start Camera Error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.isEmpty) return;

    // Xác định hướng hiện tại
    final currentDirection = _cameras[_currentCameraIndex].lensDirection;

    // Chỉ tìm cam CHÍNH (cam đầu tiên) của hướng đối diện
    // Hướng đối diện: front <-> back
    final targetDirection = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    final targetIndex = _cameras.indexWhere(
      (c) => c.lensDirection == targetDirection,
    );

    if (targetIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy camera đối diện'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isInitializing = true;
      _isUltraWide = false; // Reset về 1x khi đổi trước/sau
    });
    _currentCameraIndex = targetIndex;
    await _startCamera(_cameras[_currentCameraIndex]);
  }

  Future<void> _toggleUltraWide(bool wantUltraWide) async {
    if (_isUltraWide == wantUltraWide) return;
    if (_cameras.isEmpty) return;

    CameraLensDirection currentDirection =
        _cameras[_currentCameraIndex].lensDirection;

    // Tìm tất cả các cam có cùng hướng (trước hoặc sau)
    List<int> sameDirectionIndices = [];
    for (int i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == currentDirection) {
        sameDirectionIndices.add(i);
      }
    }

    if (sameDirectionIndices.length > 1) {
      setState(() {
        _isUltraWide = wantUltraWide;
        _isInitializing = true;
      });

      // Cam sau: index[0]=normal, index[1]=ultrawide
      // Cam trước: thứ tự ngược lại nên cần đảo
      final isFront = currentDirection == CameraLensDirection.front;
      int normalIdx = isFront
          ? sameDirectionIndices[1]
          : sameDirectionIndices[0];
      int ultraIdx = isFront
          ? sameDirectionIndices[0]
          : sameDirectionIndices[1];

      _currentCameraIndex = wantUltraWide ? ultraIdx : normalIdx;
      await _startCamera(_cameras[_currentCameraIndex]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không nhận diện được cam 0.5x của máy này'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Chọn ảnh từ thư mục (web + native)
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickMedia(imageQuality: 95);
    if (picked != null && mounted) {
      final path = picked.path.toLowerCase();
      final isVideo =
          path.endsWith('.mp4') ||
          path.endsWith('.mov') ||
          path.endsWith('.avi');
      setState(() {
        _capturedMedia = picked;
        _isVideo = isVideo;
      });
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      // 1. Chụp phát ăn ngay
      final XFile file = await _controller!.takePicture();

      // Tạm dừng camera trên web/Safari rất dễ gây lỗi đơ stream, chỉ pause trên App
      if (!kIsWeb) {
        try {
          await _controller!.pausePreview();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _capturedMedia = file;
          _isVideo = false;
        });
      }
    } catch (e) {
      debugPrint('Take Picture Error: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo) return;
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _isVideo = true;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_recordingSeconds >= 4) {
          // Tới giây 5 là cắt
          _stopRecording();
        } else {
          setState(() => _recordingSeconds++);
        }
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    if (!_isRecording) return;

    setState(() => _isRecording = false);
    try {
      final XFile file = await _controller!.stopVideoRecording();
      setState(() {
        _capturedMedia = file;
        _isVideo = true;
      });

      if (!kIsWeb) {
        setState(() => _isGeneratingThumbnail = true);
        try {
          final path = await VideoThumbnailHelper.generateThumbnail(file.path);
          if (mounted) {
            setState(() {
              _localThumbnailPath = path;
            });
          }
        } catch (e) {
          debugPrint('Lỗi tạo thumbnail: $e');
        } finally {
          if (mounted) setState(() => _isGeneratingThumbnail = false);
        }
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      if (_isFlashOn) {
        setState(() => _isFlashOn = false);
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        setState(() => _isFlashOn = true);
        await _controller!.setFlashMode(FlashMode.always);
      }
    } catch (e) {
      // Bỏ qua lỗi hiển thị nếu nó thực sự đã bật
      debugPrint('Set flash mode error: $e');
    }
  }

  Future<void> _uploadAndPost() async {
    if (_capturedMedia == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final mp = Provider.of<MomentProvider>(context, listen: false);

    try {
      final canPost = await mp.canPostMoment(userId: userId, isVideo: _isVideo);
      if (!canPost) {
        if (!mounted) return;
        await showCameraPremiumUpsellDialog();
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi kiểm tra giới hạn!'),
          backgroundColor: _kNeoRed,
        ),
      );
      return;
    }

    final caption = await showCameraCaptionDialog();
    if (caption == null) return;

    if (!mounted) return;
    setState(() => _isUploading = true);

    try {
      String mediaUrl = '';
      String? thumbnailUrl;
      if (_isVideo) {
        // Xử lý Upload Video
        if (_localThumbnailPath != null) {
          thumbnailUrl = await VideoThumbnailHelper.uploadThumbnail(
            _localThumbnailPath!,
            userId,
          );
        }

        final videoBytes = await _capturedMedia!.readAsBytes();
        final videoRef = FirebaseStorage.instance.ref().child(
          'moments/$userId/video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        await videoRef.putData(
          videoBytes,
          SettableMetadata(
            contentType: 'video/mp4',
            cacheControl: 'public, max-age=31536000',
          ),
        );
        mediaUrl = await videoRef.getDownloadURL();
      } else {
        // Xử lý Upload Ảnh với Isolate
        final rawBytes = await _capturedMedia!.readAsBytes();
        final finalBytes = await compute(_processImageIsolate, {
          'bytes': rawBytes,
          'isMirrored': _userWantsMirror,
          'isFilterEnabled': _isFilterEnabled,
        });

        final imageRef = FirebaseStorage.instance.ref().child(
          'moments/$userId/image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        await imageRef.putData(
          finalBytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'public, max-age=31536000',
          ),
        );

        mediaUrl = await imageRef.getDownloadURL();
      }

      if (!mounted) return;
      final matchedIds = await mp.getMatchedUserIds(userId);

      await mp.postMoment(
        userId: userId,
        mediaUrl: mediaUrl,
        isVideo: _isVideo,
        matchIds: matchedIds,
        caption: caption.isEmpty ? null : caption,
        thumbnailUrl: _isVideo ? thumbnailUrl : null,
        isMirrored: _userWantsMirror,
      );

      // Tắt luôn camera controller vì đã upload xong, tránh chạy ngầm
      _controller?.dispose();
      _controller = null;

      if (!mounted) return;

      // Không gọi rootNavigator.pop() vì _isUploading dùng setState chứ không dùng dialog
      Navigator.of(
        context,
      ).pop(true); // Đóng màn hình Camera và trả về true để refresh feed

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ĐÃ ĐĂNG BẰNG WEBRTC!',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('LỖI: $e'), backgroundColor: _kNeoRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepOrange),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── LỚP 1: CAMERA LIVE (Luôn nằm dưới cùng để tránh bị unmount gây lỗi đen màn hình web) ──
          if (_isInitializing)
            const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            )
          else if (_controller != null && _controller!.value.isInitialized)
            GestureDetector(
              onScaleStart: (details) {
                _baseZoomLevel = _currentZoomLevel;
              },
              onScaleUpdate: (details) async {
                if (_controller == null || !_controller!.value.isInitialized)
                  return;
                double newZoom = (_baseZoomLevel * details.scale).clamp(
                  _minAvailableZoom,
                  _maxAvailableZoom,
                );
                if (newZoom != _currentZoomLevel) {
                  setState(() => _currentZoomLevel = newZoom);
                  try {
                    await _controller!.setZoomLevel(_currentZoomLevel);
                  } catch (e) {
                    // Trình duyệt web có thể không hỗ trợ setZoomLevel trên camera
                  }
                }
              },
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 80,
                  bottom: 190, // Chừa 190px để né hoàn toàn dàn nút ở đáy
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.black, width: 4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: kIsWeb
                                  ? (_controller!.value.previewSize?.width ?? 1)
                                  : (_controller!.value.previewSize?.height ?? 1),
                              height: kIsWeb
                                  ? (_controller!.value.previewSize?.height ?? 1)
                                  : (_controller!.value.previewSize?.width ?? 1),
                              child: Transform(
                                alignment: Alignment.center,
                                transform: _shouldTransformPreview
                                    ? Matrix4.rotationY(math.pi)
                                    : Matrix4.identity(),
                                child: _isFilterEnabled
                                    ? ColorFiltered(
                                        colorFilter: const ColorFilter.matrix([
                                          1.12, 0.0, 0.0, 0.0, 5.0,
                                          0.0, 1.12, 0.0, 0.0, 5.0,
                                          0.0, 0.0, 1.18, 0.0, 15.0,
                                          0.0, 0.0, 0.0, 1.0, 0.0,
                                        ]),
                                        child: CameraPreview(_controller!),
                                      )
                                    : CameraPreview(_controller!),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const Center(
              child: Text(
                'Không tìm thấy Camera WebRTC',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // ── LỚP 2: NÚT BẤM CAMERA LIVE (Chỉ hiện khi chưa chụp) ──
          if (_capturedMedia == null) ...[
            // Top Right: Mirror Toggle & Filter Toggle
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _userWantsMirror = !_userWantsMirror;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _userWantsMirror ? _kNeoYellow : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                        ],
                      ),
                      child: const Icon(Icons.flip_rounded, color: Colors.black),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isFilterEnabled = !_isFilterEnabled;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isFilterEnabled ? _kNeoYellow : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                          ],
                        ),
                        child: Icon(
                          _isFilterEnabled ? Icons.auto_awesome_rounded : Icons.auto_awesome_outlined,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── LỰA CHỌN ZOOM 0.5x / 1x ──
            if (_controller != null && _controller!.value.isInitialized)
              Positioned(
                bottom: 140,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildZoomButton(
                      '0.5x',
                      _isUltraWide,
                      () => _toggleUltraWide(true),
                    ),
                    const SizedBox(width: 20),
                    _buildZoomButton(
                      '1x',
                      !_isUltraWide,
                      () => _toggleUltraWide(false),
                    ),
                  ],
                ),
              ),

            // ── BOTTOM BAR: X | CHỤP | ĐỔI CAM ──
            if (_controller != null && _controller!.value.isInitialized)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // X và Flash - trái
                      Positioned(
                        left: 20,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(3, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  CupertinoIcons.xmark,
                                  color: Colors.black,
                                  size: 22,
                                ),
                              ),
                            ),
                            if (!kIsWeb) const SizedBox(width: 10),
                            if (!kIsWeb)
                              GestureDetector(
                                onTap: _toggleFlash,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black,
                                        offset: Offset(3, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isFlashOn
                                        ? Icons.flash_on_rounded
                                        : Icons.flash_off_rounded,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Nút chụp / quay - chính giữa
                      GestureDetector(
                        onTap: () {
                          if (!_isRecording) _takePicture();
                        },
                        onLongPressStart: (_) => _startRecording(),
                        onLongPressEnd: (_) => _stopRecording(),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.black, width: 4),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(4, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: _isRecording ? 48 : 64,
                              height: _isRecording ? 48 : 64,
                              decoration: BoxDecoration(
                                shape: _isRecording
                                    ? BoxShape.rectangle
                                    : BoxShape.circle,
                                borderRadius: _isRecording
                                    ? BorderRadius.circular(8)
                                    : null,
                                color: _isRecording ? _kNeoRed : _kNeoYellow,
                              ),
                              child: _isRecording
                                  ? Center(
                                      child: Text(
                                        '${5 - _recordingSeconds}s',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),

                      // Folder + Đổi cam - phải
                      Positioned(
                        right: 20,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _pickFromGallery,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(3, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.black,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _switchCamera,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(3, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.cameraswitch_rounded,
                                  color: Colors.black,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          // ── LỚP 3: PREVIEW KẾT QUẢ (Nằm đè lên trên Live Camera) ──
          if (_capturedMedia != null)
            Positioned.fill(
              child: Container(
                color: Colors.white, // Che hoàn toàn Live Camera ở dưới
                child: CameraPreviewView(
                  isVideo: _isVideo,
                  isGeneratingThumbnail: _isGeneratingThumbnail,
                  localThumbnailPath: _localThumbnailPath,
                  isFrontCamera:
                      _isFrontCamera, // Không quan trọng lắm vì WebRTC tự scale
                  capturedMedia: _capturedMedia,
                  isMirrored: _userWantsMirror,
                  isFilterEnabled: _isFilterEnabled,
                  onToggleMirror: () {
                    setState(() {
                      _userWantsMirror = !_userWantsMirror;
                    });
                  },
                  onToggleFilter: () {
                    setState(() {
                      _isFilterEnabled = !_isFilterEnabled;
                    });
                  },
                  onRetake: () {
                    setState(() {
                      _capturedMedia = null;
                    });
                    // Resume camera sau khi tắt preview
                    try {
                      _controller?.resumePreview();
                    } catch (_) {}
                  },
                  onPost: _uploadAndPost,
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildZoomButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.black,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.white,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3)),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Process Image Isolate ──
Uint8List _processImageIsolate(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final isMirrored = args['isMirrored'] as bool;
  final isFilterEnabled = args['isFilterEnabled'] as bool? ?? true;

  final image = img.decodeImage(bytes);
  if (image == null) return bytes;

  var processed = image;

  // Lật ngang ảnh nếu user đang bật chế độ gương
  if (isMirrored) {
    processed = img.flipHorizontal(processed);
  }

  // Resize ảnh nếu quá lớn (Max width 1080px)
  if (processed.width > 1080) {
    processed = img.copyResize(
      processed,
      width: 1080,
      interpolation: img.Interpolation.linear,
    );
  }

  // Crop trung tâm theo tỉ lệ 3:4
  final targetW = processed.width;
  final targetH = (processed.width * 4 / 3).round();
  if (processed.height > targetH) {
    final cropY = ((processed.height - targetH) / 2).round();
    processed = img.copyCrop(
      processed,
      x: 0,
      y: cropY,
      width: targetW,
      height: targetH,
    );
  } else if (processed.height < targetH) {
    // Nếu ảnh thấp hơn tỉ lệ 3:4, crop theo chiều ngang
    final targetW2 = (processed.height * 3 / 4).round();
    final cropX = ((processed.width - targetW2) / 2).round();
    processed = img.copyCrop(
      processed,
      x: cropX,
      y: 0,
      width: targetW2,
      height: processed.height,
    );
  }

  // Bộ lọc chuẩn Locket trước khi lưu
  if (isFilterEnabled) {
    for (final pixel in processed) {
      num r = pixel.r;
      num g = pixel.g;
      num b = pixel.b;

      // Tăng tương phản (+12%) và Bơm độ sáng toàn cục (+5) để ảnh rực rỡ hơn
      r = (r * 1.12 + 5).clamp(0, 255);
      g = (g * 1.12 + 5).clamp(0, 255);

      // Tăng thêm Blue (+18%, +15 sáng) để da dẻ trong trẻo, trắng sáng, khử vàng triệt để
      b = (b * 1.18 + 15).clamp(0, 255);

      pixel.r = r;
      pixel.g = g;
      pixel.b = b;
    }
  }

  // Lưu JPEG ở chất lượng 85 (Chuẩn Locket) để cân bằng giữa dung lượng và độ sắc nét
  return img.encodeJpg(processed, quality: 85);
}
