import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

class VideoThumbnailHelper {
  /// Generate thumbnail từ video file path
  static Future<String?> generateThumbnail(String videoPath) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 400,
        quality: 75,
      );
      
      developer.log('Generated thumbnail: $thumbnailPath', name: 'VideoThumbnail');
      return thumbnailPath;
    } catch (e) {
      developer.log('Error generating thumbnail: $e', name: 'VideoThumbnail', error: e);
      return null;
    }
  }
  
  /// Upload thumbnail lên Firebase Storage
  static Future<String?> uploadThumbnail(String thumbnailPath, String userId) async {
    try {
      final file = File(thumbnailPath);
      if (!await file.exists()) return null;
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('thumbnails/$userId/thumb_$timestamp.jpg');
      
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Xóa file local
      await file.delete();
      
      developer.log('Uploaded thumbnail: $downloadUrl', name: 'VideoThumbnail');
      return downloadUrl;
    } catch (e) {
      developer.log('Error uploading thumbnail: $e', name: 'VideoThumbnail', error: e);
      return null;
    }
  }
}