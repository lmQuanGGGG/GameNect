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


          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildCardContent(isWeb: kIsWeb),
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
          color: const Color(0xFFF4F4F4), // Light background for high contrast
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(8, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game icon với glow effect -> Neo-Brutalism
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white, // White
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(4, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                size: 64,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'TRENDING GAMES',
              style: TextStyle(
                color: Colors.black,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Text(
                'KHÁM PHÁ NHỮNG TRÒ CHƠI HOT NHẤT\nVÀ TÌM BẠN CHƠI CÙNG NGAY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676), // Bright green
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('KHÁM PHÁ NGAY',
                        style: TextStyle(
                            color: Colors.black, fontSize: 16,
                            fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 24),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Swipe hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 242, 227, 230), // Pinkish
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_double_arrow_up_rounded,
                      color: Colors.black, size: 20),
                  SizedBox(width: 8),
                  Text('VUỐT LÊN ĐỂ XEM MOMENTS',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                ],
              ),
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
      child: _buildButtonContent(isWeb: kIsWeb),
    );
  }

  Widget _buildButtonContent({required bool isWeb}) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
            ),
          ],
        ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRENDING GAMES',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Khám phá game đang hot nhất',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black,
              size: 16,
            ),
          ),
        ],
      ),
      )
    );
  }
}
