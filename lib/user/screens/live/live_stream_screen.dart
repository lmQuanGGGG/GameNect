// lib/user/screens/live_stream_screen.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:replay_kit_launcher/replay_kit_launcher.dart';
import '../../../core/providers/livestream_provider.dart';
import '../../../core/providers/profile_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const _kAccent = Color(0xFFFF6E40);
const _kLiveBadge = Color(0xFFFF3B30);

// Gift definitions
const _kGifts = [
  {'type': 'heart', 'name': 'Tim', 'coins': 1},
  {'type': 'star', 'name': 'Sao', 'coins': 5},
  {'type': 'diamond', 'name': 'Kim cương', 'coins': 20},
  {'type': 'crown', 'name': 'Vương miện', 'coins': 50},
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
  bool _isUIHidden = false; // State to track if UI is hidden (TikTok style clear display)
  bool _isFullscreen = false;
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
  StreamSubscription? _giftSub;

  @override
  void initState() {
    super.initState();
    try {
      WakelockPlus.enable().catchError((e) {
        debugPrint('WakelockPlus enable async error: $e');
      });
    } catch (e) {
      debugPrint('WakelockPlus enable error: $e');
    }
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

      // Listen gifts for animation — hiện cho TẤT CẢ (kể cả mentor)
      // KHÔNG dùng timestamp filter vì server timestamp != client Timestamp.now()
      // Thay vào đó: bỏ qua snapshot đầu tiên (chứa docs cũ), chỉ trigger từ snapshot thứ 2 trở đi
      bool _giftSubReady = false;
      _giftSub = FirebaseFirestore.instance
          .collection('livestreams')
          .doc(widget.streamId)
          .collection('messages')
          .where('type', isEqualTo: 'gift')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        if (!_giftSubReady) {
          // Bỏ qua snapshot đầu tiên (load lại toàn bộ docs cũ)
          _giftSubReady = true;
          return;
        }
        for (var change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data()!;
            _triggerGiftAnimation(data['giftType'] ?? 'heart', data['username'] ?? 'User');
          }
        }
      });

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
    try {
      WakelockPlus.disable().catchError((e) {
        debugPrint('WakelockPlus disable async error: $e');
      });
    } catch (e) {
      debugPrint('WakelockPlus disable error: $e');
    }
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _streamInfoSub?.cancel();
    _giftSub?.cancel();
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

  void _triggerGiftAnimation(String type, String username) {
    setState(() {
      _giftAnimEmoji = type;
      _giftAnimUsername = username;
    });
    _giftTimer?.cancel();
    _giftTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() { _giftAnimEmoji = null; _giftAnimUsername = null; });
    });
  }

  Widget _getGiftIcon(String type, double size) {
    switch (type) {
      case 'heart':
        return ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [Colors.pinkAccent, Colors.red]).createShader(b),
          child: Icon(Icons.favorite, size: size, color: Colors.white),
        );
      case 'star':
        return ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [Colors.amberAccent, Colors.orange]).createShader(b),
          child: Icon(Icons.star_rounded, size: size, color: Colors.white),
        );
      case 'diamond':
        return ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [Colors.cyanAccent, Colors.blueAccent]).createShader(b),
          child: Icon(Icons.diamond, size: size, color: Colors.white),
        );
      case 'crown':
        return ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [Colors.yellowAccent, Colors.orangeAccent]).createShader(b),
          child: Icon(Icons.workspace_premium, size: size, color: Colors.white),
        );
      default:
        return ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [Colors.purpleAccent, Colors.deepPurple]).createShader(b),
          child: Icon(Icons.card_giftcard, size: size, color: Colors.white),
        );
    }
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.black, width: 4),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TẶNG QUÀ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 2.0)),
                  Consumer<LivestreamProvider>(
                    builder: (_, p, _w) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                      ),
                      child: Text('💰 ${p.myCoins} COIN', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
                children: _kGifts.map((gift) => _buildGiftItem(gift, ctx)).toList(),
              ),
              const SizedBox(height: 12),
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

        final provider = context.read<LivestreamProvider>();
        if (provider.myCoins < (gift['coins'] as int)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('KHÔNG ĐỦ COIN! HÃY NẠP THÊM.', style: TextStyle(fontWeight: FontWeight.w900)),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
          );
          return;
        }

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
            SnackBar(
              content: const Text('KHÔNG ĐỦ COIN!', style: TextStyle(fontWeight: FontWeight.w900)),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
          );
        } else {
          profileProvider.deductCoins(gift['coins'] as int);
          _triggerGiftAnimation(gift['type'] as String, username);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFD54F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _getGiftIcon(gift['type'] as String, 40),
            const SizedBox(height: 8),
            Text(gift['name'] as String, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
              child: Text('${gift['coins']} COIN', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft,
        ]);
        // Also hide UI when entering fullscreen to be like TikTok
        _isUIHidden = true;
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        _isUIHidden = false;
      }
    });
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
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Swipe right to hide UI, Swipe left to show UI
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! > 300) {
                setState(() { _isUIHidden = true; });
              } else if (details.primaryVelocity! < -300) {
                setState(() { _isUIHidden = false; });
              }
            }
          },
          child: Stack(
            children: [
              // ── Video background ──────────────────────────────────────────────
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: GestureDetector(
                    onTap: widget.isMentor ? null : _addLike,
                    child: _buildVideoView(),
                  ),
                ),
              ),

              // ── UI Overlays (Animated Slide/Opacity) ─────────────────────────
              Positioned.fill(
                child: AnimatedSlide(
                  offset: _isUIHidden ? const Offset(1.0, 0) : Offset.zero,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    opacity: _isUIHidden ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Stack(
                      children: [

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
                          // Neo-Brutalism mentor pill
                          Container(
                            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: _kAccent,
                                    border: Border.all(color: Colors.black, width: 2),
                                    image: _mentorAvatarUrl != null
                                        ? DecorationImage(image: NetworkImage(_mentorAvatarUrl!), fit: BoxFit.cover)
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: _mentorAvatarUrl == null
                                      ? const Icon(Icons.person, size: 16, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 100),
                                  child: Text(
                                    _mentorUsername ?? 'Mentor',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // LIVE badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kLiveBadge,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sensors_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                                const SizedBox(width: 8),
                                const Icon(Icons.remove_red_eye, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Close / End button
                          GestureDetector(
                            onTap: widget.isMentor ? _endStream : () => Navigator.pop(context),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: widget.isMentor ? Colors.red : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                              ),
                              child: Icon(
                                widget.isMentor ? Icons.stop : Icons.close,
                                color: Colors.white,
                                size: 18,
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

          // ── Fullscreen toggle button ──────────────────────────────────────
          Positioned(
            right: 12,
            bottom: (MediaQuery.of(context).size.width <= 300 ? 80 : (MediaQuery.of(context).viewInsets.bottom > 0 ? 120 : 200)) + 70,
            child: GestureDetector(
              onTap: _toggleFullscreen,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Icon(
                  _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // ── Bottom overlay ─────────────────────────────────────────────────
          // Always show the bottom overlay so chat messages are visible even in mini mode
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
                final isMini = MediaQuery.of(context).size.width <= 300;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chat messages — Neo-Brutalism style
                    SizedBox(
                      height: isMini ? 80 : (keyboardIsOpen ? 120 : 200),
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: provider.messages.length,
                        itemBuilder: (context, i) {
                          final msg = provider.messages[i];
                          final isGift = msg['type'] == 'gift';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if ((msg['avatarUrl'] as String? ?? '').isNotEmpty)
                                  Container(
                                    width: isMini ? 16 : 20, height: isMini ? 16 : 20,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(image: NetworkImage(msg['avatarUrl']), fit: BoxFit.cover),
                                    ),
                                  ),
                                Flexible(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: isMini ? 3 : 6),
                                    decoration: BoxDecoration(
                                      color: isGift ? const Color(0xFFFFD54F) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.black, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                                    ),
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${msg['username'] ?? 'User'} ',
                                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                                          ),
                                          TextSpan(
                                            text: isGift ? 'TẶNG ${msg['giftType']}!' : msg['text'] ?? '',
                                            style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: isGift ? FontWeight.w900 : FontWeight.w600),
                                          ),
                                        ],
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

                    // Chat input (Viewer only) or Stats (Mentor) - Hide when in Mini Mode (PiP)
                    if (!isMini)
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
          )
                      ],
                    ),
                  ),
                ),
              ),

              // ── Gift animation overlay — NGOÀI AnimatedSlide, luôn hiện ──
              if (_giftAnimEmoji != null)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.2,
                  left: 0, right: 0,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_giftAnimEmoji! + (_giftAnimUsername ?? '')),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) => Opacity(
                        opacity: v.clamp(0.0, 1.0),
                        child: Transform.scale(scale: 0.5 + 0.5 * v, child: child),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black, width: 4),
                            boxShadow: const [
                              BoxShadow(color: Colors.black, offset: Offset(8, 8)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _getGiftIcon(_giftAnimEmoji!, 100),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_giftAnimUsername ?? ''} TẶNG QUÀ!',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
                                ),
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
            return LayoutBuilder(
              builder: (context, constraints) {
                final isMini = constraints.maxWidth < 250 || constraints.maxHeight < 300;

                if (isMini) {
                  return Container(
                    color: const Color(0xFF101012),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kAccent.withValues(alpha: 0.15),
                            ),
                            child: const Icon(
                              Icons.screen_share_rounded,
                              color: _kAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Đang Chia Sẻ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

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
              },
            );
          }

          // Local camera preview
          return AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: provider.engine!,
              canvas: VideoCanvas(
                uid: 0,
                sourceType: provider.isScreenSharing 
                    ? VideoSourceType.videoSourceScreen 
                    : VideoSourceType.videoSourceCamera,
                mirrorMode: provider.isScreenSharing 
                    ? VideoMirrorModeType.videoMirrorModeDisabled 
                    : VideoMirrorModeType.videoMirrorModeEnabled,
              ),
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
            key: ValueKey('remote_${provider.remoteUid}_${provider.remoteIsScreenSharing}'),
            controller: VideoViewController.remote(
              rtcEngine: provider.engine!,
              canvas: VideoCanvas(
                uid: provider.remoteUid!,
                renderMode: RenderModeType.renderModeFit,
                // Chỉ lật (mirror) khi broadcaster đang dùng camera, không lật khi share màn hình.
                mirrorMode: provider.remoteIsScreenSharing
                    ? VideoMirrorModeType.videoMirrorModeDisabled
                    : VideoMirrorModeType.videoMirrorModeEnabled,
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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
            ),
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'BÌNH LUẬN...',
                hintStyle: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _LiveNeoBtn(icon: Icons.send_rounded, color: _kAccent, onTap: _sendMessage),
        const SizedBox(width: 8),
        _LiveNeoBtn(emoji: '🎁', color: Colors.amber.shade700, onTap: _showGiftSheet),
        const SizedBox(width: 8),
        _LiveNeoBtn(icon: Icons.favorite, color: Colors.pink, onTap: _addLike),
      ],
    );
  }

  Widget _buildMentorStats() {
    return Consumer<LivestreamProvider>(
      builder: (context, provider, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Stat chips — Neo
            _buildStatBadge('👁️', '$_viewerCount', 'VIEW'),
            _buildStatBadge('💬', '${provider.messages.where((m) => m['type'] == 'text').length}', 'CHAT'),
            _buildStatBadge('🎁', '${provider.messages.where((m) => m['type'] == 'gift').length}', 'GIFT'),
            // Divider
            Container(width: 2, height: 36, color: Colors.black),
            // Đổi Cam button
            GestureDetector(
              onTap: () => provider.engine?.switchCamera(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('ĐỔI CAM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Chia sẻ MH button
            GestureDetector(
              onTap: () async {
                if (provider.isScreenSharing) {
                  await provider.stopScreenShare();
                } else {
                  if (Theme.of(context).platform == TargetPlatform.iOS) {
                    try {
                      await ReplayKitLauncher.launchReplayKitBroadcast('GamenectScreenShare');
                    } catch (e) {
                      debugPrint('ReplayKit error: $e');
                    }
                  }
                  await provider.startScreenShare();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: provider.isScreenSharing ? Colors.red : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                      color: Colors.white, size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.isScreenSharing ? 'DỮNG' : 'SHARE',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD54F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
          Text(label, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

}

// ── Neo-Brutalism action button (reusable in this file) ─────────────────────
class _LiveNeoBtn extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final Color color;
  final VoidCallback onTap;

  const _LiveNeoBtn({this.icon, this.emoji, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
        ),
        child: icon != null
            ? Icon(icon, color: Colors.white, size: 18)
            : Center(child: Text(emoji!, style: const TextStyle(fontSize: 18))),
      ),
    );
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
