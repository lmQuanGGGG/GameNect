import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/widgets/profile_card.dart';
import '../../core/models/user_model.dart';

// Màn hình quản lý người dùng dành cho admin.
// Cho phép tìm kiếm, xem thông tin chi tiết, và xóa người dùng khỏi hệ thống.

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // Biến lưu nội dung tìm kiếm theo tên người dùng.
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    // Container dùng để tạo nền gradient cho toàn bộ màn hình.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF232526), Color(0xFF181A20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Ô nhập liệu để tìm kiếm người dùng theo tên.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.deepOrange),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
              // Khi thay đổi nội dung tìm kiếm, cập nhật lại biến _searchText để lọc danh sách.
              onChanged: (value) {
                setState(() {
                  _searchText = value.trim().toLowerCase();
                });
              },
            ),
          ),
          // Phần hiển thị danh sách người dùng lấy từ Firestore.
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                // Nếu chưa có dữ liệu, hiển thị vòng quay chờ.
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Lọc danh sách người dùng theo nội dung tìm kiếm.
                final users = snapshot.data!.docs.where((doc) {
                  final user = doc.data() as Map<String, dynamic>;
                  final username = (user['username'] ?? '').toString().toLowerCase();
                  return _searchText.isEmpty || username.contains(_searchText);
                }).toList();

                // Nếu không có người dùng nào, hiển thị thông báo.
                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'Không có người dùng nào.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }
                // Hiển thị danh sách người dùng bằng ListView.
                return ListView.builder(
                  itemCount: users.length,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  itemBuilder: (context, index) {
                    final user = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    // Mỗi người dùng được hiển thị trong một Container với hiệu ứng nền và bóng đổ.
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepOrange.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        // Khi bấm vào avatar, mở màn hình mới hiển thị thông tin chi tiết user bằng ProfileCard.
                        leading: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: Text(user['username'] ?? 'Chưa đặt tên'),
                                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                                    foregroundColor: Colors.white,
                                  ),
                                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                                  body: Center(
                                    child: ProfileCard(
                                      user: UserModel.fromMap(user, userId),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            backgroundImage: user['avatarUrl'] != null
                                ? NetworkImage(user['avatarUrl'])
                                : null,
                            backgroundColor: Colors.deepOrange.withValues(alpha: 0.18),
                            child: user['avatarUrl'] == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                        ),
                        // Khi bấm vào tên, cũng mở màn hình mới hiển thị ProfileCard.
                        title: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: Text(user['username'] ?? 'Chưa đặt tên'),
                                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                                    foregroundColor: Colors.white,
                                  ),
                                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                                  body: Center(
                                    child: ProfileCard(
                                      user: UserModel.fromMap(user, userId),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            user['username'] ?? 'Chưa đặt tên',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Hiển thị email của người dùng dưới tên.
                        subtitle: Text(
                          user['email'] ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        // Phần bên phải gồm icon xác thực admin và nút xóa người dùng.
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Nếu user là admin, hiển thị icon xác thực.
                            if (user['isAdmin'] == true)
                              const Icon(Icons.verified, color: Colors.deepOrange, size: 20),
                            // Nút xóa người dùng, khi bấm sẽ hỏi xác nhận trước khi xóa khỏi Firestore.
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Xóa người dùng'),
                                    content: const Text('Bạn có chắc muốn xóa người dùng này?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Hủy'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Xóa'),
                                      ),
                                    ],
                                  ),
                                );
                                // Nếu xác nhận xóa, thực hiện xóa user khỏi Firestore.
                                if (confirm == true) {
                                  await FirebaseFirestore.instance.collection('users').doc(userId).delete();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
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