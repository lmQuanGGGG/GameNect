import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// PaymentService cung cấp các hàm xử lý liên quan đến việc mua và kiểm tra trạng thái gói subscription của người dùng.
class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hàm purchaseSubscription dùng để cập nhật thông tin gói subscription cho người dùng khi mua gói mới.
  // Tham số tier là loại gói (ví dụ: monthly, yearly), durationDays là số ngày hiệu lực của gói.
  // Hàm sẽ lấy userId từ FirebaseAuth, nếu chưa đăng nhập thì báo lỗi.
  // Tính ngày kết thúc gói dựa trên thời điểm hiện tại cộng thêm số ngày hiệu lực.
  // Cập nhật thông tin subscriptionTier, subscriptionEndDate và isPremium lên Firestore cho user.
  // Sau đó ghi log giao dịch vào collection transactions để lưu lịch sử mua gói, gồm userId, tier, duration, ngày mua và ngày hết hạn.
  Future<void> purchaseSubscription(String tier, int durationDays) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');

    final endDate = DateTime.now().add(Duration(days: durationDays));

    await _firestore.collection('users').doc(userId).update({
      'subscriptionTier': tier,
      'subscriptionEndDate': endDate.toIso8601String(),
      'isPremium': true,
    });

    // Log transaction
    await _firestore.collection('transactions').add({
      'userId': userId,
      'tier': tier,
      'duration': durationDays,
      'purchaseDate': FieldValue.serverTimestamp(),
      'endDate': endDate.toIso8601String(),
    });
  }

  // Hàm checkSubscriptionStatus kiểm tra trạng thái gói subscription của một user.
  // Truy vấn dữ liệu user từ Firestore, kiểm tra trường subscriptionEndDate.
  // Nếu không có dữ liệu hoặc không có ngày hết hạn thì trả về false.
  // Nếu còn hạn sử dụng thì trả về true, nếu đã hết hạn thì cập nhật lại user về trạng thái miễn phí (subscriptionTier = 'free', isPremium = false).
  // Hàm này giúp tự động reset trạng thái premium khi gói hết hạn.
  Future<bool> checkSubscriptionStatus(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return false;

    final endDate = data['subscriptionEndDate'];
    if (endDate == null) return false;

    final expiry = DateTime.parse(endDate);
    final isActive = DateTime.now().isBefore(expiry);

    if (!isActive) {
      // Reset to free if expired
      await _firestore.collection('users').doc(userId).update({
        'subscriptionTier': 'free',
        'isPremium': false,
      });
    }

    return isActive;
  }
}