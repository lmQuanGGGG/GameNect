import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/providers/subscription_provider.dart';

// Màn hình cấu hình các gói Premium dành cho admin.
// Kiểm tra quyền admin trước khi cho phép truy cập màn hình này.
// Nếu không phải admin, hiển thị thông báo không có quyền truy cập.

class SubscriptionConfigScreen extends StatelessWidget {
  const SubscriptionConfigScreen({super.key});

  // Hàm kiểm tra user hiện tại có phải admin hay không.
  // Trả về true nếu user có quyền admin, ngược lại trả về false.
  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data()?['isAdmin'] == true;
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng FutureBuilder để kiểm tra quyền admin trước khi hiển thị nội dung.
    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Hiển thị vòng quay khi đang kiểm tra quyền.
          return const Scaffold(
            backgroundColor: Color(0xFF181A20),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!) {
          // Nếu không phải admin, hiển thị thông báo không có quyền truy cập.
          return const Scaffold(
            backgroundColor: Color(0xFF181A20),
            body: Center(
              child: Text(
                'Bạn không có quyền truy cập!',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ),
          );
        }
        // Nếu là admin, khởi tạo provider và hiển thị nội dung cấu hình gói Premium.
        return ChangeNotifierProvider(
          create: (_) => SubscriptionProvider()..fetchPlans(),
          child: const _SubscriptionConfigContent(),
        );
      },
    );
  }
}

// Widget hiển thị nội dung cấu hình các gói Premium.
// Lấy danh sách các gói từ provider và hiển thị dưới dạng danh sách.
// Cho phép thêm, sửa, xóa các gói Premium.

