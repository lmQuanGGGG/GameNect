// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'thumbnail_helper.dart';

Future<ThumbnailResult?> generateVideoThumbnail(XFile videoFile) async {
  final completer = Completer<ThumbnailResult?>();
  try {
    final video = html.VideoElement();
    video.src = videoFile.path;
    video.autoplay = false;
    video.muted = true;
    
    // Disable webkit inline video issues
    video.setAttribute('playsinline', 'true');
    video.setAttribute('webkit-playsinline', 'true');
    
    video.onLoadedMetadata.listen((_) {
      // Seek to 1 second
      video.currentTime = video.duration > 1 ? 1.0 : 0.0;
    });

    video.onSeeked.listen((_) {
      try {
        final canvas = html.CanvasElement(width: video.videoWidth, height: video.videoHeight);
        final ctx = canvas.context2D;
        ctx.drawImage(video, 0, 0);
        final dataUrl = canvas.toDataUrl('image/jpeg', 0.75);
        final binStr = html.window.atob(dataUrl.split(',')[1]);
        final bytes = Uint8List(binStr.length);
        for (int i = 0; i < binStr.length; i++) {
          bytes[i] = binStr.codeUnitAt(i);
        }
        completer.complete(ThumbnailResult(bytes: bytes));
      } catch (e) {
        completer.complete(null);
      }
    });

    video.onError.listen((_) {
      completer.complete(null);
    });
  } catch (e) {
    completer.complete(null);
  }

  return completer.future;
}
