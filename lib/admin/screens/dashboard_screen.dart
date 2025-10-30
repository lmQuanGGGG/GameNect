import 'package:flutter/material.dart';

// Màn hình bảng điều khiển dành cho admin.
// Hiển thị các chức năng quản trị như quản lý người dùng, quản lý gói Premium.
// Sử dụng Scaffold để tạo bố cục với AppBar và phần nội dung chính.
// Phần nội dung gồm tiêu đề chào mừng và các thẻ chức năng được bố trí bằng Wrap.

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Tiêu đề của màn hình quản trị
        title: const Text('Bảng điều khiển Admin'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị lời chào mừng admin
            const Text(
              'Chào mừng bạn đến với trang quản trị GameNect!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Các thẻ chức năng quản trị được bố trí bằng Wrap
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Thẻ quản lý người dùng, khi bấm sẽ chuyển sang màn hình quản lý user
                _AdminCard(
                  icon: Icons.people,
                  title: 'Quản lý người dùng',
                  onTap: () => Navigator.pushNamed(context, '/user-management'),
                ),
                // Thẻ quản lý gói Premium, khi bấm sẽ chuyển sang màn hình cấu hình gói đăng ký
                _AdminCard(
                  icon: Icons.workspace_premium,
                  title: 'Quản lý gói Premium',
                  onTap: () => Navigator.pushNamed(context, '/subscription-config'),
                ),
                // Có thể thêm các chức năng quản trị khác tại đây
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget hiển thị một thẻ chức năng cho admin.
// Nhận vào icon, tiêu đề và hàm xử lý khi bấm vào thẻ.
// Sử dụng InkWell để tạo hiệu ứng khi bấm, Container để tạo giao diện thẻ với màu nền, bo góc và bóng đổ.

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.deepOrange.shade50,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepOrange.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hiển thị icon chức năng
            Icon(icon, size: 40, color: Colors.deepOrange),
            const SizedBox(height: 12),
            // Hiển thị tiêu đề chức năng
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}