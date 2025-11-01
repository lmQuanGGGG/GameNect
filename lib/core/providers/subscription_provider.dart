import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

final _log = Logger();

// SubscriptionProvider quản lý trạng thái và logic liên quan đến việc mua, kích hoạt, kiểm tra và khôi phục gói premium cho người dùng.
class SubscriptionProvider with ChangeNotifier {
  // Biến trạng thái đang tải dữ liệu
  bool _isLoading = false;
  // Biến lưu loại gói premium đã chọn
  String? _selectedPlan;

  // Getter trả về trạng thái loading
  bool get isLoading => _isLoading;
  // Getter trả về loại gói đã chọn
  String? get selectedPlan => _selectedPlan;

  // Lấy thông tin cấu hình PayOS từ file .env
  static String get _payOSClientId => dotenv.env['PAYOS_CLIENT_ID'] ?? '';
  static String get _payOSApiKey => dotenv.env['PAYOS_API_KEY'] ?? '';
  static String get _payOSChecksumKey => dotenv.env['PAYOS_CHECKSUM_KEY'] ?? '';

  // Hàm chọn loại gói premium
  void selectPlan(String plan) {
    _selectedPlan = plan;
    notifyListeners();
  }

  // Danh sách các gói premium lấy từ Firestore
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> get plans => _plans;

  // Hàm lấy danh sách các gói premium đang hoạt động từ Firestore
  Future<void> fetchPlans() async {
    final snap = await FirebaseFirestore.instance
        .collection('premium_plans')
        .where('isActive', isEqualTo: true)
        .get();
    _plans = snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; 
      return data;
    }).toList();
    notifyListeners();
  }

  // Hàm lấy giá của gói premium theo loại gói
  int getPlanPrice(String planType) {
    final plan = _plans.firstWhere(
      (p) => p['planType'] == planType,
      orElse: () => {},
    );
    return plan['price'] ?? (planType == 'yearly' ? 507000 : 84500);
  }

  // Hàm thực hiện mua gói premium, tạo đơn hàng trên Firestore và gọi API PayOS để lấy link thanh toán
  Future<Map<String, dynamic>?> purchasePlan(String planType) async {
    _isLoading = true;
    notifyListeners();
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      final amount = getPlanPrice(planType);
      final orderCode = DateTime.now().millisecondsSinceEpoch;

      // Tạo đơn hàng trên Firestore với trạng thái pending
      await FirebaseFirestore.instance.collection('orders').doc(orderCode.toString()).set({
        'userId': userId,
        'planType': planType,
        'amount': amount,
        'orderCode': orderCode,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Gọi hàm tạo thanh toán PayOS
      final payment = await _createPayOSPayment(
        orderCode: orderCode,
        amount: amount,
        description: 'Premium $planType - GameNect',
      );

      return payment;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Hàm tạo thanh toán PayOS, trả về link thanh toán và orderCode
  Future<Map<String, dynamic>> _createPayOSPayment({
    required int orderCode,
    required int amount,
    required String description,
  }) async {
    if (_payOSClientId.isEmpty || _payOSApiKey.isEmpty || _payOSChecksumKey.isEmpty) {
      throw Exception('Missing PayOS credentials (.env)');
    }

    // URL trả về khi thanh toán thành công hoặc hủy
    final baseUrl = 'https://incandescent-pavlova-a73522.netlify.app/';
    final returnUrl = '$baseUrl/payment/success?orderCode=$orderCode';
    final cancelUrl = '$baseUrl/payment/cancel?orderCode=$orderCode';

    final url = Uri.parse('https://api-merchant.payos.vn/v2/payment-requests');
    final body = <String, dynamic>{
      'orderCode': orderCode,
      'amount': amount,
      'description': description,
      'cancelUrl': cancelUrl,
      'returnUrl': returnUrl,
    };

    // Tạo chữ ký HMAC SHA256 theo thứ tự key alphabet để xác thực với PayOS
    final sortedKeys = body.keys.toList()..sort();
    final dataStr = sortedKeys.map((k) => '$k=${body[k]}').join('&');
    final sig = Hmac(sha256, utf8.encode(_payOSChecksumKey)).convert(utf8.encode(dataStr)).toString();
    body['signature'] = sig;

    _log.i('Creating PayOS payment: $body');
    final res = await http.post(
      url,
      headers: {'x-client-id': _payOSClientId, 'x-api-key': _payOSApiKey, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    _log.i('PayOS response: ${res.statusCode} - ${res.body}');
    if (res.statusCode != 200) throw Exception('PayOS error: ${res.body}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return {
      'checkoutUrl': json['data']['checkoutUrl'],
      'orderCode': orderCode,
    };
  }

  // Hàm kiểm tra trạng thái thanh toán của đơn hàng qua API PayOS
  Future<String> checkPaymentStatus(int orderCode) async {
    try {
      final url = Uri.parse('https://api-merchant.payos.vn/v2/payment-requests/$orderCode');
      final res = await http.get(url, headers: {'x-client-id': _payOSClientId, 'x-api-key': _payOSApiKey});
      if (res.statusCode != 200) return 'pending';
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final status = (json['data']?['status'] ?? '').toString().toUpperCase();
      _log.i('Payment status($orderCode): $status');
      if (status == 'PAID') return 'success';
      if (status == 'CANCELLED' || status == 'REJECTED') return 'failed';
      return 'pending';
    } catch (e) {
      _log.w('checkPaymentStatus error: $e');
      return 'pending';
    }
  }

  // Hàm kích hoạt premium cho user khi thanh toán thành công, cập nhật thông tin lên Firestore
  Future<bool> activatePremium(String userId, String planType, int orderCode) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isPremium': true,
        'premiumPlan': planType,
        'premiumStartDate': FieldValue.serverTimestamp(),
        'premiumEndDate': Timestamp.fromDate(
          DateTime.now().add(planType == 'yearly' ? const Duration(days: 365) : const Duration(days: 30)),
        ),
      });
      await FirebaseFirestore.instance.collection('orders').doc(orderCode.toString()).update({'status': 'success'});
      return true;
    } catch (e) {
      _log.e('activatePremium error: $e');
      return false;
    }
  }

  // Hàm khôi phục lại trạng thái premium nếu user đã từng mua thành công
  Future<void> restorePurchase() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'success')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        throw Exception('Không tìm thấy giao dịch đã mua');
      }

      final data = snap.docs.first.data();
      final planType = (data['planType'] as String?) ?? 'monthly';

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isPremium': true,
        'premiumPlan': planType,
        'premiumStartDate': FieldValue.serverTimestamp(),
        'premiumEndDate': Timestamp.fromDate(
          DateTime.now().add(
            planType == 'yearly' ? const Duration(days: 365) : const Duration(days: 30),
          ),
        ),
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}