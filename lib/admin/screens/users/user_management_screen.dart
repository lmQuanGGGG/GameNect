import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/profile_card.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/cdn_helper.dart';
import 'admin_test_users_screen.dart';

enum Timeframe { day, week, month, quarter, year }

// Màn hình quản lý người dùng dành cho admin.
// Giao diện Neo-Brutalism nền trắng, chữ đen chủ đạo.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // Biến lưu nội dung tìm kiếm theo tên người dùng.
  String _searchText = '';

  // Chu kỳ thời gian đang chọn
  Timeframe _selectedTimeframe = Timeframe.week;

  // Năm đang chọn để thống kê
  int _selectedYear = DateTime.now().year;

  DateTime? _parseCreatedAt(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  void _navigateToDetail(Map<String, dynamic> user, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Theme(
          data: ThemeData.light(),
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                user['username'] ?? 'Chưa đặt tên',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: Colors.black, height: 1.5),
              ),
            ),
            backgroundColor: Colors.white,
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ProfileCard(user: UserModel.fromMap(user, userId)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
        title: const Text(
          'Xóa người dùng',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Bạn có chắc muốn xóa người dùng này khỏi hệ thống? Hành động này không thể hoàn tác.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Hủy',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350),
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
              ],
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Xóa',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa người dùng thành công.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa người dùng: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user, String userId) {
    int currentCoins = (user['coinBalance'] ?? 0) as int;
    bool isPremium = user['isPremium'] == true;
    final coinController = TextEditingController(text: currentCoins.toString());
    final reasonController = TextEditingController();
    final premiumDaysController = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.black, width: 2.5),
              ),
              title: const Text(
                'Cập nhật tài khoản',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: coinController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: 'Số Coin',
                        labelStyle: TextStyle(color: Colors.black54),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.5)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: 'Lý do cập nhật',
                        labelStyle: TextStyle(color: Colors.black54),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.5)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Premium Status', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      value: isPremium,
                      activeColor: const Color(0xFFFF6E40),
                      onChanged: (val) {
                        setState(() {
                          isPremium = val;
                        });
                      },
                    ),
                    if (isPremium) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: premiumDaysController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          labelText: 'Số ngày Premium',
                          labelStyle: TextStyle(color: Colors.black54),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF81C784),
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5))],
                  ),
                  child: TextButton(
                    onPressed: () async {
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập lý do cập nhật!'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final newCoins = int.tryParse(coinController.text) ?? currentCoins;
                      final premiumDays = int.tryParse(premiumDaysController.text) ?? 30;

                      try {
                        final updates = <String, dynamic>{
                          'coinBalance': newCoins,
                          'isPremium': isPremium,
                        };
                        
                        DateTime? endDate;
                        if (isPremium) {
                          endDate = DateTime.now().add(Duration(days: premiumDays));
                          updates['subscriptionEndDate'] = endDate.toIso8601String();
                          updates['subscriptionTier'] = 'monthly';
                          if (user['premiumStartDate'] == null) {
                            updates['premiumStartDate'] = DateTime.now().toIso8601String();
                          }
                        } else {
                          updates['subscriptionTier'] = 'free';
                        }
                        
                        await FirebaseFirestore.instance.collection('users').doc(userId).update(updates);
                        
                        final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_admin';
                        await FirebaseFirestore.instance.collection('transactions').add({
                          'userId': userId,
                          'adminId': adminId,
                          'type': 'admin_update',
                          'reason': reasonController.text.trim(),
                          'oldCoins': currentCoins,
                          'newCoins': newCoins,
                          'coinDiff': newCoins - currentCoins,
                          'isPremium': isPremium,
                          'premiumDaysAdded': isPremium ? premiumDays : 0,
                          'endDate': endDate?.toIso8601String(),
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cập nhật tài khoản & ghi log thành công!'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Lưu', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                ],
              ),
              child: TextField(
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm theo tên...',
                  hintStyle: TextStyle(color: Colors.black54),
                  prefixIcon: Icon(Icons.search, color: Colors.black),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value.trim().toLowerCase();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminTestUsersScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF176), // Vàng neon
                border: Border.all(color: Colors.black, width: 2.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                ],
              ),
              child: const Icon(
                Icons.manage_accounts_outlined,
                color: Colors.black,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards({
    required String label1,
    required String label2,
    required String label3,
    required int val1,
    required int val2,
    required int val3,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildSingleStatCard(
              title: label1,
              value: '$val1',
              color: const Color(0xFFFF7043), // Cam neon
              textColor: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSingleStatCard(
              title: label2,
              value: '$val2',
              color: const Color(0xFF81C784), // Xanh lá neon
              textColor: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSingleStatCard(
              title: label3,
              value: '$val3',
              color: const Color(0xFF4EEAF6), // Cyan neon
              textColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleStatCard({
    required String title,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: textColor.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user, String userId) {
    final isAdmin = user['isAdmin'] == true;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: GestureDetector(
          onTap: () => _navigateToDetail(user, userId),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5)),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundImage: cdnImageProvider(user['avatarUrl']),
              backgroundColor: Colors.grey.shade100,
            ),
          ),
        ),
        title: GestureDetector(
          onTap: () => _navigateToDetail(user, userId),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  user['username'] ?? 'Chưa đặt tên',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF176),
                    border: Border.all(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            user['email'] ?? 'Không có email',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4EEAF6),
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.visibility_outlined,
                  color: Colors.black,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _navigateToDetail(user, userId),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF176),
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.black,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _showEditUserDialog(user, userId),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350),
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _deleteUser(userId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ── TRÍCH XUẤT VÀ TÍNH TOÁN THỐNG KÊ ──
                final currentNow = DateTime.now();
                final now = DateTime(
                  _selectedYear,
                  currentNow.month,
                  (currentNow.month == 2 && currentNow.day == 29 && !(_selectedYear % 4 == 0 && (_selectedYear % 100 != 0 || _selectedYear % 400 == 0))) ? 28 : currentNow.day,
                  currentNow.hour,
                  currentNow.minute,
                  currentNow.second,
                );
                final startOfToday = DateTime(now.year, now.month, now.day);

                String statLabel1 = 'MỚI HÔM NAY';
                String statLabel2 = 'MỚI TUẦN NÀY';
                String statLabel3 = 'TỔNG USER';

                int statVal1 = 0;
                int statVal2 = 0;
                int statVal3 = snapshot.data!.docs.length;

                final Map<String, int> chartData = {};

                // Tính toán theo bộ chọn Timeframe
                if (_selectedTimeframe == Timeframe.day) {
                  final intervals = [
                    '0-3h',
                    '3-6h',
                    '6-9h',
                    '9-12h',
                    '12-15h',
                    '15-18h',
                    '18-21h',
                    '21-24h',
                  ];
                  for (var interval in intervals) {
                    chartData[interval] = 0;
                  }

                  statLabel1 = 'MỚI HÔM NAY';
                  statLabel2 = 'MỚI HÔM QUA';

                  final startOfYesterday = startOfToday.subtract(
                    const Duration(days: 1),
                  );

                  for (var doc in snapshot.data!.docs) {
                    final user = doc.data() as Map<String, dynamic>;
                    final createdAt = _parseCreatedAt(user['createdAt']);
                    if (createdAt != null) {
                      if (createdAt.year == now.year &&
                          createdAt.month == now.month &&
                          createdAt.day == now.day) {
                        statVal1++;
                        final hour = createdAt.hour;
                        final intervalIdx = (hour / 3).floor();
                        if (intervalIdx >= 0 && intervalIdx < 8) {
                          chartData[intervals[intervalIdx]] =
                              chartData[intervals[intervalIdx]]! + 1;
                        }
                      }
                      if (createdAt.year == startOfYesterday.year &&
                          createdAt.month == startOfYesterday.month &&
                          createdAt.day == startOfYesterday.day) {
                        statVal2++;
                      }
                    }
                  }
                } else if (_selectedTimeframe == Timeframe.week) {
                  final weekday = now.weekday;
                  final startOfWeek = startOfToday.subtract(
                    Duration(days: weekday - 1),
                  );
                  final endOfWeek = startOfWeek.add(const Duration(days: 7));
                  final List<DateTime> weekDays = List.generate(7, (index) {
                    return startOfWeek.add(Duration(days: index));
                  });
                  final weekLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                  for (var label in weekLabels) {
                    chartData[label] = 0;
                  }

                  statLabel1 = 'MỚI HÔM NAY';
                  statLabel2 = 'MỚI TUẦN NÀY';

                  for (var doc in snapshot.data!.docs) {
                    final user = doc.data() as Map<String, dynamic>;
                    final createdAt = _parseCreatedAt(user['createdAt']);
                    if (createdAt != null) {
                      if (createdAt.year == now.year &&
                          createdAt.month == now.month &&
                          createdAt.day == now.day) {
                        statVal1++;
                      }
                      final isInWeek = (createdAt.isAfter(startOfWeek) ||
                          (createdAt.year == startOfWeek.year &&
                              createdAt.month == startOfWeek.month &&
                              createdAt.day == startOfWeek.day)) && createdAt.isBefore(endOfWeek);
                      if (isInWeek) {
                        statVal2++;
                        for (int i = 0; i < 7; i++) {
                          final day = weekDays[i];
                          if (createdAt.year == day.year &&
                              createdAt.month == day.month &&
                              createdAt.day == day.day) {
                            chartData[weekLabels[i]] =
                                chartData[weekLabels[i]]! + 1;
                          }
                        }
                      }
                    }
                  }
                } else if (_selectedTimeframe == Timeframe.month) {
                  final weekLabels = ['Tuần 1', 'Tuần 2', 'Tuần 3', 'Tuần 4'];
                  for (var label in weekLabels) {
                    chartData[label] = 0;
                  }

                  statLabel1 = 'MỚI TUẦN NÀY';
                  statLabel2 = 'MỚI THÁNG NÀY';

                  final weekday = now.weekday;
                  final startOfWeek = startOfToday.subtract(
                    Duration(days: weekday - 1),
                  );
                  final endOfWeek = startOfWeek.add(const Duration(days: 7));

                  for (var doc in snapshot.data!.docs) {
                    final user = doc.data() as Map<String, dynamic>;
                    final createdAt = _parseCreatedAt(user['createdAt']);
                    if (createdAt != null) {
                      final isInWeek = (createdAt.isAfter(startOfWeek) ||
                          (createdAt.year == startOfWeek.year &&
                              createdAt.month == startOfWeek.month &&
                              createdAt.day == startOfWeek.day)) && createdAt.isBefore(endOfWeek);
                      if (isInWeek) {
                        statVal1++;
                      }
                      if (createdAt.year == now.year &&
                          createdAt.month == now.month) {
                        statVal2++;
                        final dayOfMonth = createdAt.day;
                        if (dayOfMonth >= 1 && dayOfMonth <= 7) {
                          chartData['Tuần 1'] = chartData['Tuần 1']! + 1;
                        } else if (dayOfMonth >= 8 && dayOfMonth <= 14) {
                          chartData['Tuần 2'] = chartData['Tuần 2']! + 1;
                        } else if (dayOfMonth >= 15 && dayOfMonth <= 21) {
                          chartData['Tuần 3'] = chartData['Tuần 3']! + 1;
                        } else {
                          chartData['Tuần 4'] = chartData['Tuần 4']! + 1;
                        }
                      }
                    }
                  }
                } else if (_selectedTimeframe == Timeframe.quarter) {
                  final quarter = ((now.month - 1) / 3).floor() + 1;
                  final startMonth = (quarter - 1) * 3 + 1;
                  final quarterLabels = [
                    'Tháng $startMonth',
                    'Tháng ${startMonth + 1}',
                    'Tháng ${startMonth + 2}',
                  ];
                  for (var label in quarterLabels) {
                    chartData[label] = 0;
                  }

                  statLabel1 = 'MỚI THÁNG NÀY';
                  statLabel2 = 'MỚI QUÝ NÀY';

                  for (var doc in snapshot.data!.docs) {
                    final user = doc.data() as Map<String, dynamic>;
                    final createdAt = _parseCreatedAt(user['createdAt']);
                    if (createdAt != null) {
                      if (createdAt.year == now.year &&
                          createdAt.month == now.month) {
                        statVal1++;
                      }
                      if (createdAt.year == now.year &&
                          (createdAt.month == startMonth ||
                              createdAt.month == startMonth + 1 ||
                              createdAt.month == startMonth + 2)) {
                        statVal2++;
                        if (createdAt.month == startMonth) {
                          chartData[quarterLabels[0]] =
                              chartData[quarterLabels[0]]! + 1;
                        } else if (createdAt.month == startMonth + 1) {
                          chartData[quarterLabels[1]] =
                              chartData[quarterLabels[1]]! + 1;
                        } else if (createdAt.month == startMonth + 2) {
                          chartData[quarterLabels[2]] =
                              chartData[quarterLabels[2]]! + 1;
                        }
                      }
                    }
                  }
                } else if (_selectedTimeframe == Timeframe.year) {
                  final yearLabels = [
                    'T1',
                    'T2',
                    'T3',
                    'T4',
                    'T5',
                    'T6',
                    'T7',
                    'T8',
                    'T9',
                    'T10',
                    'T11',
                    'T12',
                  ];
                  for (var label in yearLabels) {
                    chartData[label] = 0;
                  }

                  final quarter = ((now.month - 1) / 3).floor() + 1;
                  final startMonth = (quarter - 1) * 3 + 1;

                  statLabel1 = 'MỚI QUÝ NÀY';
                  statLabel2 = 'MỚI NĂM NÀY';

                  for (var doc in snapshot.data!.docs) {
                    final user = doc.data() as Map<String, dynamic>;
                    final createdAt = _parseCreatedAt(user['createdAt']);
                    if (createdAt != null) {
                      if (createdAt.year == now.year &&
                          (createdAt.month == startMonth ||
                              createdAt.month == startMonth + 1 ||
                              createdAt.month == startMonth + 2)) {
                        statVal1++;
                      }
                      if (createdAt.year == now.year) {
                        statVal2++;
                        final monthIdx = createdAt.month - 1;
                        if (monthIdx >= 0 && monthIdx < 12) {
                          chartData[yearLabels[monthIdx]] =
                              chartData[yearLabels[monthIdx]]! + 1;
                        }
                      }
                    }
                  }
                }

                // Lọc danh sách người dùng theo ô tìm kiếm
                final filteredUsers = snapshot.data!.docs.where((doc) {
                  final user = doc.data() as Map<String, dynamic>;
                  final username = (user['username'] ?? '')
                      .toString()
                      .toLowerCase();
                  return _searchText.isEmpty || username.contains(_searchText);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return ListView(
                    children: [
                      _buildStatCards(
                        label1: statLabel1,
                        label2: statLabel2,
                        label3: statLabel3,
                        val1: statVal1,
                        val2: statVal2,
                        val3: statVal3,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: NeoGrowthChart(
                          data: chartData,
                          selectedTimeframe: _selectedTimeframe,
                          onTimeframeChanged: (tf) {
                            setState(() {
                              _selectedTimeframe = tf;
                            });
                          },
                          selectedYear: _selectedYear,
                          onYearChanged: (y) {
                            setState(() {
                              _selectedYear = y;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Center(
                        child: Text(
                          'Không tìm thấy người dùng nào phù hợp.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length + 2,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildStatCards(
                        label1: statLabel1,
                        label2: statLabel2,
                        label3: statLabel3,
                        val1: statVal1,
                        val2: statVal2,
                        val3: statVal3,
                      );
                    }
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: NeoGrowthChart(
                          data: chartData,
                          selectedTimeframe: _selectedTimeframe,
                          onTimeframeChanged: (tf) {
                            setState(() {
                              _selectedTimeframe = tf;
                            });
                          },
                          selectedYear: _selectedYear,
                          onYearChanged: (y) {
                            setState(() {
                              _selectedYear = y;
                            });
                          },
                        ),
                      );
                    }

                    final userIndex = index - 2;
                    final user =
                        filteredUsers[userIndex].data() as Map<String, dynamic>;
                    final userId = filteredUsers[userIndex].id;

                    return _buildUserListItem(user, userId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NeoGrowthChart extends StatelessWidget {
  final Map<String, int> data;
  final Timeframe selectedTimeframe;
  final ValueChanged<Timeframe> onTimeframeChanged;
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  const NeoGrowthChart({
    super.key,
    required this.data,
    required this.selectedTimeframe,
    required this.onTimeframeChanged,
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    int maxVal = 0;
    data.forEach((key, val) {
      if (val > maxVal) maxVal = val;
    });
    if (maxVal == 0) maxVal = 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề & Max Value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.black, size: 20),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'BIỂU ĐỒ TĂNG TRƯỞNG',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                children: [
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedYear,
                        dropdownColor: Colors.white,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.black, size: 16),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                        items: List.generate(6, (i) => DateTime.now().year - i)
                            .map((y) => DropdownMenuItem<int>(
                                  value: y,
                                  child: Text('Năm $y'),
                                ))
                            .toList(),
                        onChanged: (y) {
                          if (y != null) onYearChanged(y);
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Max: $maxVal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bộ chọn Timeframe (Timeframe Selector) Neo-Brutalism
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: Timeframe.values.map((tf) {
                final isSelected = selectedTimeframe == tf;
                String label = '';
                switch (tf) {
                  case Timeframe.day:
                    label = 'Ngày';
                    break;
                  case Timeframe.week:
                    label = 'Tuần';
                    break;
                  case Timeframe.month:
                    label = 'Tháng';
                    break;
                  case Timeframe.quarter:
                    label = 'Quý';
                    break;
                  case Timeframe.year:
                    label = 'Năm';
                    break;
                }

                return GestureDetector(
                  onTap: () => onTimeframeChanged(tf),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      border: Border.all(color: Colors.black, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? const [
                              BoxShadow(
                                color: Colors.black12,
                                offset: Offset(1.5, 1.5),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Vẽ cột của biểu đồ
          SizedBox(
            height: 140, // Tăng chiều cao lên 140px để tránh vỡ layout
            child: Stack(
              children: [
                // Đường kẻ ngang lưới
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    return Container(
                      height: 1,
                      color: Colors.black.withValues(alpha: 0.06),
                    );
                  }),
                ),

                // Các cột dữ liệu vẽ song song
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: data.entries.map((entry) {
                    final label = entry.key;
                    final val = entry.value;

                    // Giới hạn chiều cao cột tối đa là 85px
                    final double height = (val / maxVal) * 85;

                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Giá trị cột bọc FittedBox tránh lỗi tràn chữ
                          SizedBox(
                            height: 16,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$val',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Thân cột
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              height: height < 6 ? 6 : height,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: val > 0
                                    ? const Color(0xFFFFF176)
                                    : Colors
                                          .grey
                                          .shade200, // Vàng neon khi có dữ liệu, xám nhạt khi 0
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: val > 0
                                    ? const [
                                        BoxShadow(
                                          color: Colors.black,
                                          offset: Offset(1.5, 1.5),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Nhãn ngày bọc FittedBox tránh tràn ngang
                          SizedBox(
                            height: 14,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
