import 'package:flutter/material.dart';
import 'package:gamenect_new/core/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/theme/theme_helper.dart';
import '../../../core/widgets/network_image.dart';
import '../premium/subscription_screen.dart';
import '../../widgets/tab_bar_visibility.dart';
import '../shared/peer_profile_screen.dart';

// Màn hình hiển thị danh sách người đã thích mình và người đã bỏ lỡ
// Free user chỉ xem được 3 người đầu tiên, còn lại phải nâng cấp Premium
// Premium user xem không giới hạn và có tính năng Rewind để thích lại người đã dislike
class LikedMeScreen extends StatefulWidget {
  const LikedMeScreen({super.key});

  @override
  State<LikedMeScreen> createState() => _LikedMeScreenState();
}

class _LikedMeScreenState extends State<LikedMeScreen>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;

  // Danh sách người đã thích mình
  List<UserModel> _likedMeUsers = [];
  // Danh sách người mình đã dislike
  List<UserModel> _myDislikedUsers = [];

  // Stream để lắng nghe realtime danh sách người thích mình
  Stream<List<UserModel>>? _likedMeStream;
  // Stream để lắng nghe realtime danh sách người đã dislike
  Stream<List<UserModel>>? _myDislikedStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    if (profileProvider.userData != null) {
      isLoading = false;
    } else {
      profileProvider.loadUserProfile();
    }
    _initializeData();
  }

  // Khởi tạo dữ liệu khi mở màn hình
  // Setup stream để lắng nghe realtime và cập nhật thời gian xem likes
  Future<void> _initializeData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    // Cập nhật thời gian xem likes cuối cùng để reset badge
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'lastSeenLikes': DateTime.now(),
    });

    if (mounted) {
      final matchProvider = Provider.of<MatchProvider>(context, listen: false);

      // Setup stream để lắng nghe danh sách người thích mình
      if (_likedMeStream == null) {
        _likedMeStream = matchProvider.streamLikedMeUsers(userId);
        _likedMeStream!.listen((users) {
          if (mounted) {
            setState(() {
              _likedMeUsers = users;
            });
          }
        });
      }

      // Setup stream để lắng nghe danh sách người đã dislike
      if (_myDislikedStream == null) {
        _myDislikedStream = matchProvider.streamMyDislikedUsers(
          userId,
          limit: 1000,
        );
        _myDislikedStream!.listen((users) {
          if (mounted) {
            setState(() {
              _myDislikedUsers = users;
            });
          }
        });
      }

      setState(() {
        isLoading = false;
      });
    }
  }

  // Banner nâng cấp Premium với gradient đẹp mắt
  // Hiển thị khi user chưa premium và cần unlock tính năng
  Widget _promoUpgrade(
    BuildContext context, {
    String message =
        'Xem danh sách những người bạn đã bỏ lỡ và có thể thích lại!',
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.isDarkMode ? Colors.black : const Color(0xFFF4F4F4),
        border: Border.all(color: context.isDarkMode ? Colors.white : Colors.black, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode ? Colors.white : Colors.black,
            offset: const Offset(6, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: Color(0xFFFF6E40),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Nâng cấp Premium',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFF6E40),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6E40),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: context.isDarkMode ? Colors.white : Colors.black, width: 2),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Nâng cấp ngay',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget avatar với glassmorphism effect
  // Áp dụng blur nếu user chưa premium và vượt quá giới hạn 3 người
  Widget _buildAvatar(UserModel user, {bool shouldBlur = false}) {
    Widget avatarContent;

    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      avatarContent = ClipOval(
        child: GamenectNetworkImage(
          imageUrl: user.avatarUrl!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade800,
            ),
          ),
          errorWidget: (context, url, error) {
            // Fallback nếu load ảnh lỗi
            return Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, size: 32, color: Colors.white),
            );
          },
        ),
      );
    } else {
      // Hiển thị icon person mặc định nếu không có avatar
      avatarContent = Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.grey.shade400, Colors.grey.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.person, size: 32, color: Colors.white),
      );
    }

    // Solid Neo-Brutalism avatar
    Widget glassAvatar = Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.isDarkMode ? Colors.black : Colors.white,
        border: Border.all(
          color: context.isDarkMode ? Colors.white : Colors.black,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode ? Colors.white : Colors.black,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          padding: const EdgeInsets.all(2),
          child: avatarContent,
        ),
      ),
    );

    // Trả về avatar thường nếu không cần blur
    if (!shouldBlur) return glassAvatar;

    // Blur effect nếu chưa Premium - che mờ avatar và thêm icon blur
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipOval(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: glassAvatar,
          ),
        ),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.3),
          ),
          child: const Icon(Icons.blur_on, color: Colors.white, size: 28),
        ),
      ],
    );
  }

  // Tab 1: Người đã thích tôi
  // FREE user chỉ xem 3 người đầu tiên, còn lại blur và hiện banner upsell
  Widget _likedMeTab(String currentUserId, bool isPremium) {

    // Hiển thị empty state nếu chưa có ai thích
    if (_likedMeUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Chưa có ai thích bạn!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final freeLimit = 3; // FREE user chỉ xem được 3 người
    final hasMore = _likedMeUsers.length > freeLimit;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        try {
          TabBarVisibility.of(context).update(n);
        } catch (_) {}
        return false;
      },
      child: RefreshIndicator(
        color: const Color(0xFFFF6E40),
        backgroundColor: context.scaffoldBackgroundColor,
        displacement: 20,
        onRefresh: () async {
          await _initializeData();
        },
        child: ListView.builder(
          key: const PageStorageKey('liked_me_list'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          // Premium xem tất cả, Free thì +1 item cho banner upsell
          itemCount: isPremium
              ? _likedMeUsers.length
              : (_likedMeUsers.length + 1),
        itemBuilder: (context, index) {
          // Hiện banner quảng cáo Premium sau 3 người (nếu FREE và có nhiều hơn 3)
          if (!isPremium && index == freeLimit && hasMore) {
            final remainingCount = _likedMeUsers.length - freeLimit;
            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.isDarkMode ? Colors.black : const Color(0xFFF4F4F4),
                border: Border.all(color: context.isDarkMode ? Colors.white : Colors.black, width: 3),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.isDarkMode ? Colors.white : Colors.black,
                    offset: const Offset(6, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 3 avatar xếp chồng nhau chuẩn Neo-brutalism
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => Transform.translate(
                            offset: Offset((i - 1) * -20.0, 0), // Sửa lại offset để chồng hợp lý hơn ở center
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.isDarkMode ? Colors.black : Colors.white,
                                border: Border.all(
                                  color: context.isDarkMode ? Colors.white : Colors.black,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: Icon(
                                  Icons.person,
                                  size: 32,
                                  color: context.isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '+$remainingCount người khác đã thích bạn!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF6E40),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nâng cấp Premium để xem tất cả',
                    style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6E40),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: context.isDarkMode ? Colors.white : Colors.black, width: 2),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Xem ngay',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Lấy index user thực tế (bỏ qua banner ở giữa nếu free)
          final userIndex = !isPremium && index > freeLimit ? index - 1 : index;
          if (userIndex >= _likedMeUsers.length) return const SizedBox.shrink();

          final user = _likedMeUsers[userIndex];
          // Blur avatar nếu free và vượt quá 3 người
          final shouldBlur = !isPremium && userIndex >= freeLimit;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.isDarkMode ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.isDarkMode ? Colors.white : Colors.black,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.isDarkMode ? Colors.white : Colors.black,
                  offset: const Offset(4, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                // Nếu blur thì tap vào sẽ mở màn hình premium
                onTap: shouldBlur
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      }
                    : () {
                        // Không blur thì mở profile card
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PeerProfileScreen(peerUser: user),
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildAvatar(user, shouldBlur: shouldBlur),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hiển thị dấu chấm nếu blur, còn không thì hiện tên thật
                            Text(
                              shouldBlur ? '●●●●●●' : user.username,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: context.textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shouldBlur
                                  ? '●● tuổi • ●●●●●●'
                                  : '${user.age} tuổi • ${user.location}',
                              style: TextStyle(
                                fontSize: 14,
                                color: context.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Nếu không blur thì hiển thị nút thích lại và bỏ qua
                      if (!shouldBlur)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.favorite,
                                color: Colors.deepOrange,
                                size: 28,
                              ),
                              tooltip: 'Thích lại',
                              onPressed: () async {
                                // Lưu swipe history với action like để tạo match
                                final matchProvider =
                                    Provider.of<MatchProvider>(
                                      context,
                                      listen: false,
                                    );
                                await matchProvider.saveSwipeHistory(
                                  currentUserId,
                                  user,
                                  true,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Bạn đã thích lại ${user.username}!',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 28,
                              ),
                              tooltip: 'Bỏ qua',
                              onPressed: () async {
                                // Lưu swipe history với action dislike
                                await FirestoreService().saveSwipeHistory(
                                  userId: currentUserId,
                                  targetUserId: user.id,
                                  action: 'dislike',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Bạn đã bỏ qua ${user.username}!',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        )
                      else
                        // Nếu blur thì hiển thị nút Xem để mở premium
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Xem',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  // Tab 2: Bỏ lỡ - danh sách người đã dislike
  // Chỉ Premium user mới xem được và có thể Rewind để thích lại
  Widget _missedTab(String currentUserId, bool isPremium) {

    // Nếu chưa premium thì hiển thị banner upsell
    if (!isPremium) {
      return SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _promoUpgrade(
              context,
              message:
                  'Xem lại những người bạn đã bỏ lỡ và có cơ hội thích lại họ!',
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.undo_rounded,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tính năng Rewind',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hoàn tác những lượt vuốt trái và có cơ hội kết nối lại!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Empty state nếu chưa dislike ai
    if (_myDislikedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: context.textTertiaryColor),
            const SizedBox(height: 16),
            Text(
              'Chưa có ai bị bỏ lỡ!',
              style: TextStyle(fontSize: 16, color: context.textSecondaryColor),
            ),
          ],
        ),
      );
    }

    // Hiển thị danh sách người đã dislike với tính năng Rewind
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        try {
          TabBarVisibility.of(context).update(n);
        } catch (_) {}
        return false;
      },
      child: RefreshIndicator(
        color: const Color(0xFFFF6E40),
        backgroundColor: context.scaffoldBackgroundColor,
        displacement: 20,
        onRefresh: () async {
          await _initializeData();
        },
        child: ListView.builder(
          key: const PageStorageKey('missed_list'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _myDislikedUsers.length,
          itemBuilder: (context, index) {
            final user = _myDislikedUsers[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.isDarkMode ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.isDarkMode ? Colors.white : Colors.black,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.isDarkMode ? Colors.white : Colors.black,
                  offset: const Offset(4, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Tap vào để xem profile card
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PeerProfileScreen(peerUser: user),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildAvatar(user),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.username,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: context.textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${user.age} tuổi • ${user.location}',
                              style: TextStyle(
                                fontSize: 14,
                                color: context.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Nút Rewind để hoàn tác dislike và thích lại
                      IconButton(
                        icon: const Icon(
                          Icons.undo_rounded,
                          color: Colors.deepOrange,
                          size: 28,
                        ),
                        tooltip: 'Rewind - Thích lại',
                        onPressed: () async {
                          // Lưu swipe history với action like để thay thế dislike trước đó
                          await FirestoreService().saveSwipeHistory(
                            userId: currentUserId,
                            targetUserId: user.id,
                            action: 'like',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã rewind ${user.username}!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          },
        ), // đóng ListView.builder
      ), // đóng RefreshIndicator
    ); // đóng NotificationListener
  }

  @override
  Widget build(BuildContext context) {

    super.build(context);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final profileProvider = Provider.of<ProfileProvider>(context);
    final isPremium = profileProvider.userData?.isPremium ?? false;

    // Hiển thị loading khi đang khởi tạo dữ liệu hoặc đang tải thông tin profile
    if (isLoading || (profileProvider.userData == null && profileProvider.isLoading)) {
      return Scaffold(
        backgroundColor: context.isDarkMode ? Colors.black : const Color(0xFFF4F4F4),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6E40)),
        ),
      );
    }

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: context.isDarkMode ? Colors.black : const Color(0xFFF4F4F4),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 100,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              const Text(
                'Đăng nhập để xem lượt thích',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Đăng nhập'),
              ),
            ],
          ),
        ),
      );
    }

    // Màn hình chính với 2 tabs: Thích bạn và Bỏ lỡ
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: context.isDarkMode ? Colors.black : const Color(0xFFF4F4F4),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
          ],
          // TabBar với 2 tabs
          bottom: TabBar(
            labelColor: const Color(0xFFFF6E40),
            unselectedLabelColor: context.textTertiaryColor,
            indicatorColor: const Color(0xFFFF6E40),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            dividerColor: context.cardBorderColor,
            tabs: [
              Tab(
                icon: Icon(
                  Icons.favorite,
                  shadows: [
                    Shadow(
                      color: context.isDarkMode ? Colors.white : Colors.black,
                      offset: const Offset(1.5, 1.5),
                    )
                  ],
                ),
                text: 'Thích bạn',
              ),
              Tab(
                icon: Icon(
                  Icons.undo_rounded,
                  shadows: [
                    Shadow(
                      color: context.isDarkMode ? Colors.white : Colors.black,
                      offset: const Offset(1.5, 1.5),
                    )
                  ],
                ),
                text: 'Bỏ lỡ',
              ),
            ],
          ),
        ),
        body: Stack(
          children: [

            SafeArea(
              child: currentUserId == null
                  ? Center(
                      child: Text(
                        'Không xác định được tài khoản!',
                        style: TextStyle(color: context.textColor),
                      ),
                    )
                  : TabBarView(
                      children: [
                        _likedMeTab(currentUserId, isPremium),
                        _missedTab(currentUserId, isPremium),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
