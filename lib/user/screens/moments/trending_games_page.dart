import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../games/game_trending_screen.dart';
import '../../../core/theme/theme_helper.dart';

/// Trang "Trending Games" được hiển thị ở vị trí đầu tiên trong PageView của FeedTab.
/// Toàn màn hình, có gradient background, icon game lớn và nút "Xem ngay".
class TrendingGamesPage extends StatelessWidget {
  const TrendingGamesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Hiệu ứng ánh sáng nền (Orbs)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6E40).withValues(alpha: 0.15 * context.bgOrbOpacityMultiplier),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.2 * context.bgOrbOpacityMultiplier), blurRadius: kIsWeb ? 40 : 100),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF8A65).withValues(alpha: 0.1 * context.bgOrbOpacityMultiplier),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF8A65).withValues(alpha: 0.15 * context.bgOrbOpacityMultiplier), blurRadius: kIsWeb ? 40 : 120),
                ],
              ),
            ),
          ),

          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                // Fix: Web (CanvasKit deploy) không render BackdropFilter đúng trên nền trong suốt → xám
                // Giải pháp: dùng Container màu đặc trên Web, BackdropFilter chỉ trên Mobile
                child: kIsWeb
                    ? _buildCardContent(isWeb: true)
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: _buildCardContent(isWeb: false),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent({required bool isWeb}) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.cardBgColor,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: context.cardBorderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game icon với glow effect
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.4),
                border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6E40).withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                size: 70,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'Trending Games',
              style: TextStyle(
                color: context.textColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Khám phá những trò chơi hot nhất\nvà tìm bạn chơi cùng ngay',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 40),

            // CTA button
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GameTrendingScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6E40), Color(0xFFE64A19)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6E40).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Khám phá ngay',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Swipe hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.keyboard_double_arrow_up_rounded,
                    color: context.textTertiaryColor, size: 24),
                const SizedBox(width: 8),
                Text('Vuốt lên để xem Moments',
                    style: TextStyle(
                        color: context.textTertiaryColor, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact version của Trending Games dùng trong Grid mode header.
class TrendingGamesButton extends StatelessWidget {
  const TrendingGamesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameTrendingScreen()),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        // Fix: trên Web dùng màu đặc thay BackdropFilter để tránh bug xám CanvasKit
        child: kIsWeb
            ? _buildButtonContent(isWeb: true)
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: _buildButtonContent(isWeb: false),
              ),
      ),
    );
  }

  Widget _buildButtonContent({required bool isWeb}) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.cardBorderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6E40).withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6E40).withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎮 Trending Games',
                    style: TextStyle(
                        color: context.textColor, fontSize: 18,
                        fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Text('Khám phá game đang hot nhất',
                    style: TextStyle(color: context.textSecondaryColor, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.cardBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_forward_ios_rounded, color: context.textColor, size: 16),
          ),
        ],
      ),
      )
    );
  }
}
