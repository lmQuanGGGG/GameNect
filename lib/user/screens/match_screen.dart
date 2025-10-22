import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../core/providers/match_provider.dart';
import '../../core/providers/profile_provider.dart';
//import '../../core/models/user_model.dart';
import '../../core/widgets/profile_card.dart'; // Thay vì user_card.dart
import '../../core/services/firestore_service.dart';
import 'match_list_screen.dart';
import 'subscription_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late MatchProvider matchProvider;
  final CardSwiperController controller = CardSwiperController();

  @override
  void initState() {
    super.initState();
    matchProvider = Provider.of<MatchProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final firestoreService = Provider.of<FirestoreService>(
          context,
          listen: false,
        );
        final userModel = await firestoreService.getUser(firebaseUser.uid);
        final candidateUsers = await firestoreService.getAllUsers();
        if (userModel != null) {
          await matchProvider.fetchRecommendations(userModel, candidateUsers);
          if (mounted) {
            setState(() {});
          }
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _showMatchDialog(
    BuildContext context,
    String username,
    String avatarUrl,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.deepOrange, size: 48),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 40,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Bạn đã match với $username!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Hãy nhắn tin làm quen ngay nhé!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Đóng dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MatchListScreen(),
                  ),
                );
              },
              child: const Text(
                'Xem match',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = matchProvider.recommendations;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 0,
        title: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12.0),
              child: Icon(
                Icons.sports_esports,
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
        actions: [
          // THÊM: Premium Button/Badge giống profile
          Consumer<ProfileProvider>(
            builder: (context, provider, _) {
              final isPremium = provider.userData?.isPremium == true;
              if (isPremium) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber, Colors.orange.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                return TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen()),
                    );
                  },
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.deepOrange,
                    size: 20,
                  ),
                  label: const Text(
                    'Nâng cấp',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              }
            },
          ),
          // Nút cài đặt như cũ
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(0),
                minimumSize: const Size(30, 30),
                elevation: 0,
              ),
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/location-settings',
                );
                if (result == true) {
                  // Gọi lại fetchRecommendations để load dữ liệu mới
                  final firebaseUser = FirebaseAuth.instance.currentUser;
                  if (firebaseUser != null) {
                    final firestoreService = Provider.of<FirestoreService>(
                      context,
                      listen: false,
                    );
                    final userModel = await firestoreService.getUser(
                      firebaseUser.uid,
                    );
                    final candidateUsers = await firestoreService.getAllUsers();
                    if (userModel != null) {
                      await Provider.of<MatchProvider>(
                        context,
                        listen: false,
                      ).fetchRecommendations(userModel, candidateUsers);
                      setState(() {});
                    }
                  }
                }
              },
              child: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: matchProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(child: Text('Không có đề xuất nào'))
          : SizedBox(
              height: MediaQuery.of(context).size.height - kToolbarHeight,
              child: CardSwiper(
                controller: controller,
                cardsCount: users.length,
                cardBuilder:
                    (
                      context,
                      index,
                      horizontalOffsetPercentage,
                      verticalOffsetPercentage,
                    ) {
                      if (index < 0 || index >= users.length) {
                        return const SizedBox(); // hoặc widget rỗng
                      }
                      return ProfileCard(user: users[index]);
                    },
                padding: EdgeInsets.zero, // THÊM DÒNG NÀY nếu CardSwiper hỗ trợ
                numberOfCardsDisplayed: users.length < 3
                    ? users.length
                    : 3, // Sửa dòng này
                isLoop: false,
                // Sửa lại onSwipe callback
                onSwipe: (
                  int previousIndex,
                  int? currentIndex,
                  CardSwiperDirection direction,
                ) async {
                  if (previousIndex < 0 || previousIndex >= users.length) return true;
                  final user = users[previousIndex];
                  final currentUserId =
                      FirebaseAuth.instance.currentUser?.uid;
                  final firestoreService = Provider.of<FirestoreService>(
                    context,
                    listen: false,
                  );

                  if (currentUserId != null) {
                    if (direction == CardSwiperDirection.right) {
                      // Lưu LIKE vào swipe_history
                      await firestoreService.saveSwipeHistory(
                        userId: currentUserId,
                        targetUserId: user.id,
                        action: 'like',
                      );

                      // Kiểm tra mutual like
                      final isMutual = await firestoreService
                          .checkMutualLike(
                            userId: currentUserId,
                            targetUserId: user.id,
                          );

                      if (isMutual) {
                        await firestoreService.createNewMatch(
                          userIds: [currentUserId, user.id],
                          game: 'Tên game',
                          expiresAt: DateTime.now().add(
                            const Duration(hours: 24),
                          ),
                        );

                        // QUAN TRỌNG: Đợi animation xong rồi mới show dialog
                        if (mounted) {
                          // Đợi 500ms để CardSwiper animation hoàn tất
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );

                          if (mounted) {
                            _showMatchDialog(
                              context,
                              user.username,
                              user.avatarUrl ?? '',
                            );
                          }
                        }
                      }
                    } else if (direction == CardSwiperDirection.left) {
                      // Lưu DISLIKE vào swipe_history
                      await firestoreService.saveSwipeHistory(
                        userId: currentUserId,
                        targetUserId: user.id,
                        action: 'dislike',
                      );
                    }
                  }
                  return true;
                },
                onEnd: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Hết đề xuất!')));
                },
              ),
            ),
    );
  }
}
