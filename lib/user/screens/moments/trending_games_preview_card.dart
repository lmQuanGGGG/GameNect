import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/game_provider.dart';
import '../../../core/widgets/network_image.dart';
import '../games/game_trending_screen.dart';
import '../games/game_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/match_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/models/game_model.dart';
import '../matching/home_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';

class TrendingGamesPreviewCard extends StatefulWidget {
  final double height;
  final double mediaAspectRatio;
  final bool splitEvenly;
  final bool hideDetails;

  const TrendingGamesPreviewCard({
    super.key,
    required this.height,
    this.mediaAspectRatio = 0.65,
    this.splitEvenly = false,
    this.hideDetails = false,
  });

  @override
  State<TrendingGamesPreviewCard> createState() =>
      _TrendingGamesPreviewCardState();
}

class _TrendingGamesPreviewCardState extends State<TrendingGamesPreviewCard> {
  int _currentIndex = 0;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isAudioInitialized = false;

  @override
  void initState() {
    super.initState();
    if (!_isAudioInitialized) {
      _audioPlayer.setAsset('assets/sound/sounddd.mp3');
      _audioPlayer.setSpeed(1.0);
      _isAudioInitialized = true;
    }
  }

  @override
  void dispose() {
    // _audioPlayer.dispose(); // Do not dispose static instance
    super.dispose();
  }

