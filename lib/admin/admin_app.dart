import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard/admin_dashboard_screen.dart';
import 'screens/users/user_management_screen.dart';
import 'screens/premium/subscription_config_screen.dart';
import 'screens/mentor/mentor_management_screen.dart';
import 'screens/withdrawals/withdrawals_screen.dart';

class AdminApp extends StatefulWidget {
  final VoidCallback? onBack;
  const AdminApp({super.key, this.onBack});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  int _selectedIndex = 0;

  static const _kBg = Color(0xFF0F0F13);
  static const _kSurface = Color(0xFF1A1A22);
  static const _kAccent = Color(0xFFFF5722); // deep orange
  static const _kAccentEnd = Color(0xFFFF9800); // orange

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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _kBg,
        colorScheme: const ColorScheme.dark(
          primary: _kAccent,
          surface: _kSurface,
        ),
        fontFamily: 'SF Pro Display',
      ),
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _kBg,
          extendBody: true,
          // ── AppBar premium ──────────────────────────────────────────────────
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF121217),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF22222B), width: 1),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      // Nút quay lại
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Badge ADMIN + tiêu đề
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_kAccent, _kAccentEnd],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _titles[_selectedIndex],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Spacer cho cân đối vì không còn nút logout
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: _screens[_selectedIndex],
          // ── Bottom nav premium ───────────────────────────────────────────────
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12, top: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF13131A),
        border: Border(
          top: BorderSide(color: Color(0xFF252530), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_icons.length, (i) => _buildNavItem(i)),
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF2C1A14), Color(0xFF20120C)],
                )
              : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => isSelected
                  ? const LinearGradient(
                      colors: [_kAccent, _kAccentEnd],
                    ).createShader(bounds)
                  : const LinearGradient(
                      colors: [Color(0xFF666680), Color(0xFF666680)],
                    ).createShader(bounds),
              child: Icon(_icons[index], size: 22),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                _titles[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}



