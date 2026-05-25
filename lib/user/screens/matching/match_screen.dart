import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/providers/profile_provider.dart';
//import '../../../core/models/user_model.dart';
import '../../../core/widgets/profile_card.dart'; // Thay vì user_card.dart
import '../../../core/services/firestore_service.dart';
import 'match_list_screen.dart';
import '../premium/subscription_screen.dart';
import '../../widgets/tab_bar_visibility.dart';

// Sử dụng CardSwiper để tạo hiệu ứng swipe, và provider để quản lý trạng thái match.

// Lớp chính của màn hình match, sử dụng CardSwiper để người dùng swipe qua các profile
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

// Trạng thái của MatchScreen, quản lý việc tải dữ liệu đề xuất và xử lý swipe
class _MatchScreenState extends State<MatchScreen> {
  late MatchProvider matchProvider;
  final CardSwiperController controller = CardSwiperController();
  int _currentViewIndex = 0; // Track user hiện đang xem trên web

  @override
  void initState() {
    super.initState();
    matchProvider = Provider.of<MatchProvider>(context, listen: false);
    // Sau khi build xong, tải dữ liệu đề xuất match
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final firestoreService = Provider.of<FirestoreService>(
          context,
          listen: false,
        );
        // Lấy thông tin user hiện tại
        final userModel = await firestoreService.getUser(firebaseUser.uid);
        // Lấy danh sách tất cả user để tạo đề xuất
        final candidateUsers = await firestoreService.getAllUsers();
        if (userModel != null) {
          // Tải danh sách đề xuất dựa trên user hiện tại và danh sách candidate
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

  // Hiển thị dialog khi có match xảy ra
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
                // Điều hướng đến màn hình danh sách match
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MatchListScreen()),
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
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF101012),
      // AppBar với logo và các nút hành động
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),
        ),
        title: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12.0),
              child: Icon(
                Icons.sports_esports,
                color: Color(0xFFFF6E40),
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'gamenect',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                shadows: [
                  Shadow(
                    color: const Color(0xFFFF6E40).withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Hiển thị badge Premium hoặc nút nâng cấp dựa trên trạng thái user
          Consumer<ProfileProvider>(
            builder: (context, provider, _) {
              final isPremium = provider.userData?.isPremium == true;
              if (isPremium) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFF6E40),
                    size: 20,
                  ),
                  label: const Text(
                    'Nâng cấp',
                    style: TextStyle(
                      color: Color(0xFFFF6E40),
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
          // Nút cài đặt để điều chỉnh vị trí và các tùy chọn match
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6E40).withValues(alpha: 0.1),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(0),
                minimumSize: const Size(40, 40),
                elevation: 0,
              ),
              onPressed: () async {
                // Điều hướng đến màn hình cài đặt vị trí
                final result = await Navigator.pushNamed(
                  context,
                  '/location-settings',
                );
                if (result == true) {
                  // Nếu có thay đổi, tải lại dữ liệu đề xuất
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
                color: Color(0xFFFF6E40),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Orbs để tạo hiệu ứng Liquid Glass cho Topbar
          Positioned(
            top: 0,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6E40).withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6E40).withValues(alpha: 0.1),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          // Nội dung chính an toàn dưới Topbar
          SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFFFF6E40),
              backgroundColor: const Color(0xFF1A1A1E),
              displacement: 20,
              onRefresh: () async {
                final firestoreService = Provider.of<FirestoreService>(context, listen: false);
                final userModel = await firestoreService.getCurrentUser();
                final candidateUsers = await firestoreService.getAllUsers();
                if (userModel != null) {
                  await Provider.of<MatchProvider>(context, listen: false)
                      .fetchRecommendations(userModel, candidateUsers);
                  if (mounted) setState(() {});
                }
              },
              child: Listener(
                // Dùng Listener thay GestureDetector vì CardSwiper nuốt hết gesture events.
                // Listener nhận raw pointer events TRƯỚC khi bất kỳ widget nào tiêu thụ chúng.
                onPointerMove: (event) {
                  try {
                    final controller = TabBarVisibility.of(context);
                    final dy = event.delta.dy;
                    if (dy < -5) {
                      controller.setVisible(false); // vuốt lên → ẩn
                    } else if (dy > 5) {
                      controller.setVisible(true);  // vuốt xuống → hiện
                    }
                  } catch (_) {}
                },
              child: matchProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6E40),
                      ),
                    )
                  : users.isEmpty
                  ? const Center(
                      child: Text(
                        'Không có đề xuất nào',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWideScreen = kIsWeb && constraints.maxWidth > 700;
                        final screenHeight = MediaQuery.of(context).size.height - kToolbarHeight - 20;
                        final user = (_currentViewIndex >= 0 && _currentViewIndex < users.length)
                            ? users[_currentViewIndex]
                            : null;

                        // Widget CardSwiper dùng chung cho cả 2 layout
                        final cardSwiperWidget = CardSwiper(
                          controller: controller,
                          cardsCount: users.length,
                          cardBuilder: (context, index, hOff, vOff) {
                            if (index < 0 || index >= users.length) return const SizedBox();
                            return ProfileCard(user: users[index]);
                          },
                          padding: EdgeInsets.zero,
                          numberOfCardsDisplayed: users.length < 3 ? users.length : 3,
                          isLoop: false,
                          onSwipe: (int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
                            if (previousIndex < 0 || previousIndex >= users.length) return true;
                            final swipedUser = users[previousIndex];
                            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                            final firestoreService = Provider.of<FirestoreService>(context, listen: false);

                            // Cập nhật index đang xem trên web
                            if (mounted && currentIndex != null && currentIndex < users.length) {
                              setState(() => _currentViewIndex = currentIndex);
                            }

                            if (currentUserId != null) {
                              if (direction == CardSwiperDirection.right) {
                                await firestoreService.saveSwipeHistory(
                                  userId: currentUserId, targetUserId: swipedUser.id, action: 'like');
                                final isMutual = await firestoreService.checkMutualLike(
                                  userId: currentUserId, targetUserId: swipedUser.id);
                                if (isMutual) {
                                  await firestoreService.createNewMatch(
                                    userIds: [currentUserId, swipedUser.id],
                                    game: 'Tên game',
                                    expiresAt: DateTime.now().add(const Duration(hours: 24)));
                                  if (mounted) {
                                    await Future.delayed(const Duration(milliseconds: 500));
                                    if (mounted) _showMatchDialog(context, swipedUser.username, swipedUser.avatarUrl ?? '');
                                  }
                                }
                              } else if (direction == CardSwiperDirection.left) {
                                await firestoreService.saveSwipeHistory(
                                  userId: currentUserId, targetUserId: swipedUser.id, action: 'dislike');
                              }
                            }
                            return true;
                          },
                          onEnd: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Hết đề xuất!')));
                          },
                        );

                        if (isWideScreen) {
                          // === LAYOUT 2 CỘT CHO WEB ===
                          return Row(
                            children: [
                              // Cột trái: Card swipe (max 480px, căn giữa)
                              SizedBox(
                                width: 480,
                                height: screenHeight,
                                child: cardSwiperWidget,
                              ),
                              // Divider
                              Container(
                                width: 1,
                                height: screenHeight,
                                color: const Color(0xFFFF6E40).withValues(alpha: 0.2),
                              ),
                              // Cột phải: Info panel user đang xem
                              Expanded(
                                child: user == null
                                    ? const Center(
                                        child: Text('Vuốt card để xem thông tin',
                                            style: TextStyle(color: Colors.white38)))
                                    : SingleChildScrollView(
                                        padding: const EdgeInsets.all(32),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Avatar + tên
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 40,
                                                  backgroundImage: (user.avatarUrl?.isNotEmpty == true)
                                                      ? NetworkImage(user.avatarUrl!)
                                                      : null,
                                                  child: user.avatarUrl?.isEmpty != false
                                                      ? const Icon(Icons.person, size: 40)
                                                      : null,
                                                ),
                                                const SizedBox(width: 16),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(user.username,
                                                        style: const TextStyle(
                                                            color: Colors.white, fontSize: 26,
                                                            fontWeight: FontWeight.bold)),
                                                    Text(user.rank,
                                                        style: const TextStyle(
                                                            color: Color(0xFFFF6E40), fontSize: 16)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 24),
                                            // Thông tin cơ bản
                                            _infoTile(Icons.cake, 'Tuổi', '${user.age} tuổi'),
                                            _infoTile(Icons.person, 'Giới tính', user.gender),
                                            if (user.distanceKm != null)
                                              _infoTile(Icons.location_on, 'Khoảng cách',
                                                  '${user.distanceKm!.toStringAsFixed(1)} km'),
                                            _infoTile(Icons.gamepad, 'Phong cách', user.gameStyle),
                                            _infoTile(Icons.search, 'Mục đích', user.lookingFor),
                                            const SizedBox(height: 16),
                                            // Bio
                                            if (user.bio.isNotEmpty) ...[
                                              const Text('Giới thiệu',
                                                  style: TextStyle(color: Colors.white,
                                                      fontWeight: FontWeight.bold, fontSize: 18)),
                                              const SizedBox(height: 8),
                                              Text(user.bio,
                                                  style: const TextStyle(
                                                      color: Colors.white70, fontSize: 15, height: 1.5)),
                                              const SizedBox(height: 16),
                                            ],
                                            // Game tags
                                            const Text('Game yêu thích',
                                                style: TextStyle(color: Colors.white,
                                                    fontWeight: FontWeight.bold, fontSize: 18)),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8, runSpacing: 8,
                                              children: user.favoriteGames.map((g) => Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 14, vertical: 7),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFF6E40).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                      color: const Color(0xFFFF6E40).withValues(alpha: 0.5))),
                                                child: Text(g, style: const TextStyle(
                                                    color: Colors.white, fontWeight: FontWeight.w600)),
                                              )).toList(),
                                            ),
                                            const SizedBox(height: 24),
                                            // Nút like / dislike
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () => controller.swipe(CardSwiperDirection.left),
                                                    icon: const Icon(Icons.close, color: Colors.red),
                                                    label: const Text('Bỏ qua',
                                                        style: TextStyle(color: Colors.red)),
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(color: Colors.red),
                                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12))),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () => controller.swipe(CardSwiperDirection.right),
                                                    icon: const Icon(Icons.favorite, color: Colors.white),
                                                    label: const Text('Thích',
                                                        style: TextStyle(color: Colors.white)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFFF6E40),
                                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12))),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          );
                        }

                        // === LAYOUT MOBILE (giữ nguyên) ===
                        return SizedBox(
                          height: screenHeight,
                          child: cardSwiperWidget,
                        );
                      },
                    ),
            ), // đóng Listener
          ),
          ), // đóng RefreshIndicator
        ],
      ),
    );
  }

  // Helper widget cho info row trong panel web
  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFF6E40)),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
