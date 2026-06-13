import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/subscription_provider.dart';

// Màn hình cấu hình các gói Premium dành cho admin.
// Giao diện thiết kế theo phong cách Neo-Brutalism nền trắng, chữ đen, viền dày nổi bật.
class SubscriptionConfigScreen extends StatelessWidget {
  const SubscriptionConfigScreen({super.key});

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data()?['isAdmin'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }
        if (!snapshot.data!) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Text(
                'Bạn không có quyền truy cập!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        }
        return ChangeNotifierProvider(
          create: (_) => SubscriptionProvider()..fetchPlans(),
          child: const _SubscriptionConfigContent(),
        );
      },
    );
  }
}

class _SubscriptionConfigContent extends StatelessWidget {
  const _SubscriptionConfigContent();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Thanh tiêu đề và nút thêm gói mới.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.black, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Quản lý gói Premium',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showAddDialog(context, provider),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6E40), // Cam neon
                        border: Border.all(color: Colors.black, width: 2.5),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            // Đường kẻ ngăn cách dày
            Container(
              height: 2,
              color: Colors.black,
              margin: const EdgeInsets.only(bottom: 8),
            ),
            // Hiển thị danh sách các gói Premium.
            Expanded(
              child: provider.plans.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : ListView.builder(
                      itemCount: provider.plans.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final plan = provider.plans[index];
                        return _NeoPlanCard(
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
        title: const Text(
          'Thêm gói mới',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NeoTextField(controller: planTypeController, label: 'Loại gói (monthly/yearly)'),
              _NeoTextField(controller: titleController, label: 'Tên gói'),
              _NeoTextField(controller: priceController, label: 'Giá (số)', keyboardType: TextInputType.number),
              _NeoTextField(controller: priceTextController, label: 'Giá hiển thị (vd: 84.500đ)'),
              _NeoTextField(controller: pricePerMonthController, label: 'Giá/tháng (vd: 42.250đ/tháng)'),
              _NeoTextField(controller: badgeController, label: 'Badge (vd: Tiết kiệm 50%)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Kích hoạt',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<bool>(
                    valueListenable: isActive,
                    builder: (context, value, _) => Switch(
                      value: value,
                      activeColor: Colors.black,
                      activeTrackColor: const Color(0xFFFF6E40),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.shade300,
                      onChanged: (v) => isActive.value = v,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          GestureDetector(
            onTap: () async {
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
              if (context.mounted) Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6E40),
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                ],
              ),
              child: const Text(
                'Thêm',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
        title: const Text(
          'Sửa gói',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NeoTextField(controller: titleController, label: 'Tên gói'),
              _NeoTextField(controller: priceController, label: 'Giá (số)', keyboardType: TextInputType.number),
              _NeoTextField(controller: priceTextController, label: 'Giá hiển thị'),
              _NeoTextField(controller: pricePerMonthController, label: 'Giá/tháng'),
              _NeoTextField(controller: badgeController, label: 'Badge'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Kích hoạt',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<bool>(
                    valueListenable: isActive,
                    builder: (context, value, _) => Switch(
                      value: value,
                      activeColor: Colors.black,
                      activeTrackColor: const Color(0xFFFF6E40),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.shade300,
                      onChanged: (v) => isActive.value = v,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          GestureDetector(
            onTap: () async {
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
              if (context.mounted) Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6E40),
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                ],
              ),
              child: const Text(
                'Lưu',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deletePlan(BuildContext context, SubscriptionProvider provider, Map<String, dynamic> plan) async {
    final docId = plan['id'] ?? plan['docId'];
    if (docId != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black, width: 2.5),
          ),
          title: const Text(
            'Xác nhận xóa',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa gói Premium "${plan['title']}"? Hành động này không thể hoàn tác.',
            style: const TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Hủy',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350), // Đỏ neon
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                  ],
                ),
                child: const Text(
                  'Xóa',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await FirebaseFirestore.instance.collection('premium_plans').doc(docId).delete();
        provider.fetchPlans();
      }
    }
  }
}

class _NeoPlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NeoPlanCard({
    required this.plan,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0B2), // Cam nhạt
              border: Border.all(color: Colors.black, width: 2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.black, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Giá: ${plan['priceText'] ?? plan['price']}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFFFF6E40),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (plan['pricePerMonth'] != null && plan['pricePerMonth'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      plan['pricePerMonth'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (plan['badge'] != null && plan['badge'].toString().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF176), // Vàng neon
                      border: Border.all(color: Colors.black, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan['badge'],
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                if (plan['isActive'] == false)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Đã ẩn',
                      style: TextStyle(color: Color(0xFFEF5350), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF176), // Vàng neon
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5))],
            ),
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.black, size: 18),
              onPressed: onEdit,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350), // Đỏ neon
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5))],
            ),
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.white, size: 18),
              onPressed: onDelete,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  const _NeoTextField({
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
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}