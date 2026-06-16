import 'package:flutter/material.dart';
import '../games/game_trending_screen.dart';
import '../mentor/all_mentor_media_screen.dart';
import 'mentor_post_preview_card.dart';
import 'trending_games_page.dart';

/// Trang Hub khám phá kết hợp cả "Trending Games" và "Mentor Posts" trên một màn hình duy nhất
/// giúp tối ưu hành trình vuốt dọc xem Moments (chỉ cần vuốt 1 lần thay vì 2 lần).
class DiscoverHubPage extends StatelessWidget {
  const DiscoverHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hubBgColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 900;
        final mentorMediaSize = (constraints.maxWidth * 0.24).clamp(
          360.0,
          620.0,
        );
        final mentorCardHeight = isLargeScreen ? mentorMediaSize + 58 : 250.0;

        return Container(
          color: hubBgColor,
          child: SafeArea(
            top: false,
            bottom: false,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isLargeScreen ? 12 : 8,
                  isLargeScreen ? 12 : 20,
                  isLargeScreen ? 12 : 8,
                  120,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: isLargeScreen ? 80 : 68),
                      child: isLargeScreen
                          ? const TrendingGamesButton()
                          : _buildDiscoverCard(
                              context,
                              title: 'TRENDING GAMES',
                              description:
                                  'KHÁM PHÁ CÁC TRÒ CHƠI HOT NHẤT & TÌM BẠN CHƠI',
                              icon: Icons.sports_esports_rounded,
                              buttonText: 'KHÁM PHÁ',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GameTrendingScreen(),
                                ),
                              ),
                            ),
                    ),
                    SizedBox(height: isLargeScreen ? 12 : 20),
                    MentorPostPreviewCard(
                      height: mentorCardHeight,
                      mediaAspectRatio: 1,
                      autoplayVideo: true,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllMentorMediaScreen(),
                          ),
                        );
                      },
                      fallback: _buildDiscoverCard(
                        context,
                        title: 'MENTOR POSTS',
                        description:
                            'HÌNH ẢNH & VIDEO ĐỘC QUYỀN TỪ CÁC MENTOR XỊN XÒ',
                        icon: Icons.auto_awesome_mosaic_rounded,
                        buttonText: 'XEM NGAY',
                        isLargeScreen: isLargeScreen,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllMentorMediaScreen(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isLargeScreen ? 32 : 28),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 22 : 16,
                        vertical: isLargeScreen ? 11 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E24)
                            : const Color.fromARGB(255, 242, 227, 230),
                        border: Border.all(color: borderColor, width: 2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_double_arrow_up_rounded,
                            color: isDark ? Colors.white : Colors.black,
                            size: isLargeScreen ? 24 : 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'VUỐT LÊN ĐỂ XEM MOMENTS',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: isLargeScreen ? 15 : 12,
                              fontWeight: FontWeight.w900,
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
        );
      },
    );
  }

  Widget _buildDiscoverCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required String buttonText,
    required VoidCallback onTap,
    bool isLargeScreen = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark
        ? const Color(0xFF1E1E24)
        : const Color(0xFFF4F4F4);
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
      padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(4, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isLargeScreen ? 15 : 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: shadowColor, offset: const Offset(3, 3)),
                  ],
                ),
                child: Icon(
                  icon,
                  size: isLargeScreen ? 42 : 36,
                  color: textColor,
                ),
              ),
              SizedBox(width: isLargeScreen ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: isLargeScreen ? 23 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: textColor,
                        fontSize: isLargeScreen ? 15 : 12,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 24 : 20),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 15 : 12),
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
                      fontSize: isLargeScreen ? 17 : 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: btnTextColor,
                    size: isLargeScreen ? 22 : 18,
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
