import 'package:flutter/material.dart';

// Màn hình bảng điều khiển dành cho admin.
// Hiển thị các chức năng quản trị như quản lý người dùng, quản lý gói Premium.
// Thiết kế theo phong cách Neo-Brutalism trắng đen cá tính, đồng bộ với toàn hệ thống.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'BẢNG ĐIỀU KHIỂN ADMIN',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.0,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: Colors.black, height: 2.5),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị lời chào mừng admin
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'XIN CHÀO ADMIN!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Chào mừng bạn quay trở lại trang quản trị GameNect. Hãy quản lý hệ thống hiệu quả.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Các thẻ chức năng quản trị được bố trí bằng Wrap
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Thẻ quản lý người dùng, khi bấm sẽ chuyển sang màn hình quản lý user
                _AdminCard(
                  icon: Icons.people_alt_rounded,
                  title: 'Quản lý người dùng',
                  onTap: () => Navigator.pushNamed(context, '/user-management'),
                ),
                // Thẻ quản lý gói Premium, khi bấm sẽ chuyển sang màn hình cấu hình gói đăng ký
                _AdminCard(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Quản lý gói Premium',
                  onTap: () => Navigator.pushNamed(context, '/subscription-config'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget hiển thị một thẻ chức năng cho admin.
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hiển thị icon chức năng
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                ],
              ),
              child: Icon(icon, size: 28, color: Colors.black),
            ),
            const SizedBox(height: 12),
            // Hiển thị tiêu đề chức năng
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}