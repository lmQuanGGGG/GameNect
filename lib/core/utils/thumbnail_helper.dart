import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailResult {
  final List<int>? bytes;
  final String? path;
  ThumbnailResult({this.bytes, this.path});
}

Future<ThumbnailResult?> generateVideoThumbnail(XFile videoFile) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final path = await VideoThumbnail.thumbnailFile(
      video: videoFile.path,
      thumbnailPath: tempDir.path,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 400,
      quality: 75,
    );
    if (path != null) {
      return ThumbnailResult(path: path);
    }
  } catch (e) {
    print('Error generating thumbnail: $e');
  }
  return null;
}
