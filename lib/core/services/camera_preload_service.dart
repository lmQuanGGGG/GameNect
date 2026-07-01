import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Singleton service that pre-warms the camera controller in the background
/// so the WebRTCCameraScreen opens instantly.
class CameraPreloadService {
  CameraPreloadService._();
  static final CameraPreloadService instance = CameraPreloadService._();

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isReady = false;
  bool _isLoading = false;

  Future<CameraController?>? _preloadFuture;

  bool get isReady => _isReady;
  CameraController? get controller => _controller;
  List<CameraDescription> get cameras => _cameras;

  /// Call this early to warm up the camera. Returns the future for claiming.
  Future<CameraController?> preload() {
    if (_isReady) return Future.value(_controller);
    if (_preloadFuture != null) return _preloadFuture!;

    _preloadFuture = _doPreload();
    return _preloadFuture!;
  }

  Future<CameraController?> _doPreload() async {
    _isLoading = true;

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _isLoading = false;
        return null;
      }

      // Prefer front camera (same default as WebRTCCameraScreen)
      int targetIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (targetIndex == -1) targetIndex = 0;

      final ctrl = CameraController(
        _cameras[targetIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await ctrl.initialize();
      try {
        await ctrl.setFlashMode(FlashMode.off);
      } catch (_) {}

      _controller = ctrl;
      _isReady = true;
      return ctrl;
    } catch (e) {
      debugPrint('[CameraPreload] Error: $e');
      return null;
    } finally {
      _isLoading = false;
      _preloadFuture = null;
    }
  }

  /// Called by WebRTCCameraScreen to claim the preloaded controller.
  Future<CameraController?> claim() async {
    // If it's already preloading, wait for it
    if (_preloadFuture != null) {
      final ctrl = await _preloadFuture;
      _controller = null;
      _isReady = false;
      return ctrl;
    }
    // If it's ready, return it
    final ctrl = _controller;
    _controller = null;
    _isReady = false;
    return ctrl;
  }

  /// Dispose if the preloaded controller was never claimed (e.g. user never opened camera).
  void release() {
    _controller?.dispose();
    _controller = null;
    _isReady = false;
    _isLoading = false;
  }
}
