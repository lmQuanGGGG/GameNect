import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard/admin_dashboard_screen.dart';
import 'screens/users/user_management_screen.dart';
import 'screens/premium/subscription_config_screen.dart';
import 'screens/mentor/mentor_management_screen.dart';
import 'screens/withdrawals/withdrawals_screen.dart';

// Shell chính của Admin Panel
// Giao diện Neo-Brutalism nền trắng, chữ đen chủ đạo.
class AdminApp extends StatefulWidget {
  final VoidCallback? onBack;
  const AdminApp({super.key, this.onBack});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const SubscriptionConfigScreen(),
    const UserManagementScreen(),
    const MentorManagementScreen(),
    const WithdrawalsScreen(),
  ];

  final List<String> _titles = [
    'Doanh thu',
    'Gói Premium',
    'Người dùng',
    'Mentor',
    'Rút tiền',
  ];

  final List<IconData> _icons = [
    Icons.bar_chart_rounded,
    Icons.workspace_premium_rounded,
    Icons.people_rounded,
    Icons.school_rounded,
    Icons.account_balance_wallet_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameNect Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          surface: Colors.white,
        ),
        fontFamily: 'SF Pro Display',
      ),
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: Colors.white,
          // ── AppBar Neo-Brutalism ──────────────────────────────────────────────
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            // Nút quay lại
                            GestureDetector(
                              onTap: () {
                                if (widget.onBack != null) {
                                  widget.onBack!();
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: Colors.black, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.black,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Badge ADMIN
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Tiêu đề trang hiện tại
                            Text(
                              _titles[_selectedIndex],
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Đường kẻ dưới header
                    Container(height: 2, color: Colors.black),
                  ],
                ),
              ),
            ),
          ),
          body: _screens[_selectedIndex],
          // ── Bottom nav Neo-Brutalism ─────────────────────────────────────────
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              _icons.length,
              (i) => _buildNavItem(i),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.black26,
            width: isSelected ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icons[index],
              size: 20,
              color: isSelected ? Colors.white : Colors.black38,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                _titles[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
