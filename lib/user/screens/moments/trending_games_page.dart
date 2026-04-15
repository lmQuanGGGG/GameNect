import 'package:flutter/material.dart';
import 'dart:ui';
import '../games/game_trending_screen.dart';

/// Trang "Trending Games" được hiển thị ở vị trí đầu tiên trong PageView của FeedTab.
/// Toàn màn hình, có gradient background, icon game lớn và nút "Xem ngay".
class TrendingGamesPage extends StatelessWidget {
  const TrendingGamesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6200EA).withValues(alpha: 0.3),
                  Colors.black,
                  const Color(0xFFBB86FC).withValues(alpha: 0.2),
                ],
              ),
            ),
          ),

          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Game icon với glow effect
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFBB86FC), Color(0xFF6200EA)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBB86FC).withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.videogame_asset_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    '🎮 Trending Games',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Khám phá những trò chơi hot nhất\nhiện nay',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // CTA button
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GameTrendingScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFBB86FC), Color(0xFF6200EA)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFBB86FC).withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Xem ngay',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 18,
                                  fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Swipe hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swipe_down_rounded,
                          color: Colors.white.withValues(alpha: 0.5), size: 20),
                      const SizedBox(width: 8),
                      Text('Vuốt lên để xem Moments',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFBB86FC), Color(0xFF6200EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFBB86FC).withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.videogame_asset_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎮 Trending Games',
                      style: TextStyle(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  SizedBox(height: 4),
                  Text('Discover the hottest games right now',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
