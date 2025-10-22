import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../../core/services/firestore_service.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/match_provider.dart';
import '../../core/widgets/profile_card.dart';
import 'subscription_screen.dart';

class LikedMeScreen extends StatefulWidget {
  const LikedMeScreen({super.key});

  @override
  State<LikedMeScreen> createState() => _LikedMeScreenState();
}

class _LikedMeScreenState extends State<LikedMeScreen> with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  bool isPremium = false;
  
  List<UserModel> _likedMeUsers = [];
  List<UserModel> _myDislikedUsers = [];
  
  Stream<List<UserModel>>? _likedMeStream;
  Stream<List<UserModel>>? _myDislikedStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final currentUser = await FirestoreService().getCurrentUser();
    if (currentUser != null && mounted) {
      setState(() {
        isPremium = currentUser.isPremium;
      });
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'lastSeenLikes': DateTime.now()});
    
    if (mounted) {
      final matchProvider = Provider.of<MatchProvider>(context, listen: false);
      
      _likedMeStream = matchProvider.streamLikedMeUsers(userId);
      _myDislikedStream = matchProvider.streamMyDislikedUsers(userId, limit: 1000);
      
      _likedMeStream!.listen((users) {
        if (mounted) {
          setState(() {
            _likedMeUsers = users;
          });
        }
      });
      
      _myDislikedStream!.listen((users) {
        if (mounted) {
          setState(() {
            _myDislikedUsers = users;
          });
        }
      });
      
      setState(() {
        isLoading = false;
      });
    }
  }

  // Banner nâng cấp Premium
  Widget _promoUpgrade(BuildContext context, {String message = 'Xem danh sách những người bạn đã bỏ lỡ và có thể thích lại!'}) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.5), width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.deepOrange, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Nâng cấp Premium',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.deepOrange),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Nâng cấp ngay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // Widget avatar với glassmorphism effect
  Widget _buildAvatar(UserModel user, {bool shouldBlur = false}) {
    Widget avatarContent;
    
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.network(
          user.avatarUrl!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
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

    // Glassmorphism effect cho avatar
    Widget glassAvatar = Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(2),
            child: avatarContent,
          ),
        ),
      ),
    );

    if (!shouldBlur) return glassAvatar;

    // Blur effect nếu chưa Premium
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

  // Tab 1: Người đã thích tôi (FREE chỉ xem 3 người, còn lại blur)
  Widget _likedMeTab(String currentUserId) {
    if (_likedMeUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có ai thích bạn!', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    final freeLimit = 3; // FREE chỉ xem 3 người
    final visibleCount = isPremium ? _likedMeUsers.length : freeLimit;
    final hasMore = _likedMeUsers.length > freeLimit;

    return ListView.builder(
      key: const PageStorageKey('liked_me_list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: isPremium ? _likedMeUsers.length : (_likedMeUsers.length + 1), // +1 cho banner quảng cáo
      itemBuilder: (context, index) {
        // Hiện banner quảng cáo sau 3 người (nếu FREE)
        if (!isPremium && index == freeLimit && hasMore) {
          final remainingCount = _likedMeUsers.length - freeLimit;
          return Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepOrange.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.5), width: 2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // 3 avatar xếp chồng nhau (blur)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Transform.translate(
                          offset: Offset(i * 30.0, 0),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: ClipOval(
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.person, size: 30, color: Colors.grey),
                                ),
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
                    color: Colors.deepOrange,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nâng cấp Premium để xem tất cả',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Xem ngay',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Lấy index user thực tế
        final userIndex = !isPremium && index > freeLimit ? index - 1 : index;
        if (userIndex >= _likedMeUsers.length) return const SizedBox.shrink();
        
        final user = _likedMeUsers[userIndex];
        final shouldBlur = !isPremium && userIndex >= freeLimit;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade50.withValues(alpha: 0.6),
                Colors.deepOrange.shade50.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.deepOrange.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: shouldBlur
                  ? () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                    }
                  : () {
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
                          Text(
                            shouldBlur ? '●●●●●●' : user.username,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shouldBlur ? '●● tuổi • ●●●●●●' : '${user.age} tuổi • ${user.location}',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (!shouldBlur)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.deepOrange, size: 28),
                            tooltip: 'Thích lại',
                            onPressed: () async {
                              final matchProvider = Provider.of<MatchProvider>(context, listen: false);
                              await matchProvider.saveSwipeHistory(currentUserId, user, true); // true = like
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Bạn đã thích lại ${user.username}!')),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                            tooltip: 'Bỏ qua',
                            onPressed: () async {
                              await FirestoreService().saveSwipeHistory(
                                userId: currentUserId,
                                targetUserId: user.id,
                                action: 'dislike',
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Bạn đã bỏ qua ${user.username}!')),
                                );
                              }
                            },
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Xem',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Tab 2: Bỏ lỡ (người đã dislike)
  Widget _missedTab(String currentUserId) {
    if (!isPremium) {
      return SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _promoUpgrade(context, message: 'Xem lại những người bạn đã bỏ lỡ và có cơ hội thích lại họ!'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.undo_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Tính năng Rewind',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
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

    if (_myDislikedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Chưa có ai bị bỏ lỡ!',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('missed_list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _myDislikedUsers.length,
      itemBuilder: (context, index) {
        final user = _myDislikedUsers[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade50.withValues(alpha: 0.6),
                Colors.deepOrange.shade50.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.deepOrange.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.age} tuổi • ${user.location}',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.undo_rounded, color: Colors.deepOrange, size: 28),
                      tooltip: 'Rewind - Thích lại',
                      onPressed: () async {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepOrange,
          elevation: 0,
          title: Row(
            children: const [
              Padding(
                padding: EdgeInsets.only(left: 12.0),
                child: Icon(Icons.sports_esports, color: Colors.deepOrange, size: 26),
              ),
              SizedBox(width: 8),
              Text('gamenect', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepOrange,
          elevation: 0,
          title: Row(
            children: const [
              Padding(
                padding: EdgeInsets.only(left: 12.0),
                child: Icon(Icons.sports_esports, color: Colors.deepOrange, size: 26),
              ),
              SizedBox(width: 8),
              Text('gamenect', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          actions: [
            if (isPremium)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              )
            else
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
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
              ),
          ],
          bottom: TabBar(
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepOrange,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [
              Tab(icon: Icon(Icons.favorite), text: 'Thích bạn'),
              Tab(icon: Icon(Icons.undo_rounded), text: 'Bỏ lỡ'),
            ],
          ),
        ),
        body: currentUserId == null
            ? const Center(child: Text('Không xác định được tài khoản!'))
            : TabBarView(
                children: [
                  _likedMeTab(currentUserId),
                  _missedTab(currentUserId),
                ],
              ),
      ),
    );
  }
}