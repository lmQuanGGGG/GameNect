// lib/user/screens/live_swipe_feed_screen.dart
// TikTok-style vertical swipe giữa các livestream đang live.
// Mỗi page quản lý Agora engine riêng → join/leave độc lập.

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../../../core/models/livestream_model.dart';
import '../../../core/providers/livestream_provider.dart';
import '../../../core/providers/profile_provider.dart';
import 'dart:developer' as developer;

const _kAccent = Color(0xFFFF6E40);
const _kLiveBadge = Color(0xFFFF3B30);

/// Màn hình vuốt lên/xuống giữa các live stream — TikTok style.
/// Gọi với danh sách streams và index ban đầu.
class LiveSwipeFeedScreen extends StatefulWidget {
  final List<LivestreamModel> streams;
  final int initialIndex;

  const LiveSwipeFeedScreen({
    super.key,
    required this.streams,
    this.initialIndex = 0,
  });

  @override
  State<LiveSwipeFeedScreen> createState() => _LiveSwipeFeedScreenState();
}

class _LiveSwipeFeedScreenState extends State<LiveSwipeFeedScreen> {
  late PageController _pageController;
  late List<LivestreamModel> _streams;
  int _currentIndex = 0;

  // Swipe control
  double _dragStart = 0;
  bool _isSwiping = false;

