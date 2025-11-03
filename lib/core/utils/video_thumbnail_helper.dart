import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

/// Lớp tiện ích giúp tạo và quản lý ảnh thu nhỏ từ video
/// Sử dụng để tạo thumbnail cho video người dùng upload lên hệ thống
class VideoThumbnailHelper {
  /// Hàm tạo ảnh thu nhỏ từ đường dẫn file video trên thiết bị
  /// Tham số videoPath là đường dẫn tuyệt đối đến file video cần tạo thumbnail
  /// Trả về đường dẫn file thumbnail hoặc null nếu có lỗi
  static Future<String?> generateThumbnail(String videoPath) async {
    try {
      /// Gọi thư viện video_thumbnail để tạo ảnh thu nhỏ
      /// video: đường dẫn video nguồn
      /// thumbnailPath: thư mục lưu thumbnail tạm thời trên thiết bị
      /// imageFormat: định dạng ảnh JPEG để tối ưu dung lượng
      /// maxHeight: giới hạn chiều cao 400px để giảm kích thước file
      /// quality: chất lượng nén 75% cân bằng giữa dung lượng và độ rõ nét
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 400,
        quality: 75,
      );
      
      /// Ghi log đường dẫn thumbnail vừa tạo để theo dõi và debug
      developer.log('Generated thumbnail: $thumbnailPath', name: 'VideoThumbnail');
      return thumbnailPath;
    } catch (e) {
      /// Bắt và ghi log lỗi nếu quá trình tạo thumbnail thất bại
      /// Trả về null để hàm gọi biết có lỗi xảy ra
      developer.log('Error generating thumbnail: $e', name: 'VideoThumbnail', error: e);
      return null;
    }
  }
  
  /// Hàm upload ảnh thu nhỏ lên Firebase Storage để lưu trữ lâu dài
  /// Tham số thumbnailPath là đường dẫn file thumbnail trên thiết bị
  /// Tham số userId dùng để tạo thư mục riêng cho từng người dùng
  /// Trả về URL download của thumbnail hoặc null nếu có lỗi
  static Future<String?> uploadThumbnail(String thumbnailPath, String userId) async {
    try {
      /// Tạo đối tượng File từ đường dẫn thumbnail
      final file = File(thumbnailPath);
      /// Kiểm tra file có tồn tại trên thiết bị không trước khi upload
      /// Nếu không tồn tại thì trả về null ngay
      if (!await file.exists()) return null;
      
      /// Tạo timestamp để đảm bảo tên file thumbnail là duy nhất
      /// Tránh trường hợp ghi đè file cũ khi người dùng upload nhiều video
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      /// Tạo reference đến vị trí lưu trữ trên Firebase Storage
      /// Cấu trúc thư mục: thumbnails/userId/thumb_timestamp.jpg
      /// Giúp dễ quản lý và phân loại thumbnail theo từng người dùng
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('thumbnails/$userId/thumb_$timestamp.jpg');
      
      /// Upload file thumbnail lên Firebase Storage
      await storageRef.putFile(file);
      /// Lấy URL công khai để truy cập thumbnail sau khi upload thành công
      /// URL này sẽ được lưu vào Firestore để hiển thị trên ứng dụng
      final downloadUrl = await storageRef.getDownloadURL();
      
      /// Xóa file thumbnail tạm trên thiết bị sau khi đã upload thành công
      /// Giúp giải phóng bộ nhớ thiết bị và tránh lưu file rác
      await file.delete();
      
      /// Ghi log URL thumbnail để theo dõi và debug
      developer.log('Uploaded thumbnail: $downloadUrl', name: 'VideoThumbnail');
      return downloadUrl;
    } catch (e) {
      /// Bắt và ghi log lỗi nếu quá trình upload thất bại
      /// Trả về null để hàm gọi biết có lỗi xảy ra
      developer.log('Error uploading thumbnail: $e', name: 'VideoThumbnail', error: e);
      return null;
    }
  }
}