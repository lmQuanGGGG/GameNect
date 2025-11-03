import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Service xử lý các chức năng liên quan đến thanh toán và quản lý gói premium
class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Xử lý mua gói subscription và cập nhật trạng thái premium cho user
  // tier là loại gói như monthly hoặc yearly
  // durationDays là số ngày hiệu lực của gói
  Future<void> purchaseSubscription(String tier, int durationDays) async {
    // Lấy userId từ FirebaseAuth để xác định user đang mua gói
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');

    // Tính ngày hết hạn dựa trên thời điểm hiện tại cộng số ngày gói
    final endDate = DateTime.now().add(Duration(days: durationDays));

    // Cập nhật thông tin subscription lên Firestore
    await _firestore.collection('users').doc(userId).update({
      'subscriptionTier': tier,
      'subscriptionEndDate': endDate.toIso8601String(),
      'isPremium': true,
      // Lưu ngày bắt đầu gói để tracking
      'premiumStartDate': DateTime.now().toIso8601String(),
    });

    // Lưu lại lịch sử giao dịch vào collection transactions
    // Giúp tra cứu lịch sử mua hàng và xử lý tranh chấp
    await _firestore.collection('transactions').add({
      'userId': userId,
      'tier': tier,
      'duration': durationDays,
      'purchaseDate': FieldValue.serverTimestamp(),
      'endDate': endDate.toIso8601String(),
    });
  }

  // Kiểm tra trạng thái gói subscription còn hiệu lực không
  // Tự động reset về free nếu gói đã hết hạn
  Future<bool> checkSubscriptionStatus(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return false;

    final endDate = data['subscriptionEndDate'];
    if (endDate == null) return false;

    // Parse string thành DateTime để so sánh
    final expiry = DateTime.parse(endDate);
    // Kiểm tra thời gian hiện tại có trước ngày hết hạn không
    final isActive = DateTime.now().isBefore(expiry);

    // Nếu đã hết hạn thì reset về gói free
    if (!isActive) {
      await _firestore.collection('users').doc(userId).update({
        'subscriptionTier': 'free',
        'isPremium': false,
      });
    }

    return isActive;
  }
}