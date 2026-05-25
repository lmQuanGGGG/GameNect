import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/profile_card.dart';
import '../../../core/theme/theme_helper.dart';

/// Màn hình xem profile người khác — Liquid Glass Dark Premium
/// Dùng chung cho: Chat, Lượt thích, Bỏ lỡ, Kết quả tìm kiếm...
class PeerProfileScreen extends StatelessWidget {
  final UserModel peerUser;

  const PeerProfileScreen({super.key, required this.peerUser});

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
              padding: const EdgeInsets.only(bottom: 24),
              child: ProfileCard(user: peerUser),
            ),
          ),
        ],
      ),
    );
  }
}
