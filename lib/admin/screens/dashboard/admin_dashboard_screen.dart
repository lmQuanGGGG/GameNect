import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/charts/daily_revenue_bar_chart.dart';
import '../../widgets/charts/monthly_revenue_line_chart.dart';
import '../../widgets/charts/yearly_revenue_bar_chart.dart';

// Màn hình thống kê doanh thu dành cho admin.
// Cho phép admin chọn năm, tháng để xem doanh thu theo từng khoảng thời gian.
// Hiển thị tổng doanh thu năm, tổng doanh thu tháng, biểu đồ doanh thu theo tháng và theo ngày.
// Dữ liệu doanh thu được lấy từ Firestore collection 'orders' với điều kiện status = 'success'.

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Biến lưu năm và tháng đang chọn để lọc doanh thu.
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  // Hàm lấy thống kê doanh thu từng ngày trong tháng đã chọn.
  // Trả về tổng doanh thu, tổng số gói bán ra và danh sách doanh thu từng ngày.
  Future<Map<String, dynamic>> _fetchDailyRevenueStats(int year, int month) async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'success')
        .get();

    int totalRevenue = 0;
    int totalSold = 0;
    Map<String, int> dayRevenue = {};
    Map<String, int> daySold = {};

    // Duyệt qua từng đơn hàng, lọc theo năm và tháng đã chọn.
    for (var doc in snap.docs) {
      final data = doc.data();
      final amountRaw = data['amount'];
      final int amount = amountRaw is int ? amountRaw : (amountRaw is num ? amountRaw.toInt() : 0);
      final createdAt = (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is DateTime ? data['createdAt'] as DateTime : null);
      if (createdAt == null || createdAt.year != year || createdAt.month != month) continue;

      // Tạo key ngày dạng dd/MM/yyyy để lưu doanh thu từng ngày.
      final dayKey = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/$year';
      dayRevenue[dayKey] = (dayRevenue[dayKey] ?? 0) + amount;
      daySold[dayKey] = (daySold[dayKey] ?? 0) + 1;

      totalRevenue += amount;
      totalSold += 1;
    }

    // Sắp xếp danh sách ngày tăng dần để hiển thị biểu đồ đúng thứ tự.
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

  // Hàm lấy thống kê doanh thu từng tháng trong năm đã chọn.
  // Trả về danh sách doanh thu và số lượng gói bán ra của từng tháng.
  Future<List<Map<String, dynamic>>> _fetchYearlyRevenueStats(int year) async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'success')
        .get();

    Map<int, int> monthRevenue = {}; // key: tháng, value: doanh thu
    Map<int, int> monthSold = {};

    // Duyệt qua từng đơn hàng, lọc theo năm đã chọn.
    for (var doc in snap.docs) {
      final data = doc.data();
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

    // Đảm bảo danh sách đủ 12 tháng, nếu tháng nào không có doanh thu thì gán bằng 0.
    return List.generate(12, (i) {
      final m = i + 1;
      return {
        'month': m,
        'revenue': monthRevenue[m] ?? 0,
        'sold': monthSold[m] ?? 0,
      };
    });
  }

  // Hàm lấy tổng doanh thu của năm đã chọn.
  // Trả về tổng doanh thu và tổng số gói bán ra trong năm.
  Future<Map<String, dynamic>> _fetchYearRevenue(int year) async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'success')
        .get();

    int totalRevenue = 0;
    int totalSold = 0;

    // Duyệt qua từng đơn hàng, lọc theo năm đã chọn.
    for (var doc in snap.docs) {
      final data = doc.data();
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

  // Hàm trả về danh sách các năm để chọn lọc doanh thu.
  // Mặc định lấy 6 năm gần nhất kể từ năm hiện tại.
  List<int> _getYearList() {
    final now = DateTime.now();
    return List.generate(6, (i) => now.year - i);
  }

  // Hàm trả về danh sách các tháng để chọn lọc doanh thu.
  // Mặc định lấy đủ 12 tháng trong năm.
  List<int> _getMonthList() => List.generate(12, (i) => i + 1);

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin user hiện tại đang đăng nhập để hiển thị trên dashboard.
    final user = FirebaseAuth.instance.currentUser;

    return Stack(
      children: [
        // Tạo nền gradient cho toàn bộ màn hình dashboard.
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF232526), Color(0xFF181A20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Thẻ hiển thị thông tin admin đang đăng nhập, gồm tên, email, UID.
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào, Admin!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange.shade200,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? 'Admin User',
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'UID: ${user?.uid ?? 'N/A'}',
                          style: const TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Dropdown chọn năm và tháng để lọc doanh thu.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Năm:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        dropdownColor: Colors.black87,
                        value: selectedYear,
                        style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                        items: _getYearList()
                            .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y')))
                            .toList(),
                        onChanged: (y) {
                          if (y != null) setState(() => selectedYear = y);
                        },
                      ),
                      const SizedBox(width: 16),
                      const Text('Tháng:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        dropdownColor: Colors.black87,
                        value: selectedMonth,
                        style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                        items: _getMonthList()
                            .map((m) => DropdownMenuItem<int>(value: m, child: Text('$m')))
                            .toList(),
                        onChanged: (m) {
                          if (m != null) setState(() => selectedMonth = m);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Hiển thị tổng doanh thu năm đã chọn bằng thẻ GlassStatCard.
                  FutureBuilder<Map<String, dynamic>>(
                    future: _fetchYearRevenue(selectedYear),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final stats = snapshot.data!;
                      return _GlassStatCard(
                        title: 'Tổng doanh thu năm $selectedYear',
                        value: '${(stats['totalRevenue'] / 1000).toStringAsFixed(3)} K VNĐ',
                        icon: Icons.bar_chart_rounded,
                        color: Colors.deepOrange,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Hiển thị biểu đồ doanh thu theo tháng trong năm đã chọn.
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchYearlyRevenueStats(selectedYear),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final yearly = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            'Thống kê doanh thu năm $selectedYear',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          MonthlyRevenueLineChart(yearly: yearly), // Biểu đồ đường doanh thu theo tháng
                          const SizedBox(height: 24),
                          Text(
                            'Thống kê doanh thu tháng $selectedMonth/$selectedYear',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          YearlyRevenueBarChart(yearly: yearly), // Biểu đồ cột doanh thu theo tháng
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Hiển thị tổng doanh thu của tháng đã chọn bằng thẻ GlassStatCard.
                  FutureBuilder<Map<String, dynamic>>(
                    future: _fetchDailyRevenueStats(selectedYear, selectedMonth),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final stats = snapshot.data!;
                      return _GlassStatCard(
                        title: 'Tổng doanh thu tháng $selectedMonth/$selectedYear',
                        value: '${(stats['totalRevenue'] / 1000).toStringAsFixed(3)} K VNĐ',
                        icon: Icons.stacked_bar_chart,
                        color: Colors.orange,
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // Hiển thị biểu đồ doanh thu từng ngày trong tháng đã chọn.
                  FutureBuilder<Map<String, dynamic>>(
                    future: _fetchDailyRevenueStats(selectedYear, selectedMonth),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final stats = snapshot.data!;
                      final daily = stats['daily'] as List<dynamic>;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doanh thu từng ngày tháng $selectedMonth/$selectedYear',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DailyRevenueBarChart(daily: daily), // Biểu đồ cột doanh thu từng ngày
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Widget thẻ nền kính (glassmorphism) dùng để bọc nội dung trên dashboard.
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
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.deepOrange.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}

// Widget thẻ thống kê có icon, tiêu đề và giá trị.
class _GlassStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _GlassStatCard({
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
