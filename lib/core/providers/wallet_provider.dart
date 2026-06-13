import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalletProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Tạo lệnh rút tiền
  /// [coins]: số lượng coin muốn rút
  /// [amount]: số tiền VNĐ tương ứng
  /// [bankInfo]: thông tin ngân hàng (Map)
  Future<bool> createWithdrawRequest(int coins, int amount, Map<String, String> bankInfo) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Tạo document request trong collection withdraw_requests
      await FirebaseFirestore.instance.collection('withdraw_requests').add({
        'userId': userId,
        'coins': coins,
        'amount': amount,
        'bankInfo': bankInfo,
        'status': 'pending', // pending, approved, rejected
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Trừ trực tiếp coinBalance của user ngay khi tạo lệnh để tránh rút trùng
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'coinBalance': FieldValue.increment(-coins),
      });

      return true;
    } catch (e) {
      debugPrint('Error creating withdraw request: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lấy danh sách lệnh rút tiền của user hiện tại
  Stream<List<Map<String, dynamic>>> getMyWithdrawRequests() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('withdraw_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sắp xếp giảm dần theo createdAt
      list.sort((a, b) {
        final tA = a['createdAt'] as Timestamp?;
        final tB = b['createdAt'] as Timestamp?;
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  /// Lấy danh sách lịch sử nạp coin của user hiện tại
  Stream<List<Map<String, dynamic>>> getMyCoinOrders() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('orderType', isEqualTo: 'coin')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sắp xếp giảm dần theo createdAt
      list.sort((a, b) {
        final tA = a['createdAt'] as Timestamp?;
        final tB = b['createdAt'] as Timestamp?;
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });
      return list;
    });
  }
}