  @override
  void initState() {
    super.initState();
    _streams = List.from(widget.streams);
    _currentIndex = widget.initialIndex.clamp(0, _streams.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    // Giữ màn hình dọc khi trong feed này
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Load coins ngay khi mở swipe feed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        context.read<LivestreamProvider>().loadUserCoins(uid);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _goNext() {
    if (_currentIndex < _streams.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _pageController.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_streams.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Không có stream nào', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Main PageView (vertical swipe) ─────────────────────────────
          // Dùng NeverScrollableScrollPhysics + GestureDetector thủ công
          // để đảm bảo chính xác 1 trang/vuốt như TikTok
          GestureDetector(
            onVerticalDragStart: (details) {
              if (MediaQuery.of(context).orientation == Orientation.landscape) return;
              _dragStart = details.globalPosition.dy;
              _isSwiping = false;
            },
            onVerticalDragUpdate: (details) {
              // Chặn scroll tự do
            },
            onVerticalDragEnd: (details) {
              if (MediaQuery.of(context).orientation == Orientation.landscape) return;
              if (_isSwiping) return;
              final dy = details.globalPosition.dy - _dragStart;
              final velocity = details.velocity.pixelsPerSecond.dy;
              // Ngưỡng: kéo > 60px HOẶC velocity > 300 mới chuyển trang
              if (dy < -60 || velocity < -300) {
                _isSwiping = true;
                _goNext();
              } else if (dy > 60 || velocity > 300) {
                _isSwiping = true;
                _goPrev();
              }
            },
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _streams.length,
              onPageChanged: _onPageChanged,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final stream = _streams[index];
                final isActive = index == _currentIndex;
                final shouldLoad = isActive;

                return _LivePageItem(
                  key: ValueKey(stream.id),
                  stream: stream,
                  isActive: isActive,
                  shouldLoad: shouldLoad,
                  onSwipeUp: _currentIndex < _streams.length - 1 ? _goNext : null,
                  onSwipeDown: _currentIndex > 0 ? _goPrev : null,
                  onClose: () => Navigator.of(context).pop(),
                );
              },
            ),
          ),

          // ── Page indicator (right side dots like TikTok) ──────────────────
          if (_streams.length > 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _PageDots(
                  count: _streams.length,
                  current: _currentIndex,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Physics class giữ lại cho tương thích, không dùng nữa

// ── Dot indicator ──────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    const maxVisible = 5;
    final start = (current - maxVisible ~/ 2).clamp(0, max(0, count - maxVisible).toInt());
    final end = (start + maxVisible).clamp(0, count);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(end - start, (i) {
        final idx = start + i;
        final isActive = idx == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 3),
          width: isActive ? 6 : 4,
          height: isActive ? 18 : 8,
          decoration: BoxDecoration(
            color: isActive ? _kAccent : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Single Live Page ──────────────────────────────────────────────────────

class _LivePageItem extends StatefulWidget {
  final LivestreamModel stream;
  final bool isActive;
  final bool shouldLoad;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback onClose;

  const _LivePageItem({
    super.key,
    required this.stream,
    required this.isActive,
    required this.shouldLoad,
    this.onSwipeUp,
    this.onSwipeDown,
    required this.onClose,
  });

  @override
  State<_LivePageItem> createState() => _LivePageItemState();
}

class _LivePageItemState extends State<_LivePageItem>
    with AutomaticKeepAliveClientMixin {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _joined = false;
  bool _isLoading = true;
  bool _streamEnded = false;
  bool _isFullscreen = false;
  bool _isUIHidden = false;
  // Viewer-side: broadcaster đang share màn hình hay không
  bool _remoteIsScreenSharing = false;
  // Video landscape (ngang) → hiện nút fullscreen
  bool _isLandscapeVideo = false;

  StreamSubscription? _messageSub;
  StreamSubscription? _streamDocSub;
  List<Map<String, dynamic>> _messages = [];
  int _viewerCount = 0;

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Floating likes
  final List<_FloatLike> _likes = [];
  int _likeCounter = 0;

  // Gift anim
  String? _giftEmoji;
  String? _giftUser;
  Timer? _giftTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.shouldLoad) _initStream();
  }

  @override
  void didUpdateWidget(_LivePageItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      if (!_joined) _initStream();
    } else if (!widget.isActive && old.isActive) {
      _leaveStream();
      if (_isFullscreen) {
        setState(() {
          _isFullscreen = false;
          _isUIHidden = false;
        });
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    }
  }

  void _leaveStream() {
    if (!_joined) return;
    _decrementViewer();
    _engine?.leaveChannel();
    // Khởi tạo lại frame video để tránh bị đứng hình
    if (mounted) setState(() { _remoteUid = null; });
    _joined = false;
  }

  Future<void> _initStream() async {
    if (_joined) return;
    try {
      final envAppId = const String.fromEnvironment('AGORA_APP_ID', defaultValue: '');
      final appId = envAppId.isNotEmpty ? envAppId.trim() : (dotenv.env['AGORA_APP_ID'] ?? '').trim();
      if (appId.isEmpty) return;

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine!.enableVideo();

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (conn, uid, elapsed) {
          if (mounted) setState(() => _remoteUid = uid);
        },
        onUserOffline: (conn, uid, reason) {
          if (mounted) setState(() => _remoteUid = null);
        },
        onError: (code, msg) {
          developer.log('Agora error [$code]: $msg', name: 'LivePage');
        },
        onVideoSizeChanged: (connection, sourceType, uid, width, height, rotation) {
          // Phát hiện video ngang để hiện nút fullscreen.
          bool isLandscape = width > height;
          if (rotation == 90 || rotation == 270) isLandscape = !isLandscape;
          if (mounted && _isLandscapeVideo != isLandscape) {
            setState(() => _isLandscapeVideo = isLandscape);
          }
          // Không dùng sourceType để detect screen share — không đáng tin cậy trên viewer.
          // Dùng Firestore trong _listenStreamDoc() để biết broadcaster có đang share màn hình không.
        },
      ));

      await _engine!.joinChannel(
        token: '',
        channelId: widget.stream.id,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleAudience,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      _joined = true;

      // Listen Firestore
      _listenMessages();
      _listenStreamDoc();
      _incrementViewer();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      developer.log('_initStream error: $e', name: 'LivePage');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenMessages() {
    _messageSub = FirebaseFirestore.instance
        .collection('livestreams')
        .doc(widget.stream.id)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(60)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final msgs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      setState(() => _messages = msgs);
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _listenStreamDoc() {
    _streamDocSub = FirebaseFirestore.instance
        .collection('livestreams')
        .doc(widget.stream.id)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      final viewerCount = (data['viewerCount'] ?? 0).toInt();
      final isScreenSharing = data['isScreenSharing'] as bool? ?? false;
      if (_streamEnded != (data['status'] == 'ended') ||
          _viewerCount != viewerCount ||
          _remoteIsScreenSharing != isScreenSharing) {
        setState(() {
          _viewerCount = viewerCount;
          _remoteIsScreenSharing = isScreenSharing;
          if (data['status'] == 'ended') _streamEnded = true;
        });
      }
    });
  }

  void _incrementViewer() {
    FirebaseFirestore.instance
        .collection('livestreams')
        .doc(widget.stream.id)
        .update({'viewerCount': FieldValue.increment(1)}).catchError((_) {});
  }

  void _decrementViewer() {
    FirebaseFirestore.instance
        .collection('livestreams')
        .doc(widget.stream.id)
        .update({'viewerCount': FieldValue.increment(-1)}).catchError((_) {});
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _messageSub?.cancel();
    _streamDocSub?.cancel();
    _giftTimer?.cancel();
    if (_joined) {
      _decrementViewer();
      _engine?.leaveChannel();
      _engine?.release();
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft,
        ]);
        _isUIHidden = true;
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        _isUIHidden = false;
      }
    });
  }

  void _addLike() {
    final rng = Random();
    final colors = [Colors.pinkAccent, Colors.redAccent, Colors.orangeAccent, Colors.purpleAccent];
    final icons = [Icons.favorite, Icons.star, Icons.thumb_up_rounded, Icons.emoji_emotions_rounded];
    setState(() {
      _likeCounter++;
      _likes.add(_FloatLike(
        id: _likeCounter,
        x: rng.nextDouble() * 80 + 20,
        color: colors[rng.nextInt(colors.length)],
        icon: icons[rng.nextInt(icons.length)],
      ));
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final profile = context.read<ProfileProvider>().userData;
    await FirebaseFirestore.instance
        .collection('livestreams')
        .doc(widget.stream.id)
        .collection('messages')
        .add({
      'userId': user.uid,
      'username': profile?.username ?? 'User',
      'avatarUrl': profile?.avatarUrl ?? '',
      'text': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 300) {
            setState(() { _isUIHidden = true; });
          } else if (details.primaryVelocity! < -300) {
            setState(() { _isUIHidden = false; });
          }
        }
      },
      onTap: _addLike,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video background ─────────────────────────────────────────────
            _buildVideo(),

            // ── Stream ended overlay ─────────────────────────────────────────
            if (_streamEnded) _buildEndedOverlay(),

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
                      // ── Top bar ──────────────────────────────────────────────────────
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: _buildTopBar(context),
                      ),

                      // ── Swipe hint arrows ─────────────────────────────────────────────
                      if (widget.onSwipeUp != null)
                        Positioned(
                          bottom: 220, right: 16,
                          child: _SwipeHint(direction: AxisDirection.up, onTap: widget.onSwipeUp!),
                        ),
                      if (widget.onSwipeDown != null)
                        Positioned(
                          bottom: 280, right: 16,
                          child: _SwipeHint(direction: AxisDirection.down, onTap: widget.onSwipeDown!),
                        ),

                      // ── Floating likes ────────────────────────────────────────────────
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Stack(
                            children: _likes.map<Widget>((like) => _FloatingHeartWidget(
                              key: ValueKey(like.id),
                              like: like,
                              screenSize: size,
                              onComplete: () {
                                if (mounted) setState(() => _likes.removeWhere((l) => l.id == like.id));
                              },
                            )).toList(),
                          ),
                        ),
                      ),

