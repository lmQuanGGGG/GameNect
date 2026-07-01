import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gamenect_new/core/providers/location_provider.dart';
import 'package:gamenect_new/core/widgets/network_image.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'home_screen.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/profile_card.dart'; // Thay vì user_card.dart
import '../../../core/services/firestore_service.dart';
import 'match_list_screen.dart';
import '../premium/subscription_screen.dart';
import '../../widgets/tab_bar_visibility.dart';
import '../../../core/theme/theme_helper.dart';
import 'map_discover_widget.dart';

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
  bool _needsLocation = false;
  bool _isMapView = kIsWeb;

  Future<List<UserModel>> _loadCandidates(
    FirestoreService firestoreService,
    UserModel userModel,
  ) async {
    final hasLocation =
        userModel.latitude != null && userModel.longitude != null;

    if (!hasLocation) {
      if (mounted) {
        setState(() => _needsLocation = true);
      } else {
        _needsLocation = true;
      }
      return [];
    }

    if (_needsLocation && mounted) {
      setState(() => _needsLocation = false);
    } else {
      _needsLocation = false;
    }

    return firestoreService.getUsersWithinRadius(
      latitude: userModel.latitude!,
      longitude: userModel.longitude!,
      radiusKm: userModel.maxDistance,
      limit: 100,
    );
  }

  Future<void> _reloadRecommendations({bool showLocationPrompt = false}) async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final userModel = await firestoreService.getCurrentUser();
    if (userModel == null) return;

    final candidateUsers = await _loadCandidates(firestoreService, userModel);

    if (candidateUsers.isEmpty && _needsLocation) {
      matchProvider.clearRecommendations();
    } else {
      await matchProvider.fetchRecommendations(userModel, candidateUsers);
    }

    if (mounted) {
      setState(() => _currentViewIndex = 0);
    }
  }

  void _onLocationChanged() {
    if (!mounted) return;
    final locProvider = Provider.of<LocationProvider>(context, listen: false);
    // Nếu màn hình đang chờ vị trí, và locProvider đã lấy được vị trí
    if (_needsLocation && locProvider.latitude != null && locProvider.longitude != null) {
      _reloadRecommendations();
    }
  }

  @override
  void initState() {
    super.initState();
    matchProvider = Provider.of<MatchProvider>(context, listen: false);
    
    // Lắng nghe sự thay đổi của LocationProvider để tự động reload khi lấy được vị trí ngầm
    Provider.of<LocationProvider>(context, listen: false).addListener(_onLocationChanged);

    // Sau khi build xong, tải dữ liệu đề xuất match nếu chưa có sẵn
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (matchProvider.recommendations.isNotEmpty) {
        return; // Đã tải sẵn từ lúc khởi động app
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _reloadRecommendations(showLocationPrompt: true);
      } else {
        // Guest mode: Load latest 20 female users
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(35)
              .get();
          final guestUsers = snap.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .where((u) => u.avatarUrl != null && u.avatarUrl!.trim().isNotEmpty)
              .take(30)
              .toList();

          int targetIndex = guestUsers.indexWhere((u) => u.username == 'nngochuongggg');
          if (targetIndex == -1) {
            targetIndex = guestUsers.indexWhere((u) => u.gender == 'Nữ');
          }
          if (targetIndex > 0) {
            final targetUser = guestUsers.removeAt(targetIndex);
            guestUsers.insert(0, targetUser);
          }

          matchProvider.setRecommendations(guestUsers);
          
          // Hiện thông báo cho tài khoản Khách
          if (mounted) {
            _showGuestNeoDialog(context);
          }
        } catch (e) {
          debugPrint('Error loading guest users: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    Provider.of<LocationProvider>(context, listen: false).removeListener(_onLocationChanged);
    controller.dispose();
    super.dispose();
  }

  // Popup phong cách Neo-brutalism cho Khách
  void _showGuestNeoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.travel_explore,
                size: 60,
                color: Color(0xFFFF6E40),
              ),
              const SizedBox(height: 16),
              const Text(
                'CHẾ ĐỘ KHÁCH',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1.5,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Hệ thống đang hiển thị ngẫu nhiên 30 người từ 3 miền Bắc, Trung, Nam để bạn trải nghiệm thử.\n\nĐăng nhập ngay để khám phá hàng ngàn hồ sơ và thiết lập bộ lọc theo đúng "Gu" của bạn!',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6E40),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'ĐÃ HIỂU',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1,
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
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
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
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
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
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: const Offset(1.5, 1.5)),
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
                width: 1.5,
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
                        border: Border.all(color: context.textColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: context.textColor,
                            offset: const Offset(1.5, 1.5),
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
                            'Pre',
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
                    offset: const Offset(1.5, 1.5),
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
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(34, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    await _reloadRecommendations(showLocationPrompt: true);
                  }
                },
                child: const Icon(
                  Icons.settings,
                  color: Color(0xFFFF6E40),
                  size: 20,
                ),
              ),
            ),
          ),
          // Toggle chuyển đổi Swipe / Map
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: context.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.textColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: context.textColor,
                    offset: const Offset(1.5, 1.5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.scaffoldBackgroundColor,
                  foregroundColor: context.textColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                onPressed: () {
                  setState(() {
                    _isMapView = !_isMapView;
                  });
                },
                icon: Icon(
                  _isMapView ? Icons.view_carousel_rounded : Icons.map_rounded,
                  color: const Color(0xFFFF6E40),
                  size: 20,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isMapView ? 'QUẸT' : 'MAP',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _isMapView ? double.infinity : 800),
          child: Stack(
        children: [
          // Nội dung chính an toàn dưới Topbar
          SafeArea(
            child: _isMapView 
              ? const MapDiscoverWidget()
              : RefreshIndicator(
              color: const Color(0xFFFF6E40),
              backgroundColor: const Color(0xFF1A1A1E),
              displacement: 20,
              onRefresh: () async {
                await _reloadRecommendations(showLocationPrompt: true);
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
                    ? CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 64,
                                    color: context.textSecondaryColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _needsLocation
                                        ? 'Cập nhật vị trí để tìm người phù hợp'
                                        : 'Bạn đã xem hết mọi người!',
                                    style: TextStyle(
                                      color: context.textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _needsLocation
                                        ? 'GAMENECT dùng vị trí đã lưu trong hồ sơ để gợi ý người chơi gần bạn.'
                                        : 'Thử mở rộng bán kính hoặc thay đổi bộ lọc để tìm thêm người.',
                                    style: TextStyle(
                                      color: context.textSecondaryColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      '/location-settings',
                                    ),
                                    icon: Icon(
                                      _needsLocation
                                          ? Icons.location_on
                                          : Icons.tune,
                                    ),
                                    label: Text(
                                      _needsLocation
                                          ? 'Cập nhật vị trí'
                                          : 'Điều chỉnh bộ lọc',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF6E40),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Focus(
                        autofocus: true,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowLeft) {
                              controller.swipe(CardSwiperDirection.left);
                              return KeyEventResult.handled;
                            } else if (event.logicalKey ==
                                LogicalKeyboardKey.arrowRight) {
                              controller.swipe(CardSwiperDirection.right);
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWideScreen =
                                kIsWeb && constraints.maxWidth > 700;
                            final screenHeight =
                                MediaQuery.of(context).size.height -
                                kToolbarHeight;
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
                                if (index < 0 || index >= users.length) {
                                  return const SizedBox();
                                }
                                return ProfileCard(user: users[index]);
                              },
                              padding: EdgeInsets.zero,
                              numberOfCardsDisplayed: users.length < 3
                                  ? users.length
                                  : 3,
                              isLoop: false,
                              threshold: kIsWeb ? 30 : 50, // Nhạy hơn trên Web
                              allowedSwipeDirection: kIsWeb
                                  ? const AllowedSwipeDirection.none() // Tắt vuốt thẻ trên mọi phiên bản Web
                                  : const AllowedSwipeDirection.only(
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
                                        previousIndex >= users.length) {
                                      return true;
                                    }
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
                                      // Chạy ngầm (fire-and-forget) để không làm thẻ bị khựng lại chờ mạng
                                      () async {
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
                                            await Future.delayed(
                                              const Duration(milliseconds: 500),
                                            );
                                            if (!context.mounted) return;
                                            _showMatchDialog(
                                              context,
                                              swipedUser.username,
                                              swipedUser.avatarUrl ?? '',
                                            );
                                          }
                                        } else if (direction ==
                                            CardSwiperDirection.left) {
                                          await firestoreService.saveSwipeHistory(
                                            userId: currentUserId,
                                            targetUserId: swipedUser.id,
                                            action: 'dislike',
                                          );
                                        }
                                      }();
                                    } else {
                                      // Guest mode swipe interception
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const HomeScreen(),
                                        ),
                                      );
                                      return false;
                                    }
                                    return true;
                                  },
                              onEnd: () async {
                                // Tự động load lại khi vuốt hết thẻ
                                await _reloadRecommendations(
                                  showLocationPrompt: true,
                                );
                              },
                            );

                            final actionButtonsRow = Padding(
                              padding: const EdgeInsets.only(
                                top: 12,
                                bottom: 24,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Nút Dislike
                                  GestureDetector(
                                    onTap: () => controller.swipe(
                                      CardSwiperDirection.left,
                                    ),
                                    child: Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        color: context.scaffoldBackgroundColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: context.textColor,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.textColor,
                                            offset: const Offset(1.5, 1.5),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.close,
                                          color: context.textColor,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                  // Nút Like
                                  GestureDetector(
                                    onTap: () => controller.swipe(
                                      CardSwiperDirection.right,
                                    ),
                                    child: Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        color: context.scaffoldBackgroundColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: context.textColor,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.textColor,
                                            offset: const Offset(1.5, 1.5),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.favorite,
                                          color: Color(0xFFFF6E40),
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            final mobileLayout = kIsWeb
                                ? Stack(
                                    children: [
                                      Positioned.fill(child: cardSwiperWidget),
                                      Positioned(
                                        bottom:
                                            130, // Nâng cao lên để không đè lên Bottom Nav Bar
                                        left: 0,
                                        right: 0,
                                        child: actionButtonsRow,
                                      ),
                                    ],
                                  )
                                : cardSwiperWidget;

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
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: const Color(0xFFFF6E40).withValues(alpha: 0.2),
                                            width: 1.0,
                                          ),
                                        ),
                                      ),
                                      child: user == null
                                          ? Center(
                                              child: Text(
                                                'Vuốt card để xem thông tin',
                                                style: TextStyle(
                                                  color:
                                                      context.textTertiaryColor,
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
                                                          width: 1.5,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: context
                                                                .textColor,
                                                            offset: const Offset(1.5, 1.5),
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
                                                            color: context
                                                                .textColor,
                                                            fontSize: 26,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          user.rank,
                                                          style:
                                                              const TextStyle(
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                              width: 1.5,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: context
                                                                    .textColor,
                                                                offset: const Offset(1.5, 1.5),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Text(
                                                            g,
                                                            style: TextStyle(
                                                              color: context
                                                                  .textColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                                const SizedBox(height: 24),
                                                // Nút like / dislike (Cho màn hình lớn)
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
                                                            color: context
                                                                .textColor,
                                                            width: 1.5,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: context
                                                                  .textColor,
                                                              offset: const Offset(1.5, 1.5),
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
                                                            color: context
                                                                .textColor,
                                                          ),
                                                          label: Text(
                                                            'Bỏ qua',
                                                            style: TextStyle(
                                                              color: context
                                                                  .textColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: context
                                                                .scaffoldBackgroundColor,
                                                            foregroundColor:
                                                                context
                                                                    .textColor,
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
                                                            color: context
                                                                .textColor,
                                                            width: 1.5,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: context
                                                                  .textColor,
                                                              offset: const Offset(1.5, 1.5),
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
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                context
                                                                    .textColor,
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
                                  ),
                                ],
                              );
                            }

                            // === LAYOUT MOBILE (giữ nguyên) ===
                            return SizedBox(
                              height: screenHeight,
                              child: mobileLayout,
                            );
                          },
                        ),
                      ), // đóng Focus
              ), // đóng Listener
            ),
          ), // đóng RefreshIndicator
        ],
      ),
        ),
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
