import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../scripts/create_test_users.dart';
import '../../../core/widgets/profile_card.dart';
import '../../../core/models/user_model.dart';

// Màn hình admin để tạo và quản lý test users
// Giao diện Neo-Brutalism nền trắng, chữ đen chủ đạo.
class AdminTestUsersScreen extends StatefulWidget {
  const AdminTestUsersScreen({super.key});

  @override
  State<AdminTestUsersScreen> createState() => _AdminTestUsersScreenState();
}

// Tab lọc danh sách: test users thuần hoặc hybrid users
enum _ListTab { test, hybrid }

class _AdminTestUsersScreenState extends State<AdminTestUsersScreen> {
  final CreateTestUsers _createTestUsers = CreateTestUsers();
  final TextEditingController _countController = TextEditingController(
    text: '100',
  );

  bool _isCreating = false;
  List<Map<String, dynamic>> _createdUsers = [];
  String _statusMessage = '';
  String _searchText = '';
  _ListTab _selectedTab = _ListTab.test;

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  // Xử lý tạo nhiều test users cùng lúc
  Future<void> _handleCreateUsers() async {
    final count = int.tryParse(_countController.text) ?? 0;

    if (count <= 0 || count > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số lượng từ 1 đến 500'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
      _statusMessage = 'Đang tạo $count users...';
      _createdUsers = [];
    });

