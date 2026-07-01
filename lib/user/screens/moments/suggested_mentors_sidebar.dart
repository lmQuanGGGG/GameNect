import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/mentor_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/widgets/network_image.dart';
import '../mentor/mentor_profile_screen.dart';
import '../mentor/mentor_list_screen.dart';

class SuggestedMentorsSidebar extends StatefulWidget {
  final bool isHorizontal;
  final bool showFooter;

  const SuggestedMentorsSidebar({
    super.key,
    this.isHorizontal = false,
    this.showFooter = true,
  });

  @override
  State<SuggestedMentorsSidebar> createState() =>
      _SuggestedMentorsSidebarState();
}

class _SuggestedMentorsSidebarState extends State<SuggestedMentorsSidebar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MentorProvider>(context, listen: false);
      if (provider.approvedMentors.isEmpty) {
        provider.loadApprovedMentors();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textSecondaryColor = isDark ? Colors.white70 : Colors.black54;

    return Consumer2<MentorProvider, ProfileProvider>(
      builder: (context, provider, profileProvider, child) {
        if (provider.isLoading && provider.approvedMentors.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final myGames = profileProvider.userData?.favoriteGames ?? [];

        // Sắp xếp mentor theo số lượng game trùng khớp với user
        final sortedMentors = List<Map<String, dynamic>>.from(
          provider.approvedMentors,
        );
        if (myGames.isNotEmpty) {
          sortedMentors.sort((a, b) {
            final aGames =
                (a['games'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final bGames =
                (b['games'] as List?)?.map((e) => e.toString()).toList() ?? [];

            final aMatch = aGames
                .where((game) => myGames.contains(game))
                .length;
            final bMatch = bGames
                .where((game) => myGames.contains(game))
                .length;

            return bMatch.compareTo(aMatch); // Giảm dần
          });
        }

        final mentors = sortedMentors.take(5).toList();

        if (mentors.isEmpty) {
          return const SizedBox.shrink();
        }

        if (widget.isHorizontal) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gợi ý Mentor cho bạn',
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MentorListScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Xem tất cả',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: mentors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final mentor = mentors[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MentorProfileScreen(
                                mentorId: mentor['userId'],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: textColor.withAlpha(25)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: textColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: GamenectNetworkImage(
                                    imageUrl: mentor['avatarUrl'] ?? '',
                                    fit: BoxFit.cover,
                                    width: 64,
                                    height: 64,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                mentor['username'] ?? 'Mentor',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Gợi ý',
                                style: TextStyle(
                                  color: textSecondaryColor,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MentorProfileScreen(
                                            mentorId: mentor['userId'],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Icon(
                                      Icons.remove_red_eye_rounded,
                                      color: textColor,
                                      size: 22,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    onPressed: () {},
                                    icon: Icon(
                                      Icons.person_add_rounded,
                                      color: textColor,
                                      size: 22,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gợi ý Mentor cho bạn',
                      style: TextStyle(
                        color: textSecondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MentorListScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Xem tất cả',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...mentors.map((mentor) {
                return Container(
                  margin: const EdgeInsets.only(
                    bottom: 16,
                    left: 16,
                    right: 16,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: textColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: textColor,
                        offset: const Offset(1.5, 1.5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MentorProfileScreen(
                                mentorId: mentor['userId'],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: textColor, width: 1.5),
                          ),
                          child: ClipOval(
                            child: GamenectNetworkImage(
                              imageUrl: mentor['avatarUrl'] ?? '',
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MentorProfileScreen(
                                  mentorId: mentor['userId'],
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mentor['username'] ?? 'Mentor',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Gợi ý Mentor cho bạn',
                                style: TextStyle(
                                  color: textSecondaryColor,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MentorProfileScreen(
                                mentorId: mentor['userId'],
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.remove_red_eye_rounded,
                          color: textColor,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(
                          Icons.person_add_rounded,
                          color: textColor,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
              if (widget.showFooter) ...[
                const SizedBox(height: 24),
                Text(
                  'Giới thiệu · Trợ giúp · Báo chí · API · Việc làm · Quyền riêng tư · Điều khoản · Vị trí · Ngôn ngữ · Gamenect đã xác minh',
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '© 2026 GAMENECT BY MINH QUANG',
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
