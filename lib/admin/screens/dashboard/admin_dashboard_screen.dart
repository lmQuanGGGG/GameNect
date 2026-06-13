import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/charts/daily_revenue_bar_chart.dart';
import '../../widgets/charts/monthly_revenue_line_chart.dart';
import '../../widgets/charts/yearly_revenue_bar_chart.dart';

// Màn hình thống kê doanh thu dành cho admin.
// Thiết kế theo phong cách Neo-Brutalism trắng đen chủ đạo, sử dụng màu nhấn phẳng bắt mắt.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Hàm lấy thống kê doanh thu từng ngày trong tháng đã chọn, lọc theo orderType
  Future<Map<String, dynamic>> _fetchDailyRevenueStats(int year, int month, String orderType) async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'success')
        .get();

    int totalRevenue = 0;
    int totalSold = 0;
    Map<String, int> dayRevenue = {};
    Map<String, int> daySold = {};

    for (var doc in snap.docs) {
      final data = doc.data();
      final type = data['orderType'];
      
      if (orderType == 'premium' && type != 'premium' && type != null) continue;
      if (orderType == 'coin' && type != 'coin') continue;

      final amountRaw = data['amount'];
      final int amount = amountRaw is int ? amountRaw : (amountRaw is num ? amountRaw.toInt() : 0);
      final createdAt = (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is DateTime ? data['createdAt'] as DateTime : null);
      if (createdAt == null || createdAt.year != year || createdAt.month != month) continue;

      final dayKey = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/$year';
      dayRevenue[dayKey] = (dayRevenue[dayKey] ?? 0) + amount;
      daySold[dayKey] = (daySold[dayKey] ?? 0) + 1;

      totalRevenue += amount;
      totalSold += 1;
    }

    final days = dayRevenue.keys.toList()..sort((a, b) => a.compareTo(b));
    final daily = days.map((d) => {
      'day': d,
      'revenue': dayRevenue[d]!,
      'sold': daySold[d]!,
    }).toList();

    return {
      'totalRevenue': totalRevenue,
      'totalSold': totalSold,
      'daily': daily,
    };
  }

  // Hàm lấy thống kê doanh thu từng tháng trong năm đã chọn, lọc theo orderType
  Future<List<Map<String, dynamic>>> _fetchYearlyRevenueStats(int year, String orderType) async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'success')
        .get();

    Map<int, int> monthRevenue = {}; 
    Map<int, int> monthSold = {};

    for (var doc in snap.docs) {
      final data = doc.data();
      final type = data['orderType'];
      
      if (orderType == 'premium' && type != 'premium' && type != null) continue;
      if (orderType == 'coin' && type != 'coin') continue;

      final amountRaw = data['amount'];
      final int amount = amountRaw is int ? amountRaw : (amountRaw is num ? amountRaw.toInt() : 0);
      final createdAt = (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is DateTime ? data['createdAt'] as DateTime : null);
      if (createdAt == null || createdAt.year != year) continue;

      final month = createdAt.month;
      monthRevenue[month] = (monthRevenue[month] ?? 0) + amount;
      monthSold[month] = (monthSold[month] ?? 0) + 1;
    }

    return List.generate(12, (i) {
      final m = i + 1;
      return {
        'month': m,
        'revenue': monthRevenue[m] ?? 0,
        'sold': monthSold[m] ?? 0,
      };
    });
  }

  // Hàm lấy tổng doanh thu của năm đã chọn, lọc theo orderType
  Future<Map<String, dynamic>> _fetchYearRevenue(int year, String orderType) async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'success')
        .get();

    int totalRevenue = 0;
    int totalSold = 0;

    for (var doc in snap.docs) {
      final data = doc.data();
      final type = data['orderType'];
      
      if (orderType != 'all') {
        if (orderType == 'premium' && type != 'premium' && type != null) continue;
        if (orderType == 'coin' && type != 'coin') continue;
      }

      final amountRaw = data['amount'];
      final int amount = amountRaw is int ? amountRaw : (amountRaw is num ? amountRaw.toInt() : 0);
      final createdAt = (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is DateTime ? data['createdAt'] as DateTime : null);
      if (createdAt == null || createdAt.year != year) continue;

      totalRevenue += amount;
      totalSold += 1;
    }

    return {
      'totalRevenue': totalRevenue,
      'totalSold': totalSold,
    };
  }

  List<int> _getYearList() {
    final now = DateTime.now();
    return List.generate(6, (i) => now.year - i);
  }

  List<int> _getMonthList() => List.generate(12, (i) => i + 1);

  Widget _buildStatsView(String orderType, Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchYearRevenue(selectedYear, orderType),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.black)));
            final stats = snapshot.data!;
            return _NeoStatCard(
              title: 'Doanh thu gói năm $selectedYear',
              value: '${(stats['totalRevenue'] / 1000).toStringAsFixed(3)} K VNĐ',
              icon: Icons.bar_chart_rounded,
              color: themeColor,
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchYearlyRevenueStats(selectedYear, orderType),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.black)));
            final yearly = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOANH THU NĂM $selectedYear',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                MonthlyRevenueLineChart(yearly: yearly, color: themeColor),
                const SizedBox(height: 24),
                Text(
                  'DOANH THU THÁNG $selectedMonth/$selectedYear',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                YearlyRevenueBarChart(yearly: yearly, color: themeColor),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchDailyRevenueStats(selectedYear, selectedMonth, orderType),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.black)));
            final stats = snapshot.data!;
            return _NeoStatCard(
              title: 'Doanh thu tháng $selectedMonth/$selectedYear',
              value: '${(stats['totalRevenue'] / 1000).toStringAsFixed(3)} K VNĐ',
              icon: Icons.stacked_bar_chart,
              color: themeColor,
            );
          },
        ),
        const SizedBox(height: 24),
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchDailyRevenueStats(selectedYear, selectedMonth, orderType),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.black)));
            final stats = snapshot.data!;
            final daily = stats['daily'] as List<dynamic>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHI TIẾT NGÀY THÁNG $selectedMonth/$selectedYear',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                DailyRevenueBarChart(daily: daily, color: themeColor),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  children: [
                    _buildProfileCard(user),
                    const SizedBox(height: 16),
                    _buildDateFilters(),
                    const SizedBox(height: 16),
                    // Tổng doanh thu toàn hệ thống
                    FutureBuilder<Map<String, dynamic>>(
                      future: _fetchYearRevenue(selectedYear, 'all'),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(color: Colors.black),
                            ),
                          );
                        }
                        final stats = snapshot.data!;
                        return _NeoStatCard(
                          title: 'TỔNG DOANH THU TOÀN HỆ THỐNG ($selectedYear)',
                          value: '${(stats['totalRevenue'] / 1000).toStringAsFixed(3)} K VNĐ',
                          icon: Icons.monetization_on_rounded,
                          color: const Color(0xFF64B5F6), // Xanh Brutalist
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SliverAppBar(
              pinned: true,
              floating: true,
              backgroundColor: Colors.white,
              elevation: 0,
              toolbarHeight: 0, // Ẩn phần title
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50.5),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black54,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      indicator: const BoxDecoration(color: Colors.black),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(text: 'Gói Premium'),
                        Tab(text: 'Nạp Coin'),
                      ],
                    ),
                    Container(height: 2.5, color: Colors.black),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Premium
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [_buildStatsView('premium', const Color(0xFFFFD54F))], // Vàng Brutalist
            ),
            // Tab 2: Coin
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [_buildStatsView('coin', const Color(0xFF81C784))], // Xanh lá Brutalist
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(User? user) {
    return _NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'XIN CHÀO, ADMIN!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user?.email ?? 'Admin User',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'UID: ${user?.uid ?? 'N/A'}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const Text(
          'LỌC THEO:',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 12),
        _buildDropdown<int>(
          value: selectedYear,
          items: _getYearList().map((y) => DropdownMenuItem<int>(value: y, child: Text('Năm $y'))).toList(),
          onChanged: (y) { if (y != null) setState(() => selectedYear = y); },
        ),
        const SizedBox(width: 10),
        _buildDropdown<int>(
          value: selectedMonth,
          items: _getMonthList().map((m) => DropdownMenuItem<int>(value: m, child: Text('Tháng $m'))).toList(),
          onChanged: (m) { if (m != null) setState(() => selectedMonth = m); },
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black, size: 20),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _NeoCard extends StatelessWidget {
  final Widget child;
  const _NeoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _NeoStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _NeoStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.black, width: 2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
