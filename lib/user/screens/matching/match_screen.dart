import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gamenect_new/core/widgets/network_image.dart';
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
import '../../../core/theme/theme_helper.dart';


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
    // Sau khi build xong, tải dữ liệu đề xuất match nếu chưa có sẵn
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (matchProvider.recommendations.isNotEmpty) {
        return; // Đã tải sẵn từ lúc khởi động app
      }
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F4), // Light background
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black, width: 4),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(8, 8)),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, color: Color(0xFFFF6E40), size: 56),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                  ],
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFFFEB3B),
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: GamenectNetworkImage(
                            imageUrl: avatarUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.person, size: 40, color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'TƯƠNG HỢP VỚI\n${username.toUpperCase()}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 1.0,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Hãy nhắn tin làm quen ngay nhé!',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Đóng dialog
                  // Điều hướng đến màn hình danh sách match
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MatchListScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6E40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'XEM MATCH',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = matchProvider.recommendations;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.scaffoldBackgroundColor,
      // AppBar với logo và các nút hành động
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: context.scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: context.isDarkMode ? Colors.white24 : Colors.black12,
                width: 1,
              ),
            ),
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
                color: context.textColor,
                fontWeight: FontWeight.w900,
                fontSize: 22,
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
                        color: context.textColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.textColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: context.textColor,
                            offset: const Offset(4, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFFF6E40),
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: context.scaffoldBackgroundColor,
                              fontWeight: FontWeight.w900,
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
                  label: Text(
                    'Nâng cấp',
                    style: TextStyle(
                      color: context.textColor,
                      fontWeight: FontWeight.w900,
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
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.textColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: context.textColor,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.scaffoldBackgroundColor,
                  foregroundColor: context.textColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(0),
                  minimumSize: const Size(34, 34),
                  elevation: 0,
                  shadowColor: Colors.transparent,
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
                      final candidateUsers = await firestoreService
                          .getAllUsers();
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
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Nội dung chính an toàn dưới Topbar
          SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFFFF6E40),
              backgroundColor: const Color(0xFF1A1A1E),
              displacement: 20,
              onRefresh: () async {
                final firestoreService = Provider.of<FirestoreService>(
                  context,
                  listen: false,
                );
                final userModel = await firestoreService.getCurrentUser();
                final candidateUsers = await firestoreService.getAllUsers();
                if (userModel != null) {
                  await Provider.of<MatchProvider>(
                    context,
                    listen: false,
                  ).fetchRecommendations(userModel, candidateUsers);
                  if (mounted) setState(() {});
                }
              },
              child: Listener(
                // Dùng Listener thay GestureDetector vì CardSwiper nuốt hết gesture events.
                // Listener nhận raw pointer events TRƯỚC khi bất kỳ widget nào tiêu thụ chúng.
                onPointerMove: (event) {
                  try {
                    if (kIsWeb) return;
                    // Tránh làm thay đổi giao diện/layout khi đang vuốt card ngang (ngăn xung đột khi swipe)
                    if (event.delta.dx.abs() > event.delta.dy.abs()) return;

                    final controller = TabBarVisibility.of(context);
                    final dy = event.delta.dy;
                    if (dy < -5) {
                      controller.setVisible(false); // vuốt lên → ẩn
                    } else if (dy > 5) {
                      controller.setVisible(true); // vuốt xuống → hiện
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
                    ? Center(
                        child: Text(
                          'Không có đề xuất nào',
                          style: TextStyle(color: context.textSecondaryColor),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWideScreen =
                              kIsWeb && constraints.maxWidth > 700;
                          final screenHeight =
                              MediaQuery.of(context).size.height -
                              kToolbarHeight -
                              20;
                          final user =
                              (_currentViewIndex >= 0 &&
                                  _currentViewIndex < users.length)
                              ? users[_currentViewIndex]
                              : null;

                          // Widget CardSwiper dùng chung cho cả 2 layout
                          final cardSwiperWidget = CardSwiper(
                            controller: controller,
                            cardsCount: users.length,
                            cardBuilder: (context, index, hOff, vOff) {
                              if (index < 0 || index >= users.length)
                                return const SizedBox();
                              return ProfileCard(user: users[index]);
                            },
                            padding: EdgeInsets.zero,
                            numberOfCardsDisplayed: users.length < 3
                                ? users.length
                                : 3,
                            isLoop: false,
                            threshold: kIsWeb ? 30 : 50, // Nhạy hơn trên Web
                            allowedSwipeDirection:
                                const AllowedSwipeDirection.only(
                                  left: true,
                                  right: true,
                                  up: false,
                                  down: false,
                                ),
                            onSwipe:
                                (
                                  int previousIndex,
                                  int? currentIndex,
                                  CardSwiperDirection direction,
                                ) async {
                                  if (previousIndex < 0 ||
                                      previousIndex >= users.length)
                                    return true;
                                  final swipedUser = users[previousIndex];
                                  final currentUserId =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  final firestoreService =
                                      Provider.of<FirestoreService>(
                                        context,
                                        listen: false,
                                      );

                                  // Cập nhật index đang xem trên web
                                  if (mounted &&
                                      currentIndex != null &&
                                      currentIndex < users.length) {
                                    setState(
                                      () => _currentViewIndex = currentIndex,
                                    );
                                  }

                                  if (currentUserId != null) {
                                    if (direction ==
                                        CardSwiperDirection.right) {
                                      await firestoreService.saveSwipeHistory(
                                        userId: currentUserId,
                                        targetUserId: swipedUser.id,
                                        action: 'like',
                                      );
                                      final isMutual = await firestoreService
                                          .checkMutualLike(
                                            userId: currentUserId,
                                            targetUserId: swipedUser.id,
                                          );
                                      if (isMutual) {
                                        await firestoreService.createNewMatch(
                                          userIds: [
                                            currentUserId,
                                            swipedUser.id,
                                          ],
                                          game: 'Tên game',
                                          expiresAt: DateTime.now().add(
                                            const Duration(hours: 24),
                                          ),
                                        );
                                        if (mounted) {
                                          await Future.delayed(
                                            const Duration(milliseconds: 500),
                                          );
                                          if (mounted)
                                            _showMatchDialog(
                                              context,
                                              swipedUser.username,
                                              swipedUser.avatarUrl ?? '',
                                            );
                                        }
                                      }
                                    } else if (direction ==
                                        CardSwiperDirection.left) {
                                      await firestoreService.saveSwipeHistory(
                                        userId: currentUserId,
                                        targetUserId: swipedUser.id,
                                        action: 'dislike',
                                      );
                                    }
                                  }
                                  return true;
                                },
                            onEnd: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hết đề xuất!')),
                              );
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
                                  color: const Color(
                                    0xFFFF6E40,
                                  ).withValues(alpha: 0.2),
                                ),
                                // Cột phải: Info panel user đang xem
                                Expanded(
                                  child: user == null
                                      ? Center(
                                          child: Text(
                                            'Vuốt card để xem thông tin',
                                            style: TextStyle(
                                              color: context.textTertiaryColor,
                                            ),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          padding: const EdgeInsets.all(32),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Avatar + tên
                                              Row(
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color:
                                                            context.textColor,
                                                        width: 3,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color:
                                                              context.textColor,
                                                          offset: const Offset(
                                                            4,
                                                            4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: CircleAvatar(
                                                      radius: 40,
                                                      backgroundColor: context
                                                          .scaffoldBackgroundColor,
                                                      child:
                                                          user
                                                                  .avatarUrl
                                                                  ?.isNotEmpty ==
                                                              true
                                                          ? ClipOval(
                                                              child: GamenectNetworkImage(
                                                                imageUrl: user
                                                                    .avatarUrl!,
                                                                width: 80,
                                                                height: 80,
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                            )
                                                          : const Icon(
                                                              Icons.person,
                                                              size: 40,
                                                              color: Color(
                                                                0xFFFF6E40,
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        user.username,
                                                        style: TextStyle(
                                                          color:
                                                              context.textColor,
                                                          fontSize: 26,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        user.rank,
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFFFF6E40,
                                                          ),
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 24),
                                              // Thông tin cơ bản
                                              _infoTile(
                                                Icons.cake,
                                                'Tuổi',
                                                '${user.age} tuổi',
                                              ),
                                              _infoTile(
                                                Icons.person,
                                                'Giới tính',
                                                user.gender,
                                              ),
                                              if (user.distanceKm != null)
                                                _infoTile(
                                                  Icons.location_on,
                                                  'Khoảng cách',
                                                  '${user.distanceKm!.toStringAsFixed(1)} km',
                                                ),
                                              _infoTile(
                                                Icons.gamepad,
                                                'Phong cách',
                                                user.gameStyle,
                                              ),
                                              _infoTile(
                                                Icons.search,
                                                'Mục đích',
                                                user.lookingFor,
                                              ),
                                              const SizedBox(height: 16),
                                              // Bio
                                              if (user.bio.isNotEmpty) ...[
                                                Text(
                                                  'Giới thiệu',
                                                  style: TextStyle(
                                                    color: context.textColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  user.bio,
                                                  style: TextStyle(
                                                    color: context
                                                        .textSecondaryColor,
                                                    fontSize: 15,
                                                    height: 1.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                              ],
                                              // Game tags
                                              Text(
                                                'Game yêu thích',
                                                style: TextStyle(
                                                  color: context.textColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: user.favoriteGames
                                                    .map(
                                                      (g) => Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 14,
                                                              vertical: 7,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: context
                                                              .scaffoldBackgroundColor,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color: context
                                                                .textColor,
                                                            width: 2,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: context
                                                                  .textColor,
                                                              offset:
                                                                  const Offset(
                                                                    2,
                                                                    2,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Text(
                                                          g,
                                                          style: TextStyle(
                                                            color: context
                                                                .textColor,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                              const SizedBox(height: 24),
                                              // Nút like / dislike
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: context
                                                            .scaffoldBackgroundColor,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              context.textColor,
                                                          width: 3,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: context
                                                                .textColor,
                                                            offset:
                                                                const Offset(
                                                                  4,
                                                                  4,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ElevatedButton.icon(
                                                        onPressed: () =>
                                                            controller.swipe(
                                                              CardSwiperDirection
                                                                  .left,
                                                            ),
                                                        icon: Icon(
                                                          Icons.close,
                                                          color:
                                                              context.textColor,
                                                        ),
                                                        label: Text(
                                                          'Bỏ qua',
                                                          style: TextStyle(
                                                            color: context
                                                                .textColor,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: context
                                                              .scaffoldBackgroundColor,
                                                          foregroundColor:
                                                              context.textColor,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 14,
                                                              ),
                                                          elevation: 0,
                                                          shadowColor: Colors
                                                              .transparent,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color:
                                                            context.textColor,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              context.textColor,
                                                          width: 3,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: context
                                                                .textColor,
                                                            offset:
                                                                const Offset(
                                                                  4,
                                                                  4,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ElevatedButton.icon(
                                                        onPressed: () =>
                                                            controller.swipe(
                                                              CardSwiperDirection
                                                                  .right,
                                                            ),
                                                        icon: const Icon(
                                                          Icons.favorite,
                                                          color: Color(
                                                            0xFFFF6E40,
                                                          ),
                                                        ),
                                                        label: Text(
                                                          'Thích',
                                                          style: TextStyle(
                                                            color: context
                                                                .scaffoldBackgroundColor,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              context.textColor,
                                                          foregroundColor: context
                                                              .scaffoldBackgroundColor,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 14,
                                                              ),
                                                          elevation: 0,
                                                          shadowColor: Colors
                                                              .transparent,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
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
          Text(
            '$label: ',
            style: TextStyle(color: context.textTertiaryColor, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
