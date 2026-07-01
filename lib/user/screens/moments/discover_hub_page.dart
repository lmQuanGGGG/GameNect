import 'package:flutter/material.dart';
import '../games/game_trending_screen.dart';
import '../mentor/all_mentor_media_screen.dart';
import 'mentor_post_preview_card.dart';
import 'trending_games_page.dart';
import 'trending_games_preview_card.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Trang Hub khám phá kết hợp cả "Trending Games" và "Mentor Posts" trên một màn hình duy nhất
/// giúp tối ưu hành trình vuốt dọc xem Moments (chỉ cần vuốt 1 lần thay vì 2 lần).
class DiscoverHubPage extends StatefulWidget {
  final bool isSplitMode;
  final double bottomPadding;

  const DiscoverHubPage({
    super.key,
    this.isSplitMode = false,
    this.bottomPadding = 120.0,
  });

  @override
  State<DiscoverHubPage> createState() => _DiscoverHubPageState();
}

class _DiscoverHubPageState extends State<DiscoverHubPage> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hubBgColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 900;
        final cardWidth = isLargeScreen ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth;
        // On narrow cards (width < 700), bar is 46, otherwise 58.
        final barHeight = cardWidth >= 700 ? 58.0 : 46.0;
        // If splitEvenly is true, media takes 50% width. For 1:1 media, height is cardWidth / 2.
        // If isWideLayout (cardWidth >= 700), media takes 45% width. For 1:1 media, height is cardWidth * 0.45.
        final expectedMediaWidth = cardWidth >= 700 ? cardWidth * 0.45 : (cardWidth - 4) / 2;
        final mentorCardHeight = expectedMediaWidth + barHeight;

        return VisibilityDetector(
          key: const Key('discover-hub-page'),
          onVisibilityChanged: (info) {
            final visible = info.visibleFraction > 0.6;

            if (_isVisible != visible) {
              setState(() {
                _isVisible = visible;
              });
            }
          },
          child: Container(
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
                    widget.bottomPadding,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLargeScreen)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TrendingGamesPreviewCard(
                                height: mentorCardHeight,
                                mediaAspectRatio: 1,
                                splitEvenly: true,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: MentorPostPreviewCard(
                                height: mentorCardHeight,
                                mediaAspectRatio: 1,
                                splitEvenly: true,
                                autoplayVideo: _isVisible,
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
                            ),
                          ],
                        )
                      else if (widget.isSplitMode) ...[
                        SizedBox(
                          height: 250,
                          child: Row(
                            children: [
                              const Expanded(
                                child: TrendingGamesPreviewCard(
                                  height: 250,
                                  mediaAspectRatio: 1,
                                  hideDetails: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: MentorPostPreviewCard(
                                  height: 250,
                                  mediaAspectRatio: 1.0,
                                  hideDetails: true,
                                  autoplayVideo: _isVisible,
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
                                    isLargeScreen: false,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AllMentorMediaScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const TrendingGamesPreviewCard(
                          height: 225,
                          mediaAspectRatio: 1,
                          splitEvenly: true,
                        ),
                        const SizedBox(height: 20),
                        MentorPostPreviewCard(
                          height: mentorCardHeight,
                          mediaAspectRatio: 1.0,
                          splitEvenly: true,
                          autoplayVideo: _isVisible,
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
                            isLargeScreen: false,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AllMentorMediaScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (!widget.isSplitMode) ...[
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
                            border: Border.all(color: borderColor, width: 1.5),
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
                    ],
                  ),
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
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(1.5, 1.5))],
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
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: shadowColor, offset: const Offset(1.5, 1.5)),
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
                border: Border.all(color: btnBorderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(color: btnShadowColor, offset: const Offset(1.5, 1.5)),
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