  void _advanceGame(int totalGames) {
    if (totalGames <= 1) return;
    _audioPlayer.pause();
    _audioPlayer.seek(Duration.zero).then((_) => _audioPlayer.play());
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % totalGames;
        });
      }
    });
  }

  void _showShareBottomSheet(BuildContext context, GameModel game) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: Provider.of<MatchProvider>(
                context,
                listen: false,
              ).fetchMatchedUsersWithMatchId(currentUserId),
              builder: (context, snapshot) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: const Border(
                      top: BorderSide(color: Colors.black, width: 1.5),
                      left: BorderSide(color: Colors.black, width: 1.5),
                      right: BorderSide(color: Colors.black, width: 1.5),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(0, -4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 20),
                        width: 40,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const Text(
                        'CHIA SẺ GAME',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'GỬI "${game.name.toUpperCase()}" CHO BẠN BÈ',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: 'https://gamenect.vn/game/${game.id}'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'ĐÃ SAO CHÉP LIÊN KẾT',
                                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                  backgroundColor: Colors.white,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Colors.black, width: 1.5),
                                  ),
                                ),
                              );
                              Navigator.pop(bottomSheetContext);
                            },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black, width: 1.5),
                                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5))],
                                  ),
                                  child: const Icon(Icons.link, color: Colors.black, size: 24),
                                ),
                                const SizedBox(height: 8),
                                const Text('Copy Link', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Share.share('Xem game ${game.name} cực hay trên Gamenect ngay: https://gamenect.vn/game/${game.id}');
                              Navigator.pop(bottomSheetContext);
                            },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black, width: 1.5),
                                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5))],
                                  ),
                                  child: const Icon(Icons.share_outlined, color: Colors.black, size: 24),
                                ),
                                const SizedBox(height: 8),
                                const Text('Ứng dụng khác', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value.toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm bạn bè...',
                            hintStyle: const TextStyle(color: Colors.black54),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.black54,
                            ),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(
                        color: Colors.black,
                        height: 4,
                        thickness: 4,
                      ),
                      Expanded(
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF6E40),
                                ),
                              )
                            : snapshot.hasError ||
                                  !snapshot.hasData ||
                                  snapshot.data!.isEmpty
                            ? const Center(
                                child: Text(
                                  'BẠN CHƯA CÓ MATCH NÀO',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  final allMatches = snapshot.data!;
                                  final filteredMatches = searchQuery.isEmpty
                                      ? allMatches
                                      : allMatches.where((m) {
                                          final username =
                                              (m['user'].username ?? '')
                                                  .toLowerCase();
                                          return username.contains(searchQuery);
                                        }).toList();

                                  if (filteredMatches.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'KHÔNG TÌM THẤY BẠN BÈ',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    itemCount: filteredMatches.length,
                                    itemBuilder: (context, index) {
                                      final matchData = filteredMatches[index];
                                      final user = matchData['user'];
                                      final matchId = matchData['matchId'];

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 8,
                                            ),
                                        leading: ClipOval(
                                          child: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child:
                                                user.avatarUrl != null &&
                                                    user.avatarUrl!.isNotEmpty
                                                ? GamenectNetworkImage(
                                                    imageUrl: user.avatarUrl!,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Container(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                            ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Container(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                              child: const Icon(
                                                                Icons.person,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                            ),
                                                  )
                                                : Container(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.1),
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        title: Text(
                                          user.username ?? 'User',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        trailing: GestureDetector(
                                          onTap: () {
                                            Navigator.pop(bottomSheetContext);

                                            Provider.of<ChatProvider>(
                                              context,
                                              listen: false,
                                            ).sendGameMessage(
                                              matchId,
                                              game,
                                              peerUser: user,
                                            );

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'ĐÃ GỬI ${game.name.toUpperCase()} CHO ${user.username?.toUpperCase() ?? "BẠN BÈ"}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                backgroundColor: Colors.white,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: const BorderSide(
                                                    color: Colors.black,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.black,
                                                width: 1.5,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black,
                                                  offset: const Offset(1.5, 1.5),
                                                ),
                                              ],
                                            ),
                                            child: const Text(
                                              'GỬI',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
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
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStackLayer(Color borderColor, Color cardColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final provider = context.watch<GameProvider>();
    final games = provider.trendingGames;
    final topGame = games.isNotEmpty
        ? games[_currentIndex % games.length]
        : null;
    final stackCount = games.length > _currentIndex
        ? (games.length - _currentIndex).clamp(1, 3)
        : 1;

    if (topGame == null && !provider.isLoadingTrending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<GameProvider>().loadTrendingGames();
      });
    }

    final gameTitle = topGame?.name ?? 'TRENDING GAMES';
    final gameSubtitle = topGame != null && topGame.genres.isNotEmpty
        ? topGame.genres.join(' • ')
        : 'Khám phá các trò chơi hot nhất';
    final gameGenre = topGame != null && topGame.genres.isNotEmpty
        ? topGame.genres.first.toUpperCase()
        : 'GAMENECT HOT';
    final gameRating = topGame != null && topGame.rating > 0
        ? 'Rating: ${topGame.rating.toStringAsFixed(1)}'
        : 'Cập nhật hôm nay';

    return SizedBox(
      height: widget.height + (stackCount > 1 ? 12 : 0),
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (stackCount >= 3)
            Positioned(
              top: 12,
              left: 12,
              right: 0,
              bottom: 0,
              child: _buildStackLayer(borderColor, cardColor),
            ),
          if (stackCount >= 2)
            Positioned(
              top: 6,
              left: 6,
              right: 6,
              bottom: 6,
              child: _buildStackLayer(borderColor, cardColor),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.height,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(-0.18, -0.05),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: GestureDetector(
                key: ValueKey(topGame?.id ?? 0),
                onTap: () {
                  if (games.isNotEmpty) {
                    _advanceGame(games.length);
                  }
                },
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: borderColor, offset: const Offset(1.5, 1.5)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final onImageTap = () {
                        if (topGame != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  GameDetailScreen(gameId: topGame.id),
                            ),
                          );
                        }
                      };

                      final onButtonTap = () async {
                        if (topGame != null) {
                          final url = Uri.parse(
                            'https://rawg.io/games/${topGame.id}',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        }
                      };

                      final isWideLayout = constraints.maxWidth >= 500;
                      final isLargeDesktop = constraints.maxWidth >= 1200;
                      final hasVerticalSpace = constraints.maxHeight >= 260;
                      final barHeight = isWideLayout ? 58.0 : 46.0;
                      final mediaHeight = constraints.maxHeight - barHeight;
                      final gridRatioWidth =
                          mediaHeight * widget.mediaAspectRatio;
                      final maxMediaWidth =
                          constraints.maxWidth * (isWideLayout ? 0.45 : 0.62);

                      final mediaWidth = widget.hideDetails
                          ? constraints.maxWidth
                          : (widget.splitEvenly
                                ? (constraints.maxWidth - 4) / 2
                                : gridRatioWidth.clamp(0.0, maxMediaWidth));

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: widget.hideDetails ? 1 : 0,
                            child: ClipRRect(
                              borderRadius: widget.hideDetails
                                  ? BorderRadius.circular(12)
                                  : const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                              child: SizedBox(
                                width: mediaWidth,
                                height: constraints.maxHeight,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        color: const Color(0xFF00E676),
                                        child: topGame?.backgroundImage != null
                                            ? GamenectNetworkImage(
                                                imageUrl:
                                                    topGame!.backgroundImage!,
                                                fit: BoxFit.cover,
                                                width: mediaWidth,
                                              )
                                            : const Center(
                                                child: Icon(
                                                  Icons.sports_esports_rounded,
                                                  size: 80,
                                                  color: Colors.black,
                                                ),
                                              ),
                                      ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      height: barHeight,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isWideLayout ? 12 : 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        border: Border(
                                          top: BorderSide(
                                            color: borderColor,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: borderColor,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: Container(
                                                width: isWideLayout ? 34 : 26,
                                                height: isWideLayout ? 34 : 26,
                                                color: Colors.black,
                                                child: Icon(
                                                  Icons
                                                      .local_fire_department_rounded,
                                                  color: const Color(
                                                    0xFFFF6E40,
                                                  ),
                                                  size: isWideLayout ? 19 : 15,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: isWideLayout ? 9 : 6),
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  gameGenre,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: isWideLayout
                                                        ? 15
                                                        : 12,
                                                    height: 1,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                Text(
                                                  gameRating,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: textColor.withValues(
                                                      alpha: 0.85,
                                                    ),
                                                    fontSize: isWideLayout
                                                        ? 12
                                                        : 10,
                                                    height: 1,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (widget.hideDetails)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                GestureDetector(
                                                  onTap: onButtonTap,
                                                  child: Container(
                                                    color: Colors.transparent,
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    child: Icon(
                                                      Icons.language_rounded,
                                                      size: 18,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: () {
                                                    if (topGame != null) {
                                                      _showShareBottomSheet(
                                                        context,
                                                        topGame,
                                                      );
                                                    }
                                                  },
                                                  child: Container(
                                                    color: Colors.transparent,
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    child: Icon(
                                                      Icons.share_rounded,
                                                      size: 18,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: onImageTap,
                                                  child: Container(
                                                    color: Colors.transparent,
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    child: Icon(
                                                      Icons
                                                          .remove_red_eye_rounded,
                                                      size: 18,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 1.5),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!widget.hideDetails) ...[
                            Container(width: 1.5, color: borderColor),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (games.isNotEmpty) {
                                    _advanceGame(games.length);
                                  }
                                },
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    isWideLayout ? 20 : 12,
                                    hasVerticalSpace
                                        ? (isWideLayout ? 16 : 10)
                                        : 8,
                                    isWideLayout ? 20 : 12,
                                    hasVerticalSpace
                                        ? (isWideLayout ? 20 : 10)
                                        : 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Container(
                                              constraints: BoxConstraints(
                                                maxWidth: isWideLayout
                                                    ? 130
                                                    : 112,
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isWideLayout
                                                    ? 12
                                                    : 10,
                                                vertical: isWideLayout ? 8 : 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00E676),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: borderColor,
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: borderColor,
                                                    offset: const Offset(1.5, 1.5),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Flexible(
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        'HOT',
                                                        maxLines: 1,
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontSize: isWideLayout
                                                              ? 20
                                                              : 18,
                                                          height: 1,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: isWideLayout ? 7 : 5,
                                                  ),
                                                  Text(
                                                    'NHẤT',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: isWideLayout
                                                          ? 9
                                                          : 8,
                                                      height: 1,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      letterSpacing: 0.6,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 1.5),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const GameTrendingScreen(),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: borderColor,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Tất cả',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons
                                                        .arrow_forward_ios_rounded,
                                                    size: 10,
                                                    color: Colors.black,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: hasVerticalSpace
                                            ? (isWideLayout ? 14 : 10)
                                            : 6,
                                      ),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                gameTitle.toUpperCase(),
                                                textAlign: TextAlign.left,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: isLargeDesktop
                                                      ? 30
                                                      : (isWideLayout
                                                          ? 24
                                                          : 18),
                                                  height: 1.15,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ),

                                      SizedBox(
                                        height: hasVerticalSpace
                                            ? (isWideLayout ? 12 : 8)
                                            : 4,
                                      ),

                                            Flexible(
                                              child: Text(
                                                gameSubtitle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize:
                                                      isWideLayout ? 14 : 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              height: hasVerticalSpace
                                                  ? (isWideLayout ? 12 : 8)
                                                  : 4,
                                            ),

                                      // Nút "Chạm ảnh để xem"
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: borderColor,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Chạm ảnh để xem',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: isWideLayout ? 11 : 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Icon(
                                              Icons.touch_app_rounded,
                                              color: Colors.black,
                                              size: isWideLayout ? 16 : 15,
                                            ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                if (topGame != null) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          GameDetailScreen(
                                                            gameId: topGame.id,
                                                          ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: hasVerticalSpace
                                                      ? (isWideLayout ? 14 : 10)
                                                      : 8,
                                                  horizontal: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFF6E40,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: borderColor,
                                                    width: 1.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: borderColor,
                                                      offset: const Offset(
                                                        3,
                                                        3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'CHI TIẾT',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: isWideLayout
                                                              ? 16
                                                              : 12,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Icon(
                                                        Icons
                                                            .sports_esports_rounded,
                                                        color: Colors.white,
                                                        size: isWideLayout
                                                            ? 22
                                                            : 18,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: isWideLayout ? 12 : 8,
                                          ),
                                          GestureDetector(
                                            onTap: () async {
                                              if (topGame != null) {
                                                final url = Uri.parse(
                                                  'https://rawg.io/games/${topGame.id}',
                                                );
                                                if (await canLaunchUrl(url)) {
                                                  await launchUrl(url);
                                                }
                                              }
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(
                                                hasVerticalSpace
                                                    ? (isWideLayout ? 11 : 7)
                                                    : 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: borderColor,
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: borderColor,
                                                    offset: const Offset(1.5, 1.5),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.language_rounded,
                                                color: Colors.black,
                                                size: isWideLayout ? 26 : 20,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: isWideLayout ? 12 : 8,
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              if (topGame != null) {
                                                _showShareBottomSheet(
                                                  context,
                                                  topGame,
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(
                                                hasVerticalSpace
                                                    ? (isWideLayout ? 11 : 7)
                                                    : 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: borderColor,
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: borderColor,
                                                    offset: const Offset(1.5, 1.5),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.share_rounded,
                                                color: Colors.black,
                                                size: isWideLayout ? 26 : 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