    try {
      final users = await _createTestUsers.createMultipleUsers(count);

      setState(() {
        _createdUsers = users;
        _statusMessage = 'Đã tạo thành công ${users.length}/$count users';
        _isCreating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tạo thành công ${users.length} users!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi: $e';
        _isCreating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Xóa tất cả test users đuôi @gamenect.com hoặc bắt đầu bằng 'testuser'
  Future<void> _handleDeleteTestUsers() async {
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
        content: const Text(
          'Bạn có chắc muốn xóa tất cả test users có email bắt đầu bằng "testuser" hoặc đuôi @gamenect.com? Hành động này không thể hoàn tác.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.black)),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350),
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Xóa tất cả',
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

    if (confirm != true) return;

    setState(() {
      _isCreating = true;
      _statusMessage = 'Đang xóa test users...';
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('isTestAccount', isEqualTo: true)
          .get();

      int deletedCount = 0;
      for (final doc in snap.docs) {
        final email = (doc.data()['email'] ?? '').toString().toLowerCase();
        if (email.endsWith('@gamenect.com') || email.startsWith('testuser')) {
          await doc.reference.delete();
          deletedCount++;
        }
      }

      setState(() {
        _createdUsers = [];
        _statusMessage =
            'Đã xóa thành công $deletedCount test users (bắt đầu bằng "testuser" hoặc đuôi @gamenect.com)';
        _isCreating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa thành công $deletedCount test users!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi: $e';
        _isCreating = false;
      });
    }
  }

  // Xóa từng test user một
  Future<void> _deleteSingleUser(String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
        title: const Text(
          'Xóa test user',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Bạn có chắc muốn xóa test user "$email"?',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.black)),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350),
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(8),
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

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa test user thành công.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Copy danh sách users vào clipboard
  void _copyUsersList() {
    if (_createdUsers.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('Email | Password | Tên | Thành phố | Games');
    buffer.writeln('-' * 80);

    for (var user in _createdUsers) {
      buffer.writeln(
        '${user['email']} | ${user['password']} | ${user['displayName']} | ${user['city']} | ${user['games'].join(', ')}',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã copy danh sách users!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Điều hướng đến trang profile của hybrid user
  void _navigateToProfile(Map<String, dynamic> data, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Theme(
          data: ThemeData.light(),
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                data['username'] ?? 'Chưa đặt tên',
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
                child: ProfileCard(user: UserModel.fromMap(data, userId)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
      ),
      child: TextField(
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: _selectedTab == _ListTab.test
              ? 'Tìm kiếm test user theo tên hoặc email...'
              : 'Tìm kiếm hybrid user theo tên hoặc email...',
          hintStyle: const TextStyle(color: Colors.black54),
          prefixIcon: const Icon(Icons.search, color: Colors.black),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
        ),
        onChanged: (value) {
          setState(() {
            _searchText = value.trim().toLowerCase();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Tạo & Quản lý Test Users',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black, height: 1.5),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('isTestAccount', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            final allTestDocs = snapshot.hasData ? snapshot.data!.docs : [];

            // ── TEST USERS: email bắt đầu testuser VÀ đuôi @gamenect.com ──
            final gamenectTestUsers = allTestDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final email = (data['email'] ?? '').toString().toLowerCase();
              return email.endsWith('@gamenect.com') &&
                  email.contains('testuser');
            }).toList();

            final totalGamenectTestCount = gamenectTestUsers.length;

            // ── HYBRID USERS: tạo từ 10/2025 - 03/2026, KHÔNG phải testuser/gamenect.com ──
            bool isHybridDoc(dynamic docRaw) {
              final doc = docRaw as QueryDocumentSnapshot;
              final data = doc.data() as Map<String, dynamic>;
              final email = (data['email'] ?? '').toString().toLowerCase();
              // Loại trừ testuser* hoặc *@gamenect.com
              if (email.startsWith('testuser') ||
                  email.endsWith('@gamenect.com')) {
                return false;
              }
              // Phải được tạo từ 10/2025 đến 03/2026
              final createdAt = data['createdAt'];
              if (createdAt == null) return false;
              DateTime? dt;
              if (createdAt is Timestamp) {
                dt = createdAt.toDate();
              } else if (createdAt is String) {
                dt = DateTime.tryParse(createdAt);
              }
              if (dt == null) return false;
              
              if (dt.year == 2025 && dt.month >= 10) return true;
              if (dt.year == 2026) {
                if (dt.month <= 2) return true;
                if (dt.month == 3 && dt.day <= 12) return true; // Lấy 40% của tháng 3 (từ mùng 1 đến 12)
              }
              return false;
            }

            final hybridUsers = allTestDocs.where(isHybridDoc).toList();
            final hybridCount = hybridUsers.length;

            // ── Lọc theo tab đang chọn + search text ──
            final activeList = _selectedTab == _ListTab.test
                ? gamenectTestUsers
                : hybridUsers;

            final filteredList = activeList.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final username =
                  (data['username'] ?? '').toString().toLowerCase();
              final email = (data['email'] ?? '').toString().toLowerCase();
              return _searchText.isEmpty ||
                  username.contains(_searchText) ||
                  email.contains(_searchText);
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Card Hướng dẫn ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2.5),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.black),
                          SizedBox(width: 8),
                          Text(
                            'THÔNG TIN HƯỚNG DẪN',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Password mặc định: Test@123\n'
                        '• Định dạng email tạo mới: testuserXXX@gamenect.com\n'
                        '• Các tài khoản được đánh dấu isTestAccount = true\n'
                        '• Tự động chọn 1-3 game và vị trí ngẫu nhiên tại Việt Nam',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Thống kê: 2 thẻ bấm được để lọc danh sách ──
                Row(
                  children: [
                    // Thẻ TEST USERS
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedTab = _ListTab.test;
                          _searchText = '';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedTab == _ListTab.test
                                ? const Color(0xFFFFF176) // Vàng neon - active
                                : const Color(0xFFFAFAFA), // Xám nhạt - inactive
                            border: Border.all(
                              color: Colors.black,
                              width: _selectedTab == _ListTab.test ? 3 : 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black,
                                offset: _selectedTab == _ListTab.test
                                    ? const Offset(4, 4)
                                    : const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_alt_outlined,
                                color: _selectedTab == _ListTab.test
                                    ? Colors.black
                                    : Colors.black38,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TEST USERS',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: _selectedTab == _ListTab.test
                                            ? Colors.black54
                                            : Colors.black26,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$totalGamenectTestCount',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: _selectedTab == _ListTab.test
                                            ? Colors.black
                                            : Colors.black38,
                                      ),
                                    ),
                                    Text(
                                      'Đang hoạt động',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _selectedTab == _ListTab.test
                                            ? Colors.black54
                                            : Colors.black26,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedTab == _ListTab.test)
                                const Icon(
                                  Icons.arrow_downward,
                                  size: 14,
                                  color: Colors.black54,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Thẻ HYBRID USERS
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedTab = _ListTab.hybrid;
                          _searchText = '';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedTab == _ListTab.hybrid
                                ? const Color(0xFFB2EBF2) // Xanh neon - active
                                : const Color(0xFFFAFAFA),
                            border: Border.all(
                              color: Colors.black,
                              width: _selectedTab == _ListTab.hybrid ? 3 : 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black,
                                offset: _selectedTab == _ListTab.hybrid
                                    ? const Offset(4, 4)
                                    : const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.merge_type,
                                color: _selectedTab == _ListTab.hybrid
                                    ? Colors.black
                                    : Colors.black38,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'HYBRID USERS',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: _selectedTab == _ListTab.hybrid
                                            ? Colors.black54
                                            : Colors.black26,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$hybridCount',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: _selectedTab == _ListTab.hybrid
                                            ? Colors.black
                                            : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedTab == _ListTab.hybrid)
                                const Icon(
                                  Icons.arrow_downward,
                                  size: 14,
                                  color: Colors.black54,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Nhập Số lượng & Nút bấm ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Số lượng users cần tạo',
                      labelStyle: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                      prefixIcon: Icon(Icons.group_add, color: Colors.black),
                      border: InputBorder.none,
                    ),
                    enabled: !_isCreating,
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    // Nút Tạo Users
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7043), // Cam neon
                          border: Border.all(color: Colors.black, width: 2.5),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isCreating ? null : _handleCreateUsers,
                          icon: _isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.white,
                                ),
                          label: Text(
                            _isCreating ? 'Đang tạo...' : 'Tạo Users',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Nút Xóa tất cả đuôi @gamenect.com
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350), // Đỏ neon
                          border: Border.all(color: Colors.black, width: 2.5),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isCreating
                              ? null
                              : _handleDeleteTestUsers,
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Xóa sạch Test Users',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Hiển thị Trạng thái ──
                if (_statusMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2.5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(1.5, 1.5),
                        ),
                      ],
                    ),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isCreating
                            ? const Color(0xFFFF7043)
                            : const Color(0xFF81C784),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // ── Danh sách Users vừa được tạo (Có nút copy) ──
                if (_createdUsers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tài khoản vừa tạo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        onPressed: _copyUsersList,
                        icon: const Icon(
                          Icons.content_copy,
                          color: Color(0xFFFF7043),
                        ),
                        tooltip: 'Copy danh sách',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _createdUsers.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Colors.black12),
                      itemBuilder: (context, index) {
                        final user = _createdUsers[index];
                        return ListTile(
                          title: Text(
                            user['displayName'] ?? '',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${user['email']}\nPass: ${user['password']}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Tiêu đề danh sách theo tab ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedTab == _ListTab.test
                            ? 'DANH SÁCH TEST USER (gamenect)'
                            : 'DANH SÁCH HYBRID USER',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (_selectedTab == _ListTab.hybrid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB2EBF2),
                          border: Border.all(color: Colors.black, width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Bấm để xem profile',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 16),

                // ── Danh sách ──
                if (!snapshot.hasData)
                  const Center(child: CircularProgressIndicator())
                else if (filteredList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        _selectedTab == _ListTab.test
                            ? 'Không tìm thấy test user nào phù hợp.'
                            : 'Không tìm thấy hybrid user nào phù hợp.',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final doc = filteredList[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final userId = doc.id;
                      final email = data['email'] ?? '';
                      final displayName = data['username'] ?? 'Không tên';
                      final city = data['city'] ?? 'Chưa rõ';
                      final games =
                          (data['favoriteGames'] as List?)?.join(', ') ??
                          'Không game';
                      final isHybridTab = _selectedTab == _ListTab.hybrid;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isHybridTab
                              ? const Color(0xFFE0F7FA)
                              : Colors.white,
                          border: Border.all(
                            color: Colors.black,
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: isHybridTab
                              ? () => _navigateToProfile(data, userId)
                              : null,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isHybridTab
                                      ? const Color(0xFF00ACC1)
                                      : Colors.black,
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundColor: isHybridTab
                                    ? const Color(0xFF00ACC1).withValues(
                                        alpha: 0.2)
                                    : const Color(0xFFFF7043).withValues(
                                        alpha: 0.2),
                                child: Icon(
                                  isHybridTab
                                      ? Icons.merge_type
                                      : Icons.bug_report,
                                  color: isHybridTab
                                      ? const Color(0xFF00ACC1)
                                      : const Color(0xFFFF7043),
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (isHybridTab)
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black38,
                                    size: 18,
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '$email\n$city • $games',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            // Cả test và hybrid đều có nút xóa
                            trailing: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF5350),
                                      border: Border.all(
                                          color: Colors.black, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black,
                                          offset: Offset(1.5, 1.5),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () =>
                                          _deleteSingleUser(userId, email),
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
