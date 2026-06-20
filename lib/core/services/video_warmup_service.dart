import 'dart:collection';

import 'package:video_player/video_player.dart';

class VideoWarmupService {
  static const int _maxControllers = 4;
  static final LinkedHashMap<String, VideoPlayerController> _controllers =
      LinkedHashMap<String, VideoPlayerController>();
  static final Set<String> _warmingUrls = <String>{};

  static Future<void> warmUp(String url) async {
    if (url.isEmpty) return;
    if (_controllers.containsKey(url) || _warmingUrls.contains(url)) return;

    _warmingUrls.add(url);
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      await controller.setVolume(0);
      await controller.pause();
      _controllers[url] = controller;
      _trim();
    } catch (_) {
      // Warm-up is best-effort only; playback will create its own controller.
    } finally {
      _warmingUrls.remove(url);
    }
  }

  static VideoPlayerController? take(String url) {
    if (url.isEmpty) return null;
    return _controllers.remove(url);
  }

  static void _trim() {
    while (_controllers.length > _maxControllers) {
      final oldestUrl = _controllers.keys.first;
      final controller = _controllers.remove(oldestUrl);
      controller?.dispose();
    }
  }

  static void clear() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _warmingUrls.clear();
  }
}
