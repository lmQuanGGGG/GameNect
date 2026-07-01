import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/mentor_provider.dart';
import '../../../core/widgets/network_image.dart';
import 'mentor_profile_screen.dart';

final Map<String, String?> _globalGameImageCache = {};

Future<String?> _fetchGameImage(String gameName) async {
  if (_globalGameImageCache.containsKey(gameName)) {
    return _globalGameImageCache[gameName];
  }
  final apiKey =
      dotenv.env['RAWG_API_KEY'] ?? '754a38d2419a4aee8924fd13b8193b0f';
  try {
    final url =
        'https://api.rawg.io/api/games?key=$apiKey&search=$gameName&page_size=1';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      if (results.isNotEmpty) {
        final imageUrl = results.first['background_image'] as String?;
        _globalGameImageCache[gameName] = imageUrl;
        return imageUrl;
      }
    }
  } catch (e) {}
  _globalGameImageCache[gameName] = null;
  return null;
}

class MentorListScreen extends StatefulWidget {
  const MentorListScreen({super.key});

  @override
  State<MentorListScreen> createState() => _MentorListScreenState();
}

class _MentorListScreenState extends State<MentorListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Danh sách Mentor',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Consumer<MentorProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.approvedMentors.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final allMentors = provider.approvedMentors;
          final mentors = allMentors.where((m) {
            final name = (m['username'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: textColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: textColor,
                            offset: const Offset(1.5, 1.5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm mentor...',
                          hintStyle: TextStyle(
                            color: textColor.withValues(alpha: 0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: textColor,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Grid List
                  Expanded(
                    child: allMentors.isEmpty
                        ? const Center(child: Text('Chưa có Mentor nào.'))
                        : mentors.isEmpty
                        ? const Center(
                            child: Text('Không tìm thấy Mentor phù hợp.'),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              // Kiểm tra xem có phải màn hình lớn không
                              final isLargeScreen = constraints.maxWidth > 600;

                              // Giới hạn độ rộng của card để không bị quá to
                              // Màn hình càng rộng thì càng nhiều cột
                              int crossAxisCount =
                                  (constraints.maxWidth /
                                          (isLargeScreen ? 220 : 160))
                                      .floor();
                              if (crossAxisCount < 2) crossAxisCount = 2;

                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      // Thêm không gian dọc nếu hiển thị thêm text
                                      childAspectRatio: isLargeScreen
                                          ? 0.65
                                          : 0.8,
                                    ),
                                itemCount: mentors.length,
                                itemBuilder: (context, index) {
                                  final mentor = mentors[index];
                                  final double rating =
                                      (mentor['rating'] ?? 0.0).toDouble();
                                  final int reviews =
                                      (mentor['totalReviews'] ?? 0).toInt();
                                  final List<dynamic>? games =
                                      mentor['games'] as List<dynamic>?;
                                  final String gamesStr =
                                      (games != null && games.isNotEmpty)
                                      ? games.take(2).join(', ') +
                                            (games.length > 2 ? '...' : '')
                                      : 'Chưa cập nhật';

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
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: textColor,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: textColor,
                                            offset: const Offset(1.5, 1.5),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: isLargeScreen ? 84 : 72,
                                            height: isLargeScreen ? 84 : 72,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: textColor,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: GamenectNetworkImage(
                                                imageUrl:
                                                    mentor['avatarUrl'] ?? '',
                                                fit: BoxFit.cover,
                                                width: isLargeScreen ? 84 : 72,
                                                height: isLargeScreen ? 84 : 72,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            mentor['username'] ?? 'Mentor',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: isLargeScreen ? 18 : 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                          if (isLargeScreen) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.star_rounded,
                                                  color: Color(0xFFFF6E40),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${rating.toStringAsFixed(1)} ($reviews)',
                                                  style: TextStyle(
                                                    color: textColor.withValues(
                                                      alpha: 0.8,
                                                    ),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            if (games == null || games.isEmpty)
                                              Text(
                                                'Chưa cập nhật',
                                                style: TextStyle(
                                                  color: textColor.withValues(
                                                    alpha: 0.6,
                                                  ),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              )
                                            else
                                              Column(
                                                children: games.take(2).map((
                                                  gameName,
                                                ) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 4,
                                                        ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        FutureBuilder<String?>(
                                                          future:
                                                              _fetchGameImage(
                                                                gameName
                                                                    .toString(),
                                                              ),
                                                          builder: (context, snapshot) {
                                                            if (snapshot
                                                                    .hasData &&
                                                                snapshot.data !=
                                                                    null) {
                                                              return Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      right: 6,
                                                                    ),
                                                                child: ClipRRect(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                  child: GamenectNetworkImage(
                                                                    imageUrl:
                                                                        snapshot
                                                                            .data!,
                                                                    width: 16,
                                                                    height: 16,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                            return const SizedBox.shrink();
                                                          },
                                                        ),
                                                        Flexible(
                                                          child: Text(
                                                            gameName.toString(),
                                                            style: TextStyle(
                                                              color: textColor
                                                                  .withValues(
                                                                    alpha: 0.6,
                                                                  ),
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                          ],
                                          const Spacer(),
                                          SizedBox(
                                            width: double.infinity,
                                            height: isLargeScreen ? 36 : 32,
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _showRatingDialog(
                                                    context,
                                                    mentor['userId'],
                                                  ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: textColor,
                                                side: BorderSide(
                                                  color: textColor.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  width: 1.5,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text(
                                                'Viết đánh giá',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            height: isLargeScreen ? 40 : 36,
                                            child: ElevatedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        MentorProfileScreen(
                                                          mentorId:
                                                              mentor['userId'],
                                                        ),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFFF6E40,
                                                ),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  side: BorderSide(
                                                    color: textColor,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: const Text(
                                                'Xem hồ sơ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRatingDialog(BuildContext context, String mentorId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (currentUserId == mentorId) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    double selectedRating = 5.0;
    final commentCtrl = TextEditingController();
    bool isSubmitting = false;
    final messenger = ScaffoldMessenger.of(context);
    final mentorProvider = context.read<MentorProvider>();
    const kNeoOrange = Color(0xFFFF6E40);
    const kNeoRed = Color(0xFFFF4081);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: textColor, width: 3),
          ),
          title: Text(
            'ĐÁNH GIÁ MENTOR',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1.2,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BẠN THẤY MENTOR NÀY THẾ NÀO?',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1.0;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedRating = starVal);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        selectedRating >= starVal
                            ? Icons.star
                            : Icons.star_border,
                        color: selectedRating >= starVal
                            ? kNeoRed
                            : Colors.grey,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  border: Border.all(color: textColor, width: 3),
                  boxShadow: const [
                    BoxShadow(color: kNeoOrange, offset: Offset(4, 4)),
                  ],
                ),
                child: TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nhập ý kiến...',
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isSubmitting
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        border: Border.all(color: textColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: textColor,
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'HỦY',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() => isSubmitting = true);
                            final currentUserId =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (currentUserId == null) return;
                            final ok = await mentorProvider.rateMentor(
                              fromUserId: currentUserId,
                              toMentorId: mentorId,
                              rating: selectedRating,
                              comment: commentCtrl.text.trim(),
                            );
                            Navigator.pop(dialogContext);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Cảm ơn bạn đã đánh giá!'
                                        : 'Đánh giá thất bại',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: ok ? Colors.green : kNeoRed,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: kNeoOrange,
                        border: Border.all(color: textColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: textColor,
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'GỬI',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
