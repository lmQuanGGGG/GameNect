import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../scripts/create_test_users.dart';

class AdminTestUsersScreen extends StatefulWidget {
  const AdminTestUsersScreen({super.key});

  @override
  State<AdminTestUsersScreen> createState() => _AdminTestUsersScreenState();
}

class _AdminTestUsersScreenState extends State<AdminTestUsersScreen> {
  final CreateTestUsers _createTestUsers = CreateTestUsers();
  final TextEditingController _countController = TextEditingController(text: '100');
  
  bool _isCreating = false;
  List<Map<String, dynamic>> _createdUsers = [];
  String _statusMessage = '';

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

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
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteTestUsers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa tất cả test users?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
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
      await _createTestUsers.deleteAllTestUsers();
      
      setState(() {
        _createdUsers = [];
        _statusMessage = 'Đã xóa tất cả test users';
        _isCreating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa test users thành công!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Test Users'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Thông tin',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Password mặc định: Test@123\n'
                      '• Email format: testuser001@gamenect.com\n'
                      '• Tất cả users sẽ có isTestAccount = true\n'
                      '• Mỗi user có 1-3 games ngẫu nhiên\n'
                      '• Location ngẫu nhiên tại các tỉnh thành VN',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Input số lượng
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số lượng users',
                hintText: 'Nhập số lượng (1-500)',
                prefixIcon: const Icon(Icons.people),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !_isCreating,
            ),

            const SizedBox(height: 16),

            // Nút tạo users
            ElevatedButton.icon(
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
                  : const Icon(Icons.add_circle),
              label: Text(_isCreating ? 'Đang tạo...' : 'Tạo Users'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Nút xóa test users
            OutlinedButton.icon(
              onPressed: _isCreating ? null : _handleDeleteTestUsers,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa tất cả Test Users'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Status message
            if (_statusMessage.isNotEmpty)
              Card(
                color: _isCreating ? Colors.orange.shade50 : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _isCreating ? Colors.orange.shade900 : Colors.green.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // Danh sách users đã tạo
            if (_createdUsers.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Danh sách users (${_createdUsers.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _copyUsersList,
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy danh sách',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _createdUsers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _createdUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepOrange.shade100,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                      title: Text(user['displayName']),
                      subtitle: Text(
                        '${user['email']}\n${user['city']} • ${user['games'].join(', ')}',
                      ),
                      isThreeLine: true,
                      dense: true,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
