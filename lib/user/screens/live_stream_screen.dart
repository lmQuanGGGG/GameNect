// lib/user/screens/live_stream_screen.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:replay_kit_launcher/replay_kit_launcher.dart';
import '../../core/providers/livestream_provider.dart';
import '../../core/providers/profile_provider.dart';

const _kAccent = Color(0xFFFF6E40);
const _kLiveBadge = Color(0xFFFF3B30);
const _kGlassBg = Color(0x14FFFFFF);
const _kGlassBorder = Color(0x1FFFFFFF);

// Gift definitions
const _kGifts = [
  {'type': 'heart', 'emoji': '❤️', 'name': 'Tim', 'coins': 1},
  {'type': 'star', 'emoji': '⭐', 'name': 'Ngôi sao', 'coins': 5},
  {'type': 'diamond', 'emoji': '💎', 'name': 'Hồng ngọc', 'coins': 20},
  {'type': 'crown', 'emoji': '👑', 'name': 'Kim cương', 'coins': 50},
];

/// Màn hình xem / phát Livestream — Task 6.3
class LiveStreamScreen extends StatefulWidget {
  final String streamId;
  final bool isMentor;

  const LiveStreamScreen({
    super.key,
    required this.streamId,
    required this.isMentor,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _canPop = false;
  String? _mentorUsername;
  String? _mentorAvatarUrl;
  int _viewerCount = 0;

  // Floating likes list for TikTok tap-to-like
  final List<FloatingLike> _likes = [];
  int _likeCounter = 0;

  void _addLike() {
    final random = Random();
    final colors = [
      Colors.pinkAccent,
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.lightBlueAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
    ];
    final icons = [
      Icons.favorite,
      Icons.favorite_border,
      Icons.star,
      Icons.emoji_emotions_rounded,
      Icons.thumb_up_rounded,
    ];
    setState(() {
      _likeCounter++;
      _likes.add(FloatingLike(
        id: _likeCounter,
        x: random.nextDouble() * 80 + 20, // Offset from right side
        color: colors[random.nextInt(colors.length)],
        icon: icons[random.nextInt(icons.length)],
      ));
    });
  }

  // Gift animation
  String? _giftAnimEmoji;
  String? _giftAnimUsername;
  Timer? _giftTimer;

  StreamSubscription? _streamInfoSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.loadUserProfile();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Load coin balance
      await context.read<LivestreamProvider>().loadUserCoins(currentUserId);

      if (widget.isMentor) {
        // Mentor đã join qua GoLiveScreen — chỉ cần listen messages
        context.read<LivestreamProvider>().listenToMessages(widget.streamId);
      } else {
        // Viewer join stream
        await context.read<LivestreamProvider>().joinStream(widget.streamId);
      }

      // Listen stream info
      _streamInfoSub = FirebaseFirestore.instance
          .collection('livestreams')
          .doc(widget.streamId)
          .snapshots()
          .listen((doc) {
        if (!doc.exists) return;
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _mentorUsername = data['mentorUsername'];
            _mentorAvatarUrl = data['mentorAvatarUrl'];
            _viewerCount = (data['viewerCount'] ?? 0).toInt();
          });
          // Nếu stream ended và đang là viewer thì pop
          if (data['status'] == 'ended' && !widget.isMentor) {
            _showStreamEndedDialog();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _streamInfoSub?.cancel();
    _giftTimer?.cancel();
    if (!widget.isMentor) {
      context.read<LivestreamProvider>().leaveStream(widget.streamId);
    }
    super.dispose();
  }

  void _showStreamEndedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Stream đã kết thúc', style: TextStyle(color: Colors.white)),
        content: const Text('Mentor đã kết thúc livestream.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              if (mounted) {
                setState(() {
                  _canPop = true;
                });
                Navigator.pop(context); // Close screen
              }
            },
            child: const Text('OK', style: TextStyle(color: _kAccent)),
          ),
        ],
      ),
    );
  }

  void _triggerGiftAnimation(String emoji, String username) {
    setState(() {
      _giftAnimEmoji = emoji;
      _giftAnimUsername = username;
    });
    _giftTimer?.cancel();
    _giftTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() { _giftAnimEmoji = null; _giftAnimUsername = null; });
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final currentUser = FirebaseAuth.instance.currentUser;
    final profileProvider = context.read<ProfileProvider>();
    final username = profileProvider.userData?.username ?? 'User';
    final avatarUrl = profileProvider.userData?.avatarUrl ?? '';

    await context.read<LivestreamProvider>().sendMessage(
      widget.streamId,
      currentUser?.uid ?? '',
      username,
      avatarUrl,
      text,
    );
  }

  void _showGiftSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tặng quà', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Consumer<LivestreamProvider>(
                    builder: (_, p, child) => Row(
                      children: [
                        const Text('💰', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text('${p.myCoins} coins', style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: _kGifts.map((gift) => _buildGiftItem(gift, ctx)).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGiftItem(Map<String, dynamic> gift, BuildContext sheetCtx) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(sheetCtx);
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        final profileProvider = context.read<ProfileProvider>();
        final username = profileProvider.userData?.username ?? 'User';
        final avatarUrl = profileProvider.userData?.avatarUrl ?? '';
        final mentorId = (await FirebaseFirestore.instance
            .collection('livestreams')
            .doc(widget.streamId)
            .get())
            .data()?['mentorId'] ?? '';

        final ok = await context.read<LivestreamProvider>().sendGift(
          streamId: widget.streamId,
          fromUserId: currentUser.uid,
          toMentorId: mentorId,
          fromUsername: username,
          fromAvatarUrl: avatarUrl,
          giftType: gift['type'],
          coinValue: gift['coins'],
        );

        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không đủ coin!'), backgroundColor: Colors.red),
          );
        } else {
          _triggerGiftAnimation(gift['emoji'], username);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _kGlassBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kGlassBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(gift['emoji'], style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(gift['name'], style: const TextStyle(color: Colors.white70, fontSize: 10)),
            Text('${gift['coins']} coin', style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _endStream() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kết thúc Stream?', style: TextStyle(color: Colors.white)),
        content: const Text('Stream sẽ kết thúc và tất cả người xem sẽ bị thoát.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        final provider = context.read<LivestreamProvider>();
        setState(() {
          _canPop = true;
        });
        // Pop screen immediately so user is not stuck on exit
        Navigator.pop(context);
        // Execute the stream termination and cleanup in background using the pre-resolved provider
        provider.endStream(widget.streamId).catchError((e) {
          debugPrint("Error ending stream: $e");
        });
      }
    }
  }

  Widget _buildPureVideoView() {
    return Center(child: _buildVideoView());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LivestreamProvider>();
    // Auto-detect PiP if screen width is extremely small (system transitions or overlay size)
    final isSystemPiP = provider.isSystemPiP || MediaQuery.of(context).size.width < 300;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.isMentor) {
          _endStream();
        } else {
          // Minimizes and leaves screen
          context.read<LivestreamProvider>().minimize(context, widget.streamId, false);
          if (mounted) {
            setState(() {
              _canPop = true;
            });
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false, // Prevents squishing the video background
        body: isSystemPiP
            ? _buildPureVideoView()
            : Stack(
                children: [
                  // ── Video background ──────────────────────────────────────────────
                  GestureDetector(
                    onTap: widget.isMentor ? null : _addLike,
                    child: _buildVideoView(),
                  ),

          // ── Top overlay ───────────────────────────────────────────────────
          if (MediaQuery.of(context).size.width > 300)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 280) {
                        return Align(
                          alignment: Alignment.topRight,
                          child: GestureDetector(
                            onTap: widget.isMentor ? _endStream : () => Navigator.pop(context),
                            child: Container(
                              width: 36, height: 36,
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.isMentor ? Icons.stop : Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      return Row(
                        children: [
                          // Sleek unified Broadcaster Pill (TikTok-style)
                          Container(
                            padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_mentorAvatarUrl != null)
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundImage: NetworkImage(_mentorAvatarUrl!),
                                  )
                                else
                                  const CircleAvatar(
                                    radius: 13,
                                    backgroundColor: Colors.white12,
                                    child: Icon(Icons.person, size: 13, color: Colors.white70),
                                  ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 80),
                                  child: Text(
                                    _mentorUsername ?? 'Mentor',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (!widget.isMentor) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: _kAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, color: Colors.white, size: 8),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Overlapping Viewer Avatars + Viewer count (TikTok style)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.circle, color: _kLiveBadge, size: 6),
                                const SizedBox(width: 4),
                                const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                const SizedBox(width: 6),
                                const Icon(Icons.remove_red_eye, color: Colors.white70, size: 11),
                                const SizedBox(width: 3),
                                Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Close / End button
                          GestureDetector(
                            onTap: widget.isMentor ? _endStream : () => Navigator.pop(context),
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: widget.isMentor ? Colors.red.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Icon(
                                widget.isMentor ? Icons.stop : Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

          // ── Gift animation overlay ─────────────────────────────────────────
          if (_giftAnimEmoji != null)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: 0, right: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.scale(scale: 0.8 + 0.2 * v, child: child),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_giftAnimEmoji!, style: const TextStyle(fontSize: 36)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_giftAnimUsername ?? '', style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                            const Text('đã tặng quà!', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Floating likes overlay ────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: _likes.map<Widget>((like) {
                  return _FloatingHeartWidget(
                    key: ValueKey(like.id),
                    like: like,
                    onComplete: () {
                      setState(() {
                        _likes.removeWhere((l) => l.id == like.id);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Bottom overlay ─────────────────────────────────────────────────
          if (MediaQuery.of(context).size.width > 300)
            Positioned(
              left: 0, right: 0, 
              bottom: MediaQuery.of(context).viewInsets.bottom,
              child: SafeArea(
              top: false,
              child: Consumer<LivestreamProvider>(
                builder: (context, provider, _) {
                  // Scroll to bottom when new message
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.animateTo(
                        _scrollCtrl.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  final keyboardIsOpen = MediaQuery.of(context).viewInsets.bottom > 0;

                  return Column(
                    children: [
                      // Chat messages
                      SizedBox(
                        height: keyboardIsOpen ? 120 : 200,
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: provider.messages.length,
                          itemBuilder: (context, i) {
                            final msg = provider.messages[i];
                            final isGift = msg['type'] == 'gift';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (msg['avatarUrl'] != null && (msg['avatarUrl'] as String).isNotEmpty)
                                    Container(
                                      width: 20, height: 20,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: NetworkImage(msg['avatarUrl']),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Flexible(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isGift
                                                ? _kAccent.withValues(alpha: 0.25)
                                                : Colors.black.withValues(alpha: 0.55),
                                            borderRadius: BorderRadius.circular(12),
                                            border: isGift ? Border.all(color: _kAccent.withValues(alpha: 0.4)) : null,
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '${msg['username'] ?? 'User'} ',
                                                  style: TextStyle(
                                                    color: isGift ? _kAccent : Colors.white70,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (isGift)
                                                  TextSpan(
                                                    text: 'tặng ${_giftEmoji(msg['giftType'])} ${msg['giftType']}!',
                                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                                  )
                                                else
                                                  TextSpan(
                                                    text: msg['text'] ?? '',
                                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Chat input (Viewer only) or Stats (Mentor)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: widget.isMentor
                            ? _buildMentorStats()
                            : _buildViewerInput(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildVideoView() {
    return Consumer<LivestreamProvider>(
      builder: (context, provider, _) {
        if (provider.engine == null) {
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: _kAccent),
            ),
          );
        }

        if (widget.isMentor) {
          if (provider.isScreenSharing) {
            // Sleek glassmorphic card for mentor when sharing screen (prevents infinity mirror)
            return Container(
              color: const Color(0xFF101012),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kAccent.withValues(alpha: 0.15),
                              border: Border.all(color: _kAccent, width: 2),
                            ),
                            child: const Icon(
                              Icons.screen_share_rounded,
                              color: _kAccent,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Đang Chia Sẻ Màn Hình',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Khán giả đang xem trực tiếp màn hình thiết bị của bạn.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: provider.stopScreenShare,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.stop_screen_share_rounded, size: 18),
                            label: const Text('Dừng chia sẻ'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // Local camera preview
          return AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: provider.engine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          );
        } else {
          // Remote broadcaster video
          if (provider.remoteUid == null) {
            return Container(
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _kAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Đang kết nối với Mentor...',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            );
          }
          return AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: provider.engine!,
              canvas: VideoCanvas(
                uid: provider.remoteUid!,
                renderMode: RenderModeType.renderModeFit,
              ),
              connection: RtcConnection(channelId: widget.streamId),
            ),
          );
        }
      },
    );
  }

  Widget _buildViewerInput() {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
              color: _kAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Gift
        GestureDetector(
          onTap: _showGiftSheet,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              shape: BoxShape.circle,
            ),
            child: const Text('🎁', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 8),
        // Heart Like button (TikTok Tap-to-like)
        GestureDetector(
          onTap: _addLike,
          child: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
              color: Colors.pink,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildMentorStats() {
    return Consumer<LivestreamProvider>(
      builder: (context, provider, _) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge('👁️', '$_viewerCount', 'Viewers'),
                _buildStatBadge('💬', '${provider.messages.where((m) => m['type'] == 'text').length}', 'Chats'),
                _buildStatBadge('🎁', '${provider.messages.where((m) => m['type'] == 'gift').length}', 'Gifts'),
                // Screen Sharing Control
                GestureDetector(
                  onTap: () async {
                    if (provider.isScreenSharing) {
                      await provider.stopScreenShare();
                    } else {
                      if (Theme.of(context).platform == TargetPlatform.iOS) {
                        try {
                          await ReplayKitLauncher.launchReplayKitBroadcast('GamenectScreenShare');
                        } catch (e) {
                          debugPrint('Error launching ReplayKit: $e');
                        }
                      }
                      await provider.startScreenShare();
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                        color: provider.isScreenSharing ? _kAccent : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.isScreenSharing ? 'Dừng Share' : 'Chia sẻ MH',
                        style: TextStyle(
                          color: provider.isScreenSharing ? _kAccent : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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
  }

  Widget _buildStatBadge(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
      ],
    );
  }

  String _giftEmoji(String? type) {
    switch (type) {
      case 'heart': return '❤️';
      case 'star': return '⭐';
      case 'diamond': return '💎';
      case 'crown': return '👑';
      default: return '🎁';
    }
  }
}

// ── Tap-to-like helper models and widgets ────────────────────────────────────

class FloatingLike {
  final int id;
  final double x;
  final Color color;
  final IconData icon;

  FloatingLike({required this.id, required this.x, required this.color, required this.icon});
}

class _FloatingHeartWidget extends StatefulWidget {
  final FloatingLike like;
  final VoidCallback onComplete;

  const _FloatingHeartWidget({super.key, required this.like, required this.onComplete});

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnim;
  late Animation<double> _xAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _yAnim = Tween<double>(begin: 0.0, end: 320.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Sine wave horizontal wiggle input
    _xAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.2), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _opacityAnim = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Horizontal offset with sine wiggle
        final wiggle = sin(_xAnim.value * 3 * pi) * 16;
        final xPos = MediaQuery.of(context).size.width - widget.like.x + wiggle - 40;
        final yPos = MediaQuery.of(context).size.height - _yAnim.value - 120;

        return Positioned(
          left: xPos,
          top: yPos,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Icon(
                widget.like.icon,
                color: widget.like.color,
                size: 28,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