class _SubscriptionConfigContent extends StatelessWidget {
  const _SubscriptionConfigContent();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: SafeArea(
        child: Column(
          children: [
            // Thanh tiêu đề và nút thêm gói mới.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                children: [
                  // Hiển thị icon Premium và tiêu đề màn hình.
                  const Icon(Icons.workspace_premium, color: Colors.deepOrange, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Quản lý gói Premium',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade200,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  // Nút thêm gói mới, khi bấm sẽ mở dialog nhập thông tin gói.
                  FloatingActionButton(
                    backgroundColor: Colors.deepOrange,
                    mini: true,
                    onPressed: () => _showAddDialog(context, provider),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Hiển thị danh sách các gói Premium.
            Expanded(
              child: provider.plans.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: provider.plans.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final plan = provider.plans[index];
                        // Hiển thị từng gói bằng GlassPlanCard, có nút sửa và xóa.
                        return _GlassPlanCard(
                          plan: plan,
                          onEdit: () => _showEditDialog(context, provider, plan),
                          onDelete: () => _deletePlan(context, provider, plan),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Hàm hiển thị dialog thêm gói mới.
  // Nhập thông tin gói và lưu vào Firestore khi bấm nút Thêm.
  void _showAddDialog(BuildContext context, SubscriptionProvider provider) {
    final planTypeController = TextEditingController();
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final priceTextController = TextEditingController();
    final pricePerMonthController = TextEditingController();
    final badgeController = TextEditingController();
    final isActive = ValueNotifier<bool>(true);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232526),
        title: const Text('Thêm gói mới', style: TextStyle(color: Colors.deepOrange)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Các trường nhập thông tin gói mới.
              _GlassTextField(controller: planTypeController, label: 'Loại gói (monthly/yearly)'),
              _GlassTextField(controller: titleController, label: 'Tên gói'),
              _GlassTextField(controller: priceController, label: 'Giá (số)', keyboardType: TextInputType.number),
              _GlassTextField(controller: priceTextController, label: 'Giá hiển thị (vd: 84.500đ)'),
              _GlassTextField(controller: pricePerMonthController, label: 'Giá/tháng (vd: 42.250đ/tháng)'),
              _GlassTextField(controller: badgeController, label: 'Badge (vd: Tiết kiệm 50%)'),
              Row(
                children: [
                  const Text('Kích hoạt', style: TextStyle(color: Colors.white70)),
                  const Spacer(),
                  // Switch để chọn trạng thái kích hoạt của gói.
                  ValueListenableBuilder<bool>(
                    valueListenable: isActive,
                    builder: (context, value, _) => Switch(
                      value: value,
                      activeColor: Colors.deepOrange,
                      onChanged: (v) => isActive.value = v,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Nút Thêm để lưu gói mới vào Firestore.
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('premium_plans').add({
                'planType': planTypeController.text,
                'title': titleController.text,
                'price': int.tryParse(priceController.text) ?? 0,
                'priceText': priceTextController.text,
                'pricePerMonth': pricePerMonthController.text,
                'badge': badgeController.text,
                'isActive': isActive.value,
              });
              provider.fetchPlans();
              Navigator.pop(context);
            },
            child: const Text('Thêm', style: TextStyle(color: Colors.deepOrange)),
          ),
          // Nút Hủy để đóng dialog.
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // Hàm hiển thị dialog sửa thông tin gói Premium.
  // Cho phép chỉnh sửa các trường và lưu lại vào Firestore.
  void _showEditDialog(BuildContext context, SubscriptionProvider provider, Map<String, dynamic> plan) {
    final titleController = TextEditingController(text: plan['title'] ?? '');
    final priceController = TextEditingController(text: plan['price']?.toString() ?? '');
    final priceTextController = TextEditingController(text: plan['priceText'] ?? '');
    final pricePerMonthController = TextEditingController(text: plan['pricePerMonth'] ?? '');
    final badgeController = TextEditingController(text: plan['badge'] ?? '');
    final isActive = ValueNotifier<bool>(plan['isActive'] ?? true);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232526),
        title: const Text('Sửa gói', style: TextStyle(color: Colors.deepOrange)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Các trường chỉnh sửa thông tin gói.
              _GlassTextField(controller: titleController, label: 'Tên gói'),
              _GlassTextField(controller: priceController, label: 'Giá (số)', keyboardType: TextInputType.number),
              _GlassTextField(controller: priceTextController, label: 'Giá hiển thị'),
              _GlassTextField(controller: pricePerMonthController, label: 'Giá/tháng'),
              _GlassTextField(controller: badgeController, label: 'Badge'),
              Row(
                children: [
                  const Text('Kích hoạt', style: TextStyle(color: Colors.white70)),
                  const Spacer(),
                  // Switch để chỉnh trạng thái kích hoạt của gói.
                  ValueListenableBuilder<bool>(
                    valueListenable: isActive,
                    builder: (context, value, _) => Switch(
                      value: value,
                      activeColor: Colors.deepOrange,
                      onChanged: (v) => isActive.value = v,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Nút Lưu để cập nhật thông tin gói vào Firestore.
          TextButton(
            onPressed: () async {
              final docId = plan['id'] ?? plan['docId'];
              if (docId != null) {
                await FirebaseFirestore.instance.collection('premium_plans').doc(docId).update({
                  'title': titleController.text,
                  'price': int.tryParse(priceController.text) ?? 0,
                  'priceText': priceTextController.text,
                  'pricePerMonth': pricePerMonthController.text,
                  'badge': badgeController.text,
                  'isActive': isActive.value,
                });
                provider.fetchPlans();
              }
              Navigator.pop(context);
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.deepOrange)),
          ),
          // Nút Hủy để đóng dialog.
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // Hàm xóa một gói Premium khỏi Firestore.
  void _deletePlan(BuildContext context, SubscriptionProvider provider, Map<String, dynamic> plan) async {
    final docId = plan['id'] ?? plan['docId'];
    if (docId != null) {
      await FirebaseFirestore.instance.collection('premium_plans').doc(docId).delete();
      provider.fetchPlans();
    }
  }
}

// Widget hiển thị thông tin một gói Premium dưới dạng thẻ.
// Hiển thị tên gói, giá, badge, trạng thái kích hoạt, nút sửa và xóa.

class _GlassPlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GlassPlanCard({
    required this.plan,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.deepOrange.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Icon Premium của gói.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.deepOrange, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên gói Premium.
                Text(
                  plan['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Giá hiển thị của gói.
                Text(
                  'Giá: ${plan['priceText'] ?? plan['price']}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.deepOrangeAccent,
                  ),
                ),
                // Giá/tháng nếu có.
                if (plan['pricePerMonth'] != null && plan['pricePerMonth'].toString().isNotEmpty)
                  Text(
                    plan['pricePerMonth'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                // Badge khuyến mãi nếu có.
                if (plan['badge'] != null && plan['badge'].toString().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan['badge'],
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                // Hiển thị trạng thái đã ẩn nếu gói không kích hoạt.
                if (plan['isActive'] == false)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Đã ẩn',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Nút sửa gói.
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.deepOrangeAccent),
            onPressed: onEdit,
          ),
          // Nút xóa gói.
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// Widget trường nhập liệu có hiệu ứng nền mờ.
// Dùng cho dialog thêm/sửa gói Premium.

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  const _GlassTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}