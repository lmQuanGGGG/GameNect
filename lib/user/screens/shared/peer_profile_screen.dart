import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/profile_card.dart';
import '../../../core/theme/theme_helper.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/match_provider.dart';
import '../matching/home_screen.dart';

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
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.textColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.textColor,
                              offset: const Offset(4, 4),
                            ),
                          ],
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
                    const SizedBox(width: 12),
                    // Avatar nhỏ + tên + rank
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: peerUser.avatarUrl?.isNotEmpty == true
                          ? NetworkImage(peerUser.avatarUrl!)
                          : null,
                      backgroundColor:
                          context.textColor.withValues(alpha: 0.1),
                      child: peerUser.avatarUrl == null
                          ? const Icon(Icons.person,
                              size: 18, color: Color(0xFFFF6E40))
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
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.w900,
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
          // ProfileCard cuộn đầy đủ, tránh AppBar
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: showActions ? 100 : 24),
              child: ProfileCard(user: peerUser),
            ),
          ),
          // Nút Dislike và Like
          if (showActions)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Nút Dislike (X)
                  Container(
                    decoration: BoxDecoration(
                      color: context.scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.textColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: context.textColor,
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 36,
                      padding: const EdgeInsets.all(16),
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () async {
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        if (currentUserId == null) {
                          // Chặn Khách
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const HomeScreen()),
                            );
                          }
                          return;
                        }
                        
                        if (currentUserId != null) {
                          await FirestoreService().saveSwipeHistory(
                            userId: currentUserId,
                            targetUserId: peerUser.id,
                            action: 'dislike'
                          );
                        }
                        
                        if (context.mounted) {
                          try {
                            Provider.of<MatchProvider>(context, listen: false)
                                .removeRecommendation(peerUser.id);
                          } catch (_) {}
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Nút Like (Heart)
                  Container(
                    decoration: BoxDecoration(
                      color: context.textColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.textColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: context.textColor,
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: () async {
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        if (currentUserId == null) {
                          // Chặn Khách
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const HomeScreen()),
                            );
                          }
                          return;
                        }

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
                          try {
                            Provider.of<MatchProvider>(context, listen: false)
                                .removeRecommendation(peerUser.id);
                          } catch (_) {}
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
                      backgroundColor: context.textColor,
                      icon: const Icon(Icons.favorite, color: Color(0xFFFF6E40)),
                      label: Text('Thích', style: TextStyle(color: context.scaffoldBackgroundColor, fontWeight: FontWeight.w900, fontSize: 16)),
                      elevation: 0,
                      highlightElevation: 0,
                      hoverElevation: 0,
                      focusElevation: 0,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
