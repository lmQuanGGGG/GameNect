import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/profile_card.dart';
import '../../../core/theme/theme_helper.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';

/// Màn hình xem profile người khác — Liquid Glass Dark Premium
/// Dùng chung cho: Chat, Lượt thích, Bỏ lỡ, Kết quả tìm kiếm...
class PeerProfileScreen extends StatelessWidget {
  final UserModel peerUser;
  final bool showActions;

  const PeerProfileScreen({super.key, required this.peerUser, this.showActions = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: context.appBarBgColor,
                border: Border(
                  bottom: BorderSide(
                    color: context.cardBorderColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    // Nút back kính mờ
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: context.cardBorderColor,
                                width: 0.8,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.chevron_left,
                                color: Color(0xFFFF6E40),
                                size: 28,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Avatar nhỏ + tên + rank
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: peerUser.avatarUrl?.isNotEmpty == true
                          ? NetworkImage(peerUser.avatarUrl!)
                          : null,
                      backgroundColor:
                          const Color(0xFFFF6E40).withValues(alpha: 0.3),
                      child: peerUser.avatarUrl == null
                          ? Icon(Icons.person,
                              size: 18, color: context.textColor)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peerUser.username,
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            peerUser.rank,
                            style: const TextStyle(
                              color: Color(0xFFFF6E40),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Orb cam trái trên — tạo hiệu ứng Liquid Glass
          Positioned(
            top: 0,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6E40).withValues(alpha: 0.12 * context.bgOrbOpacityMultiplier),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6E40).withValues(alpha: 0.08 * context.bgOrbOpacityMultiplier),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          // Orb cam tối phải dưới
          Positioned(
            bottom: 100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBF360C).withValues(alpha: 0.1 * context.bgOrbOpacityMultiplier),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBF360C).withValues(alpha: 0.08 * context.bgOrbOpacityMultiplier),
                    blurRadius: 120,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          // ProfileCard cuộn đầy đủ, tránh AppBar
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: showActions ? 100 : 24),
              child: ProfileCard(user: peerUser),
            ),
          ),
          // Nút Like
          if (showActions)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: () async {
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    if (currentUserId == null) return;

                    final firestoreService = FirestoreService();
                    await firestoreService.saveSwipeHistory(
                      userId: currentUserId, 
                      targetUserId: peerUser.id, 
                      action: 'like'
                    );

                    final isMutual = await firestoreService.checkMutualLike(
                      userId: currentUserId, 
                      targetUserId: peerUser.id
                    );

                    if (isMutual) {
                      await firestoreService.createNewMatch(
                        userIds: [currentUserId, peerUser.id],
                        game: 'Gamenect',
                      );
                    }
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (isMutual) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🎉 Đã Match thành công!')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã gửi lượt thích 💖')),
                        );
                      }
                    }
                  },
                  backgroundColor: const Color(0xFFFF6E40),
                  icon: const Icon(Icons.favorite, color: Colors.white),
                  label: const Text('Thích', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  elevation: 8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
