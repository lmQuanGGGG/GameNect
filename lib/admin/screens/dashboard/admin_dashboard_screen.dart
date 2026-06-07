import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/charts/daily_revenue_bar_chart.dart';
import '../../widgets/charts/monthly_revenue_line_chart.dart';
import '../../widgets/charts/yearly_revenue_bar_chart.dart';

// Màn hình thống kê doanh thu dành cho admin.
// Cho phép admin chọn năm, tháng để xem doanh thu theo từng khoảng thời gian.
// Tách biệt thống kê Gói Premium và Nạp Coin ra 2 tab riêng.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  // Biến lưu năm và tháng đang chọn để lọc doanh thu.
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
      
      // Lọc theo orderType. Nếu type null, mặc định coi là premium (dữ liệu cũ).
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
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchYearRevenue(selectedYear, orderType),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            final stats = snapshot.data!;
            return _GlassStatCard(
              title: 'Tổng doanh thu năm $selectedYear',
              value: '${(stats['totalRevenue'] / 1000).toStringAsFixed(3)} K VNĐ',
              icon: Icons.bar_chart_rounded,
              color: themeColor,
            );
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchYearlyRevenueStats(selectedYear, orderType),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            final yearly = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Thống kê doanh thu năm $selectedYear',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                MonthlyRevenueLineChart(yearly: yearly, color: themeColor),
                const SizedBox(height: 24),
                Text(
                  'Thống kê doanh thu tháng $selectedMonth/$selectedYear',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                YearlyRevenueBarChart(yearly: yearly, color: themeColor),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchDailyRevenueStats(selectedYear, selectedMonth, orderType),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            final stats = snapshot.data!;
            return _GlassStatCard(
              title: 'Tổng doanh thu tháng $selectedMonth/$selectedYear',
              value: '${(stats['totalRevenue'] / 1000).toStringAsFixed(3)} K VNĐ',
              icon: Icons.stacked_bar_chart,
              color: themeColor,
            );
          },
        ),
        const SizedBox(height: 32),
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchDailyRevenueStats(selectedYear, selectedMonth, orderType),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            final stats = snapshot.data!;
            final daily = stats['daily'] as List<dynamic>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doanh thu từng ngày tháng $selectedMonth/$selectedYear',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const SizedBox(height: 12),
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

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF232526), Color(0xFF181A20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                  child: Column(
                    children: [
                      _buildProfileCard(user),
                      const SizedBox(height: 16),
                      _buildDateFilters(),
                      const SizedBox(height: 12),
                      // Tổng doanh thu toàn hệ thống
                      FutureBuilder<Map<String, dynamic>>(
                        future: _fetchYearRevenue(selectedYear, 'all'),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()));
                          final stats = snapshot.data!;
                          return _GlassStatCard(
                            title: 'TỔNG DOANH THU TOÀN HỆ THỐNG ($selectedYear)',
                            value: '${(stats['totalRevenue'] / 1000).toStringAsFixed(3)} K VNĐ',
                            icon: Icons.monetization_on_rounded,
                            color: Colors.greenAccent,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverAppBar(
                pinned: true,
                floating: true,
                backgroundColor: const Color(0xFF181A20), // Trùng màu nền
                elevation: 0,
                toolbarHeight: 0, // Ẩn phần title của AppBar
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: Colors.deepOrange,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.deepOrange,
                  tabs: const [
                    Tab(text: 'Gói Premium'),
                    Tab(text: 'Nạp Coin'),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Premium
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [_buildStatsView('premium', Colors.deepOrange)],
              ),
              // Tab 2: Coin
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [_buildStatsView('coin', Colors.amber)],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(User? user) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào, Admin!',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade200, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Text(user?.email ?? 'Admin User', style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 4),
          Text('UID: ${user?.uid ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('Năm:', style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(width: 8),
        DropdownButton<int>(
          dropdownColor: Colors.black87,
          value: selectedYear,
          style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
          items: _getYearList().map((y) => DropdownMenuItem<int>(value: y, child: Text('$y'))).toList(),
          onChanged: (y) { if (y != null) setState(() => selectedYear = y); },
        ),
        const SizedBox(width: 16),
        const Text('Tháng:', style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(width: 8),
        DropdownButton<int>(
          dropdownColor: Colors.black87,
          value: selectedMonth,
          style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
          items: _getMonthList().map((m) => DropdownMenuItem<int>(value: m, child: Text('$m'))).toList(),
          onChanged: (m) { if (m != null) setState(() => selectedMonth = m); },
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.deepOrange.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.18), width: 1.2),
      ),
      child: child,
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _GlassStatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))],
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(width: 18),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
