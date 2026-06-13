import 'package:flutter/material.dart';
import '../games/game_trending_screen.dart';
import '../mentor/all_mentor_media_screen.dart';

/// Trang Hub khám phá kết hợp cả "Trending Games" và "Mentor Posts" trên một màn hình duy nhất
/// giúp tối ưu hành trình vuốt dọc xem Moments (chỉ cần vuốt 1 lần thay vì 2 lần).
class DiscoverHubPage extends StatelessWidget {
  const DiscoverHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hubBgColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;

    return Container(
      color: hubBgColor,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                // Tiêu đề chính dạng Neo-Brutalism
                Text(
                  'GAMENECT HUB',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        color: Colors.deepOrange.withValues(alpha: 0.5),
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Card 1: Trending Games
                _buildDiscoverCard(
                  context,
                  title: 'TRENDING GAMES',
                  description: 'KHÁM PHÁ CÁC TRÒ CHƠI HOT NHẤT & TÌM BẠN CHƠI',
                  icon: Icons.sports_esports_rounded,
                  buttonText: 'KHÁM PHÁ',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GameTrendingScreen()),
                  ),
                ),
                const SizedBox(height: 20),

                // Card 2: Mentor Posts
                _buildDiscoverCard(
                  context,
                  title: 'MENTOR POSTS',
                  description: 'HÌNH ẢNH & VIDEO ĐỘC QUYỀN TỪ CÁC MENTOR XỊN XÒ',
                  icon: Icons.auto_awesome_mosaic_rounded,
                  buttonText: 'XEM NGAY',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllMentorMediaScreen()),
                  ),
                ),
                const SizedBox(height: 28),

                // Hint vuốt lên
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E24) : const Color.fromARGB(255, 242, 227, 230),
                    border: Border.all(color: borderColor, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_double_arrow_up_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'VUỐT LÊN ĐỂ XEM MOMENTS',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E1E24) : const Color(0xFFF4F4F4);
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    // Neo Brutalism button color scheme (unified white/black)
    final btnBgColor = isDark ? Colors.black : Colors.white;
    final btnTextColor = isDark ? Colors.white : Colors.black;
    final btnBorderColor = isDark ? Colors.white : Colors.black;
    final btnShadowColor = isDark ? Colors.white : Colors.black;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(8, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                ),
                child: Icon(icon, size: 36, color: textColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: btnBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: btnBorderColor, width: 3),
                boxShadow: [
                  BoxShadow(color: btnShadowColor, offset: const Offset(3, 3)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: TextStyle(
                      color: btnTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: btnTextColor, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
