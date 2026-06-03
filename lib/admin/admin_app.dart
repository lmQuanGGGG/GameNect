import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/auth_service.dart';
import 'screens/dashboard/admin_dashboard_screen.dart';
import 'screens/users/user_management_screen.dart';
import 'screens/premium/subscription_config_screen.dart';
import 'screens/mentor/mentor_management_screen.dart';

// Widget AdminApp là giao diện tổng cho admin.
// Quản lý các chức năng: xem thống kê doanh thu, quản lý gói Premium, quản lý người dùng.
// Sử dụng BottomNavigationBar để chuyển đổi giữa các màn hình chức năng.
// Mỗi màn hình là một widget riêng biệt, được lưu trong danh sách _screens.

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  // Biến lưu chỉ số màn hình hiện tại đang được chọn trên thanh điều hướng dưới cùng.
  int _selectedIndex = 0;

  // Danh sách các màn hình chức năng, mỗi phần tử là một widget màn hình.
  final List<Widget> _screens = [
    const AdminDashboardScreen(), // Màn hình thống kê doanh thu
    const SubscriptionConfigScreen(), // Màn hình quản lý gói Premium
    const UserManagementScreen(), // Màn hình quản lý người dùng
    const MentorManagementScreen(), // Màn hình quản lý Mentor
  ];

  // Danh sách tiêu đề cho từng màn hình, dùng để hiển thị trên AppBar.
  final List<String> _titles = [
    'Thống kê doanh thu',
    'Quản lý gói Premium',
    'Quản lý người dùng',
    'Quản lý Mentor',
  ];

  @override
  Widget build(BuildContext context) {
    // Sử dụng MaterialApp để khởi tạo theme và cấu hình app cho admin.
    return MaterialApp(
      title: 'GameNect Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF181A20),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        fontFamily: 'SF Pro Display',
      ),
      home: Scaffold(
        extendBody: true,
        appBar: AppBar(
          // Hiển thị tiêu đề tương ứng với màn hình đang chọn.
          title: Text(_titles[_selectedIndex]),
          actions: [
            // Nút đăng xuất nằm ở góc phải AppBar, gọi hàm signOut từ AuthService khi bấm.
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final authService = Provider.of<AuthService>(context, listen: false);
                await authService.signOut();
              },
            ),
          ],
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        // Hiển thị nội dung màn hình chức năng tương ứng với chỉ số đã chọn.
        body: _screens[_selectedIndex],
        // Thanh điều hướng dưới cùng cho phép chuyển đổi giữa các chức năng quản trị.
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border(
              top: BorderSide(
                color: Colors.deepOrange.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.deepOrange,
            unselectedItemColor: Colors.white70,
            showUnselectedLabels: true,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            // Khi bấm vào một mục, cập nhật chỉ số màn hình đang chọn để hiển thị nội dung mới.
            onTap: (index) => setState(() => _selectedIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded),
                label: 'Doanh thu',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.workspace_premium),
                label: 'Gói Premium',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Người dùng',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.school_rounded),
                label: 'Mentor',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
