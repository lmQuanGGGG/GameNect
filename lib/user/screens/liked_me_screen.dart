import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool isLoading = true;
  bool isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadLikedMeUsers();

    // Đánh dấu đã xem lượt thích
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'lastSeenLikes': DateTime.now()});
      }
    });
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
        isPremium = currentUser.isPremium;
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final matchProvider = Provider.of<MatchProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepOrange,
        elevation: 0,
        title: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12.0),
              child: Icon(
                Icons.sports_esports, // hoặc CupertinoIcons.game_controller_solid
                color: Colors.deepOrange,
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'gamenect',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: currentUserId == null
          ? const Center(child: Text('Không xác định được tài khoản!'))
          : StreamBuilder<List<UserModel>>(
              stream: matchProvider.streamLikedMeUsers(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final likedMeUsers = snapshot.data ?? [];
                return Column(
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
                                      radius: 32,
                                      backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                          ? NetworkImage(user.avatarUrl!)
                                          : null,
                                      child: user.avatarUrl == null ? const Icon(Icons.person, size: 32) : null,
                                    ),
                                    title: Text(
                                      user.username,
                                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.normal),
                                    ),
                                    subtitle: Text(
                                      '${user.age} tuổi • ${user.location}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.favorite, color: Colors.deepOrange, size: 28),
                                          tooltip: 'Thích lại',
                                          onPressed: () async {
                                            await matchProvider.saveSwipeHistory(currentUserId, user, true);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Bạn đã thích lại ${user.username}!')),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                                          tooltip: 'Dislike',
                                          onPressed: () async {
                                            await matchProvider.saveSwipeHistory(currentUserId, user, false);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Bạn đã dislike ${user.username}!')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}