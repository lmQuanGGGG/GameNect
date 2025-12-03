import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import '../../core/providers/moment_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:logger/logger.dart';
import 'package:image/image.dart' as img;
import '../../core/utils/video_thumbnail_helper.dart';
import 'dart:developer' as developer;
import '../../core/services/firestore_service.dart';
import 'subscription_screen.dart';

import '../widgets/glass_icon_button.dart';
import '../widgets/zoom_preset_button.dart';
import '../widgets/recording_indicator.dart';
import '../widgets/glass_button.dart';
import '../widgets/preview_button.dart';

// Màn hình camera để chụp ảnh và quay video cho tính năng Moment
// Tương tự Instagram Stories: tap nhanh = chụp ảnh, giữ lâu = quay video
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with TickerProviderStateMixin {
  CameraController? _controller; // Quản lý camera
  List<CameraDescription>? _cameras; // Danh sách camera có sẵn
  bool _isInitialized = false; // Kiểm tra camera đã sẵn sàng chưa
  bool _isRecording = false; // Đang quay video hay không
  bool _isFrontCamera = true; // Đang dùng camera trước hay sau
  int _recordingSeconds = 0; // Số giây đã quay
  Timer? _recordingTimer; // Timer đếm giây khi quay video
  XFile? _capturedMedia; // File ảnh/video vừa chụp
  bool _isVideo = false; // File vừa chụp là video hay ảnh
  bool _isFlashOn = false; // Đèn flash có đang bật không
  double _exposure = 0.0; // Độ sáng (-2.0 đến 2.0)
  double _currentZoom = 1.0; // Mức zoom hiện tại
  double _minZoom = 1.0; // Zoom tối thiểu camera hỗ trợ
  double _maxZoom = 1.0; // Zoom tối đa camera hỗ trợ
  final ImagePicker _picker = ImagePicker(); // Để chọn ảnh/video từ thư viện
  VideoPlayerController? _videoController; // Play video preview

  // Các biến để xử lý tap màn hình = focus camera
  Offset? _focusPoint; // Vị trí tap để focus
  bool _showFocusCircle = false; // Hiện vòng tròn focus hay không
  AnimationController?
  _focusAnimationController; // Animation cho vòng tròn focus

  // Biến cho tính năng pinch to zoom
  double _baseScale = 1.0; // Lưu zoom ban đầu khi bắt đầu pinch

  // Biến để hiển thị thanh điều chỉnh độ sáng
  bool _showExposureSlider = false;
  Offset? _exposureSliderPosition;

  // Giả lập flash cho camera trước (overlay trắng)
  bool _showFrontFlashOverlay = false;

  // Thumbnail cho video (để preview không cần load video)
  String? _localThumbnailPath;
  bool _isGeneratingThumbnail = false;

  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    // Setup animation controller cho vòng tròn focus
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _initializeCamera();
  }

  // Khởi động camera khi mở màn hình
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      // Mặc định dùng camera sau trước
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.veryHigh, // Dùng quality cao nhất
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg, // Format JPEG cho ảnh đẹp
      );

      _isFrontCamera = false;
      await _controller!.initialize();
      // Khóa màn hình chỉ dọc
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      // Lấy giới hạn zoom của camera
      _maxZoom = await _controller!.getMaxZoomLevel();
      _minZoom = await _controller!.getMinZoomLevel();
      _currentZoom = _minZoom;

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      _logger.e('Camera init error: $e');
    }
  }

  // Đổi camera trước/sau
  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isInitialized = false;
    });

    final newCamera = _cameras!.firstWhere(
      (camera) =>
          camera.lensDirection ==
          (_isFrontCamera
              ? CameraLensDirection.front
              : CameraLensDirection.back),
      orElse: () => _cameras!.first,
    );

    await _controller?.dispose();
    _controller = CameraController(
      newCamera,
      ResolutionPreset.veryHigh, // Quality cao
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    _maxZoom = await _controller!.getMaxZoomLevel();
    _minZoom = await _controller!.getMinZoomLevel();
    _currentZoom = _minZoom;

    // Camera trước không có flash thật
    if (_isFrontCamera) {
      _isFlashOn = false;
      await _controller!.setFlashMode(FlashMode.off);
    }

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  // Tap màn hình để focus và set exposure point
  Future<void> _handleTapToFocus(TapDownDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final Size size = box.size;

    // Chuyển tọa độ pixel thành % (0-1) cho camera API
    final dx = localPosition.dx / size.width;
    final dy = localPosition.dy / size.height;

    setState(() {
      _focusPoint = localPosition;
      _showFocusCircle = true;
      _showExposureSlider = true;
      _exposureSliderPosition = localPosition;
    });

    _focusAnimationController?.forward(from: 0);

    try {
      await _controller!.setFocusPoint(Offset(dx, dy));
      await _controller!.setExposurePoint(Offset(dx, dy));
    } catch (e) {
      _logger.e('Focus error: $e');
    }

    // Tự động ẩn sau 3 giây
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showFocusCircle = false;
          _showExposureSlider = false;
        });
      }
    });
  }

  // Pinch to zoom - giai đoạn bắt đầu
  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentZoom;
  }

  // Pinch to zoom - đang zoom
  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    if (_controller == null) return;

    final newZoom = (_baseScale * details.scale).clamp(_minZoom, _maxZoom);

    // Chỉ update khi thay đổi đủ lớn (tránh lag)
    if ((newZoom - _currentZoom).abs() > 0.01) {
      _currentZoom = newZoom;
      await _controller!.setZoomLevel(_currentZoom);
      setState(() {});
    }
  }

  // Zoom theo nút preset (1x, 2x, 3x)
  Future<void> _setZoomPreset(double zoom) async {
    if (_controller == null) return;

    final targetZoom = zoom.clamp(_minZoom, _maxZoom);
    _currentZoom = targetZoom;
    await _controller!.setZoomLevel(_currentZoom);
    setState(() {});
  }

  // Chụp ảnh
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // Giả lập flash cho camera trước
    if (_isFrontCamera && _isFlashOn) {
      setState(() => _showFrontFlashOverlay = true);
      await Future.delayed(const Duration(milliseconds: 350));
    }

    try {
      final image = await _controller!.takePicture();
      setState(() {
        _capturedMedia = image;
        _isVideo = false;
        _showFrontFlashOverlay = false;
      });
    } catch (e) {
      setState(() => _showFrontFlashOverlay = false);
      _logger.e('Take picture error: $e');
    }
  }

  // Bắt đầu quay video
  Future<void> _startRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isRecording)
      return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      // Timer đếm giây, tự động dừng sau 15 giây
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordingSeconds++);
        if (_recordingSeconds >= 15) {
          _stopRecording();
        }
      });
    } catch (e) {
      _logger.e('Start recording error: $e');
    }
  }

  // Dừng quay video
  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;

    try {
      _recordingTimer?.cancel();
      final video = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _capturedMedia = video;
        _isVideo = true;
        _recordingSeconds = 0;
      });

      // Tạo thumbnail để preview
      await _generateThumbnail(video.path);
    } catch (e) {
      _logger.e('Stop recording error: $e');
    }
  }

  // Tạo thumbnail từ video
  Future<void> _generateThumbnail(String videoPath) async {
    setState(() => _isGeneratingThumbnail = true);

    try {
      final thumbnailPath = await VideoThumbnailHelper.generateThumbnail(
        videoPath,
      );
      if (mounted && thumbnailPath != null) {
        setState(() {
          _localThumbnailPath = thumbnailPath;
          _isGeneratingThumbnail = false;
        });
      }
    } catch (e) {
      _logger.e('Error generating thumbnail: $e');
      if (mounted) {
        setState(() => _isGeneratingThumbnail = false);
      }
    }
  }

  // Chọn ảnh/video từ thư viện
  Future<void> _pickFromGallery() async {
    try {
      // Hỏi user muốn chọn ảnh hay video
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
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Chọn loại file',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildGlassButton(
                        icon: Icons.photo_rounded,
                        label: 'Ảnh',
                        onTap: () => Navigator.pop(ctx, 'image'),
                      ),
                      const SizedBox(height: 12),
                      _buildGlassButton(
                        icon: Icons.videocam_rounded,
                        label: 'Video (≤ 15s)',
                        onTap: () => Navigator.pop(ctx, 'video'),
                      ),
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
          // Kiểm tra video không quá 15 giây
          final videoController = VideoPlayerController.file(
            File(pickedFile.path),
          );
          await videoController.initialize();
          final duration = videoController.value.duration.inSeconds;
          await videoController.dispose();

          if (duration > 15) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video phải ngắn hơn hoặc bằng 15 giây!'),
                  backgroundColor: Colors.red,
                ),
              );
            }
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

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GlassIconButton(icon: icon, onPressed: onPressed);
  }

  Widget _buildZoomPreset(String label, double zoom) {
    return ZoomPresetButton(
      label: label,
      zoom: zoom,
      currentZoom: _currentZoom,
      onZoomChanged: _setZoomPreset,
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GlassButton(icon: icon, label: label, onTap: onTap);
  }

  Widget _buildPreviewButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return PreviewButton(
      icon: icon,
      label: label,
      onPressed: onPressed,
      isPrimary: isPrimary,
    );
  }

  // Lật ảnh nếu chụp từ camera trước với quality 100%
  Future<XFile> _flipImageIfFrontCamera(XFile file) async {
    if (!_isFrontCamera) return file;

    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return file;

      final flipped = img.flipHorizontal(image);

      // Lưu với quality 100% để giữ nguyên chất lượng
      final newPath = file.path.replaceFirst('.jpg', '_flipped.jpg');
      final newFile = File(newPath)
        ..writeAsBytesSync(
          img.encodeJpg(flipped, quality: 100), // Quality tối đa
        );

      return XFile(newFile.path);
    } catch (e) {
      _logger.e('Flip image error: $e');
      return file; // Nếu lỗi thì trả về ảnh gốc
    }
  }

  // Upload lên Firebase và đăng moment
  Future<void> _uploadAndPost() async {
    if (_capturedMedia == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Kiểm tra giới hạn 20 moments/tháng (free user)
    try {
      final canPost = await FirestoreService().canPostMoment(userId);
      if (!canPost) {
        await _showPremiumUpsellDialog();
        return;
      }
    } catch (e) {
      developer.log('Check limit error: $e', name: 'CameraCapture');
    }

    // Hỏi user nhập caption
    final caption = await _showCaptionDialog();
    if (caption == null) return;

    // Hiện loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.deepOrange),
      ),
    );

    try {
      String? mediaUrl;
      String? thumbnailUrl;

      if (_isVideo) {
        // Upload video
        final videoRef = FirebaseStorage.instance.ref().child(
          'moments/$userId/video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        await videoRef.putFile(File(_capturedMedia!.path));
        mediaUrl = await videoRef.getDownloadURL();

        // Upload thumbnail
        if (_localThumbnailPath != null) {
          final thumbRef = FirebaseStorage.instance.ref().child(
            'moments/$userId/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await thumbRef.putFile(File(_localThumbnailPath!));
          thumbnailUrl = await thumbRef.getDownloadURL();
        }
      } else {
        // Lật ảnh camera trước với quality cao
        XFile imageToUpload = _capturedMedia!;
        if (_isFrontCamera) {
          imageToUpload = await _flipImageIfFrontCamera(_capturedMedia!);
        }

        // Upload ảnh với metadata quality cao
        final imageRef = FirebaseStorage.instance.ref().child(
          'moments/$userId/image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'quality': 'high'}, // Đánh dấu quality cao
        );

        await imageRef.putFile(File(imageToUpload.path), metadata);
        mediaUrl = await imageRef.getDownloadURL();
      }

      // Lấy danh sách match để gửi moment
      final momentProvider = Provider.of<MomentProvider>(
        context,
        listen: false,
      );
      final matchedUserIds = await momentProvider.getMatchedUserIds(userId);

      // Đăng lên Firestore
      await momentProvider.postMoment(
        userId: userId,
        mediaUrl: mediaUrl,
        isVideo: _isVideo,
        matchIds: matchedUserIds,
        caption: caption.isEmpty ? null : caption,
        thumbnailUrl: thumbnailUrl,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Đóng loading
      Navigator.of(context).pop(true); // Quay lại
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đăng khoảnh khắc!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      developer.log(
        'Error uploading moment: $e',
        name: 'CameraCapture',
        error: e,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final msg = e.toString();
      if (msg.contains('LIMIT_EXCEEDED')) {
        await _showPremiumUpsellDialog();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  // Dialog upsell premium khi vượt giới hạn
  Future<void> _showPremiumUpsellDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
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
                    colors: [
                      Colors.deepOrange.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.amber,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Nâng cấp Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bạn đã đăng đủ 20 khoảnh khắc trong tháng này!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nâng cấp để đăng không giới hạn',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Text(
                              'Để sau',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SubscriptionScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 8,
                              shadowColor: Colors.deepOrange.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            child: const Text(
                              'Nâng cấp ngay',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

  // Dialog nhập caption
  Future<String?> _showCaptionDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
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
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thêm chú thích',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Bạn đang nghĩ gì?',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        autofocus: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Hủy',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(ctx, controller.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Đăng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

  @override
  Widget build(BuildContext context) {
    // Nếu đã chụp/quay thì hiện màn preview
    if (_capturedMedia != null) {
      return _buildPreviewScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? Stack(
              children: [
                // Camera preview tỷ lệ 9:16
                Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: GestureDetector(
                      onTapDown: _handleTapToFocus,
                      onScaleStart: _handleScaleStart,
                      onScaleUpdate: _handleScaleUpdate,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),

                // Vòng tròn focus vàng khi tap
                if (_showFocusCircle && _focusPoint != null)
                  Positioned(
                    left: _focusPoint!.dx - 40,
                    top: _focusPoint!.dy - 40,
                    child: FadeTransition(
                      opacity: _focusAnimationController!,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.yellow, width: 2),
                        ),
                      ),
                    ),
                  ),

                // Thanh điều chỉnh độ sáng
                if (_showExposureSlider && _exposureSliderPosition != null)
                  Positioned(
                    left: _exposureSliderPosition!.dx + 50,
                    top: _exposureSliderPosition!.dy - 80,
                    child: FadeTransition(
                      opacity: _focusAnimationController!,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: 40,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.wb_sunny_rounded,
                                  color: Colors.yellow,
                                  size: 20,
                                ),
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 8,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 16,
                                            ),
                                      ),
                                      child: Slider(
                                        value: _exposure,
                                        min: -2.0,
                                        max: 2.0,
                                        activeColor: Colors.yellow,
                                        inactiveColor: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        onChanged: (value) async {
                                          _exposure = value;
                                          await _controller?.setExposureOffset(
                                            _exposure,
                                          );
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.wb_sunny_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Top bar với nút đóng
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
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),

                // Đồng hồ đếm giây khi đang quay
                if (_isRecording)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: RecordingIndicator(seconds: _recordingSeconds),
                    ),
                  ),

                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(
                      bottom: 40,
                      left: 20,
                      right: 20,
                      top: 20,
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
                    child: Column(
                      children: [
                        // Hàng nút: Flash, Flip camera, Zoom
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildGlassIconButton(
                              icon: _isFlashOn
                                  ? Icons.flash_on
                                  : Icons.flash_off,
                              onPressed: () async {
                                if (_isFrontCamera) {
                                  setState(() => _isFlashOn = !_isFlashOn);
                                } else {
                                  _isFlashOn = !_isFlashOn;
                                  await _controller!.setFlashMode(
                                    _isFlashOn
                                        ? FlashMode.torch
                                        : FlashMode.off,
                                  );
                                  setState(() {});
                                }
                              },
                            ),
                            _buildGlassIconButton(
                              icon: Icons.flip_camera_ios_rounded,
                              onPressed: _toggleCamera,
                            ),
                            _buildZoomPreset('1', 1.0),
                            _buildZoomPreset('2', 2.0),
                            _buildZoomPreset('3', 3.0),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Hàng nút chính: Thư viện, Chụp/Quay, Chuyển chế độ
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Nút thư viện
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: _buildGlassIconButton(
                                icon: Icons.photo_library_rounded,
                                onPressed: _pickFromGallery,
                              ),
                            ),
                            // Nút chụp/quay chính giữa
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: GestureDetector(
                                onTap: _isRecording
                                    ? _stopRecording
                                    : (_isVideo
                                          ? _startRecording
                                          : _takePicture),
                                onLongPress: () {
                                  if (!_isRecording && !_isVideo) {
                                    _startRecording();
                                  }
                                },
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: _isRecording ? 32 : 60,
                                    height: _isRecording ? 32 : 60,
                                    decoration: BoxDecoration(
                                      color: _isRecording
                                          ? Colors.red
                                          : Colors.white,
                                      shape: _isRecording
                                          ? BoxShape.rectangle
                                          : BoxShape.circle,
                                      borderRadius: _isRecording
                                          ? BorderRadius.circular(8)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Nút chuyển chế độ video/ảnh
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _isVideo = !_isVideo),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(35),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 20,
                                      sigmaY: 20,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        _isVideo
                                            ? Icons.camera_alt_rounded
                                            : Icons.videocam_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Text hướng dẫn
                        Text(
                          _isRecording
                              ? 'Nhấn để dừng'
                              : _isVideo
                              ? 'Nhấn để quay • Giữ để chụp'
                              : 'Nhấn để chụp • Giữ để quay',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Hiển thị mức zoom
                Positioned(
                  bottom: 200,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _currentZoom != 1.0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${_currentZoom.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Overlay trắng giả flash camera trước
                if (_showFrontFlashOverlay)
                  Positioned.fill(child: Container(color: Colors.white)),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            ),
    );
  }

  // Màn hình preview sau khi chụp/quay
  Widget _buildPreviewScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Preview media
          Center(
            child: _isVideo
                ? (_localThumbnailPath != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_localThumbnailPath!),
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
                                if (_isGeneratingThumbnail)
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
                                  _isGeneratingThumbnail
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
                // SỬA: Lật preview nếu là camera trước
                : (_isFrontCamera
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..scale(-1.0, 1.0), // Lật ngang
                          child: Image.file(
                            File(_capturedMedia!.path),
                            fit: BoxFit.contain,
                          ),
                        )
                      : Image.file(
                          File(_capturedMedia!.path),
                          fit: BoxFit.contain,
                        )),
          ),

          // Top bar với nút hủy (GIỮ NGUYÊN)
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
                    onPressed: () {
                      // Xóa thumbnail local
                      if (_localThumbnailPath != null) {
                        File(_localThumbnailPath!).delete().catchError((_) {});
                      }
                      setState(() {
                        _capturedMedia = null;
                        _localThumbnailPath = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom actions (GIỮ NGUYÊN)
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
                    onPressed: () {
                      if (_localThumbnailPath != null) {
                        File(_localThumbnailPath!).delete().catchError((_) {});
                      }
                      setState(() {
                        _capturedMedia = null;
                        _localThumbnailPath = null;
                      });
                    },
                    isPrimary: false,
                  ),
                  _buildPreviewButton(
                    icon: Icons.arrow_forward_rounded,
                    label: 'Đăng',
                    onPressed: _uploadAndPost,
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

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _controller?.dispose();
    _videoController?.dispose();
    _focusAnimationController?.dispose();

    // Xóa thumbnail local
    if (_localThumbnailPath != null) {
      File(_localThumbnailPath!).delete().catchError((_) {});
    }

    super.dispose();
  }
}
