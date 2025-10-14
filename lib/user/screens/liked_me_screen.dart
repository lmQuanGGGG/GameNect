import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/match_provider.dart';
import '../../core/widgets/profile_card.dart';

class LikedMeScreen extends StatefulWidget {
  const LikedMeScreen({super.key});

  @override
  State<LikedMeScreen> createState() => _LikedMeScreenState();
}

class _LikedMeScreenState extends State<LikedMeScreen> {
  List<UserModel> likedMeUsers = [];
  bool isLoading = true;
  bool isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadLikedMeUsers();
  }

  Future<void> _loadLikedMeUsers() async {
    try {
      final currentUser = await FirestoreService().getCurrentUser();
      debugPrint('currentUser: $currentUser');
      if (currentUser == null) {
        debugPrint('Không lấy được currentUser');
        return;
      }

      setState(() {
        isPremium = currentUser.isPremium ?? false;
      });

      final limit = isPremium ? 1000 : 20;
      final matchProvider = Provider.of<MatchProvider>(context, listen: false);
      final users = await matchProvider.fetchLikedMeUsers(currentUser.id, limit: limit);

      debugPrint('Kết quả fetchLikedMeUsers: ${users.length} users');
      if (users.isEmpty) {
        debugPrint('Không có ai thích bạn hoặc lỗi query Firestore');
      }

      if (mounted) {
        setState(() {
          likedMeUsers = users;
          isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Lỗi khi load likedMeUsers: $e');
      debugPrint('Stacktrace: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ai đã thích bạn'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!isPremium)
                  Container(
                    width: double.infinity,
                    color: Colors.orange[50],
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'Tài khoản chưa mua gói chỉ xem được tối đa 20 người đã thích bạn. Muốn xem thêm hãy nâng cấp gói!',
                      style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: likedMeUsers.isEmpty
                      ? const Center(child: Text('Chưa có ai thích bạn!'))
                      : ListView.builder(
                          itemCount: likedMeUsers.length,
                          itemBuilder: (context, index) {
                            final user = likedMeUsers[index];
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(
                                        title: Text(user.username),
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.deepOrange,
                                        elevation: 0,
                                      ),
                                      body: ProfileCard(user: user),
                                    ),
                                  ),
                                );
                              },
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 32, // tăng kích thước avatar
                                  backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                      ? NetworkImage(user.avatarUrl!)
                                      : null,
                                  child: user.avatarUrl == null ? const Icon(Icons.person, size: 32) : null, // icon lớn hơn
                                ),
                                title: Text(
                                  user.username,
                                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.normal), // tăng size và đậm
                                ),
                                subtitle: Text(
                                  '${user.age} tuổi • ${user.location}',
                                  style: const TextStyle(fontSize: 16), // tăng size subtitle
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}