                      // ── Gift anim ─────────────────────────────────────────────────────
                      if (_giftEmoji != null)
                        Positioned(
                          top: size.height * 0.25,
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
                                    Text(_giftEmoji!, style: const TextStyle(fontSize: 32)),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_giftUser ?? '', style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const Text('đã tặng quà!', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ── Fullscreen toggle button — chỉ hiện khi video ngang ────────────
                      if (_isLandscapeVideo)
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

                      // ── Bottom overlay (chat + input) ─────────────────────────────────
                      Positioned(
                        left: 0, right: 0,
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                        child: SafeArea(
                          top: false,
                          child: _buildBottom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Loading overlay ───────────────────────────────────────────────
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: _kAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_engine == null || _isLoading) {
      return Container(
        color: const Color(0xFF0D0D10),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.stream.mentorAvatarUrl.isNotEmpty)
                CircleAvatar(
                  radius: 48,
                  backgroundImage: NetworkImage(widget.stream.mentorAvatarUrl),
                )
              else
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white12,
                  child: Icon(Icons.person, size: 48, color: Colors.white38),
                ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: _kAccent, strokeWidth: 2),
            ],
          ),
        ),
      );
    }

    if (_remoteUid == null) {
      return Container(
        color: const Color(0xFF0D0D10),
        child: const Center(
          child: CircularProgressIndicator(color: _kAccent),
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(
          uid: _remoteUid!,
          renderMode: RenderModeType.renderModeFit,
          // Chỉ lật (mirror) khi broadcaster dùng camera, không lật khi share màn hình.
          mirrorMode: _remoteIsScreenSharing
              ? VideoMirrorModeType.videoMirrorModeDisabled
              : VideoMirrorModeType.videoMirrorModeEnabled,
        ),
        connection: RtcConnection(channelId: widget.stream.id),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Avatar + name pill
            Container(
              padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.stream.mentorAvatarUrl.isNotEmpty)
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: NetworkImage(widget.stream.mentorAvatarUrl),
                    )
                  else
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white12,
                      child: Icon(Icons.person, size: 14, color: Colors.white70),
                    ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Text(
                      widget.stream.mentorUsername,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Game tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
              ),
              child: Text(widget.stream.game, style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            // LIVE + viewers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
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
            // Close button
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottom(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      children: [
        // Chat list
        SizedBox(
          height: keyboardOpen ? 100 : 180,
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final msg = _messages[i];
              final isGift = msg['type'] == 'gift';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if ((msg['avatarUrl'] as String? ?? '').isNotEmpty)
                      Container(
                        width: 18, height: 18,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(image: NetworkImage(msg['avatarUrl']), fit: BoxFit.cover),
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
                              text: TextSpan(children: [
                                TextSpan(
                                  text: '${msg['username'] ?? 'User'} ',
                                  style: TextStyle(
                                    color: isGift ? _kAccent : Colors.white70,
                                    fontWeight: FontWeight.bold, fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: isGift ? 'tặng ${msg['giftType']}!' : msg['text'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ]),
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

        // Input row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
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
              _ActionBtn(icon: Icons.send_rounded, color: _kAccent, onTap: _sendMessage),
              const SizedBox(width: 8),
              _ActionBtn(emoji: '🎁', color: Colors.amber.shade700, onTap: _showGiftSheet),
              const SizedBox(width: 8),
              _ActionBtn(icon: Icons.favorite, color: Colors.pink, onTap: _addLike),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEndedOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_rounded, color: Colors.white38, size: 64),
            const SizedBox(height: 12),
            const Text('Stream đã kết thúc', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.onSwipeUp != null)
              TextButton.icon(
                onPressed: widget.onSwipeUp,
                icon: const Icon(Icons.expand_less, color: _kAccent),
                label: const Text('Xem stream khác ↑', style: TextStyle(color: _kAccent)),
              ),
          ],
        ),
      ),
    );
  }

  void _showGiftSheet() {
    // Gifts định nghĩa
    const gifts = [
      {'type': 'heart', 'emoji': '❤️', 'name': 'Tim', 'coins': 1},
      {'type': 'star', 'emoji': '⭐', 'name': 'Sao', 'coins': 5},
      {'type': 'diamond', 'emoji': '💎', 'name': 'Kim cương', 'coins': 20},
      {'type': 'crown', 'emoji': '👑', 'name': 'Vương miện', 'coins': 50},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tặng quà', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: gifts.map((g) => GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  final provider = context.read<LivestreamProvider>();
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  final profileProvider = context.read<ProfileProvider>();
                  final profile = profileProvider.userData;
                  final mentorId = widget.stream.mentorId;
                  
                  if (provider.myCoins < (g['coins'] as int)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Không đủ coin! Hãy nạp thêm.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  final ok = await provider.sendGift(
                    streamId: widget.stream.id,
                    fromUserId: user.uid,
                    toMentorId: mentorId,
                    fromUsername: profile?.username ?? 'User',
                    fromAvatarUrl: profile?.avatarUrl ?? '',
                    giftType: g['type'] as String,
                    coinValue: g['coins'] as int,
                  );

                  if (!mounted) return;
                  if (ok) {
                    profileProvider.deductCoins(g['coins'] as int);
                    setState(() {
                      _giftEmoji = g['emoji'] as String;
                      _giftUser = profile?.username ?? 'User';
                    });
                    _giftTimer?.cancel();
                    _giftTimer = Timer(const Duration(seconds: 3), () {
                      if (mounted) setState(() { _giftEmoji = null; _giftUser = null; });
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Không đủ coin!'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(g['emoji'] as String, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(g['name'] as String, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      Text('${g['coins']} coin', style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Swipe hint button ──────────────────────────────────────────────────────

class _SwipeHint extends StatefulWidget {
  final AxisDirection direction;
  final VoidCallback onTap;
  const _SwipeHint({required this.direction, required this.onTap});

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUp = widget.direction == AxisDirection.up;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, isUp ? -_anim.value : _anim.value),
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(
            isUp ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: Colors.white70, size: 22,
          ),
        ),
      ),
    );
  }
}

// ── Small action button ────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({this.icon, this.emoji, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: icon != null
            ? Icon(icon, color: Colors.white, size: 18)
            : Center(child: Text(emoji!, style: const TextStyle(fontSize: 18))),
      ),
    );
  }
}

// ── Floating like models + widget ─────────────────────────────────────────

class _FloatLike {
  final int id;
  final double x;
  final Color color;
  final IconData icon;
  _FloatLike({required this.id, required this.x, required this.color, required this.icon});
}

class _FloatingHeartWidget extends StatefulWidget {
  final _FloatLike like;
  final Size screenSize;
  final VoidCallback onComplete;

  const _FloatingHeartWidget({super.key, required this.like, required this.screenSize, required this.onComplete});

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _yAnim, _xAnim, _scaleAnim, _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 1800), vsync: this);
    _yAnim = Tween<double>(begin: 0, end: 320).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _xAnim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1.2), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 70),
    ]).animate(_ctrl);
    _opacityAnim = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);
    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final wiggle = sin(_xAnim.value * 3 * pi) * 16;
        final xPos = widget.screenSize.width - widget.like.x + wiggle - 40;
        final yPos = widget.screenSize.height - _yAnim.value - 120;
        return Positioned(
          left: xPos, top: yPos,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Icon(widget.like.icon, color: widget.like.color, size: 28,
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 5)]),
            ),
          ),
        );
      },
    );
  }
}
