// lib/user/screens/mentor_profile_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/mentor_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/mentor_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/providers/livestream_provider.dart';
import 'mentor_media_screen.dart';
import 'mentor_edit_profile_screen.dart';
import '../shared/peer_profile_screen.dart';
import '../live/live_swipe_feed_screen.dart';
import '../../../core/widgets/network_image.dart';

const _kNeoOrange = Color(0xFFFF6E40);
const _kNeoRed = Color(0xFFFF3B30);
const _kDarkBg = Color(0xFF121214);
const _kLightBg = Color(0xFFF4F4F0);
const _kDarkCard = Color(0xFF2A2A32);
const _kLightCard = Colors.white;

class MentorProfileScreen extends StatefulWidget {
  final String mentorId;
  const MentorProfileScreen({super.key, required this.mentorId});

  @override
  State<MentorProfileScreen> createState() => _MentorProfileScreenState();
}

class _MentorProfileScreenState extends State<MentorProfileScreen> {
  MentorModel? _mentor;
  Map<String, dynamic>? _mentorUser;
  bool _isFollowing = false;
  bool _hasMatchRequest = false;
  String? _matchRequestId;
  bool _isLoading = true;
  String? _liveStreamId;
  StreamSubscription<MentorModel?>? _mentorSub;
  int _activeTab = 0;
  late final Stream<QuerySnapshot> _ratingsStream;
  late final Stream<QuerySnapshot> _mediaStream;

  @override
  void initState() {
    super.initState();
    _ratingsStream = FirebaseFirestore.instance
        .collection('mentor_ratings')
        .where('toMentorId', isEqualTo: widget.mentorId)
        .snapshots();
    _mediaStream = FirestoreService().getMentorMedia(widget.mentorId);
    _loadData();
    _subscribeMentorStream();
  }

  @override
  void dispose() {
    _mentorSub?.cancel();
    super.dispose();
  }

  void _subscribeMentorStream() {
    _mentorSub = FirestoreService()
        .getMentorProfileStream(widget.mentorId)
        .listen((mentor) {
          if (mounted && mentor != null) {
            setState(() {
              _mentor = mentor;
            });
          }
        });
  }

  Future<void> _loadData() async {
    final mentorProvider = context.read<MentorProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      _mentor = await FirebaseFirestore.instance
          .collection('mentor_profiles')
          .doc(widget.mentorId)
          .get()
          .then(
            (doc) =>
                doc.exists ? MentorModel.fromMap(doc.data()!, doc.id) : null,
          );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.mentorId)
          .get();
      _mentorUser = userDoc.data();

      if (currentUserId.isNotEmpty) {
        _isFollowing = await mentorProvider.checkIsFollowing(
          widget.mentorId,
          currentUserId,
        );
        _matchRequestId = await FirebaseFirestore.instance
            .collection('mentor_match_requests')
            .where('fromUserId', isEqualTo: currentUserId)
            .where('toMentorId', isEqualTo: widget.mentorId)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get()
            .then((s) => s.docs.isEmpty ? null : s.docs.first.id);
        _hasMatchRequest = _matchRequestId != null;
      }

      final liveSnap = await FirebaseFirestore.instance
          .collection('livestreams')
          .where('mentorId', isEqualTo: widget.mentorId)
          .where('status', isEqualTo: 'live')
          .limit(1)
          .get();

      if (liveSnap.docs.isNotEmpty) {
        _liveStreamId = liveSnap.docs.first.id;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (widget.mentorId == currentUserId) return;

    final mentorProvider = context.read<MentorProvider>();
    setState(() => _isFollowing = !_isFollowing);

    if (_isFollowing) {
      await mentorProvider.followMentor(widget.mentorId, currentUserId);
    } else {
      await mentorProvider.unfollowMentor(widget.mentorId, currentUserId);
    }
  }

  void _showFollowerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MentorFollowerSheet(mentorId: widget.mentorId),
    );
  }

  void _showMatchRequestSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null || currentUserId.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (widget.mentorId == currentUserId) return;

    final msgCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? _kDarkCard : _kLightCard,
      shape: Border(
        top: BorderSide(color: isDark ? Colors.white : Colors.black, width: 3),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GỬI MATCH REQUEST',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Viết lời nhắn cho Mentor (tùy chọn)',
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.6,
                ),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark ? _kDarkBg : _kLightBg,
                border: Border.all(
                  color: isDark ? Colors.white : Colors.black,
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(color: _kNeoOrange, offset: Offset(4, 4)),
                ],
              ),
              child: TextField(
                controller: msgCtrl,
                maxLines: 3,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Mình muốn học Valorant...',
                  hintStyle: TextStyle(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.4,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                if (currentUserId == null) return;

                final ok = await context
                    .read<MentorProvider>()
                    .sendMatchRequest(
                      currentUserId,
                      widget.mentorId,
                      msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
                    );

                if (mounted) {
                  setState(() => _hasMatchRequest = ok);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Đã gửi Match Request!' : 'Gửi thất bại',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      backgroundColor: ok ? Colors.green : _kNeoRed,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _kNeoOrange,
                  border: Border.all(
                    color: isDark ? Colors.white : Colors.black,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.white : Colors.black,
                      offset: const Offset(4, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'GỬI YÊU CẦU',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double selectedRating = 5.0;
    final commentCtrl = TextEditingController();
    bool isSubmitting = false;
    final messenger = ScaffoldMessenger.of(context);
    final mentorProvider = context.read<MentorProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? _kDarkCard : _kLightCard,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isDark ? Colors.white : Colors.black,
              width: 3,
            ),
          ),
          title: Text(
            'ĐÁNH GIÁ MENTOR',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
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
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.7,
                  ),
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
                            ? CupertinoIcons.star_fill
                            : CupertinoIcons.star,
                        color: selectedRating >= starVal
                            ? _kNeoRed
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
                  color: isDark ? _kDarkBg : _kLightBg,
                  border: Border.all(
                    color: isDark ? Colors.white : Colors.black,
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(color: _kNeoOrange, offset: Offset(4, 4)),
                  ],
                ),
                child: TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nhập ý kiến...',
                    hintStyle: TextStyle(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.4,
                      ),
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
                        color: isDark ? _kDarkBg : _kLightBg,
                        border: Border.all(
                          color: isDark ? Colors.white : Colors.black,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.white : Colors.black,
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'HỦY',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
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
                              toMentorId: widget.mentorId,
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
                                  backgroundColor: ok ? Colors.green : _kNeoRed,
                                  shape: const RoundedRectangleBorder(
                                    side: BorderSide(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                              if (ok) _loadData();
                            }
                          },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: _kNeoRed,
                        border: Border.all(
                          color: isDark ? Colors.white : Colors.black,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.white : Colors.black,
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: isSubmitting
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            )
                          : const Text(
                              'GỬI',
                              style: TextStyle(
                                color: Colors.white,
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

  // --- NEO-BRUTALISM UI HELPERS ---

  Widget _buildNeoContainer({
    required Widget child,
    Color? bgColor,
    Color? borderColor,
    Color? shadowColor,
    double borderRadius = 16,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: bgColor ?? (isDark ? _kDarkCard : _kLightCard),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? (isDark ? Colors.white : Colors.black),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? (isDark ? Colors.white : Colors.black),
            offset: const Offset(4, 4),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _kDarkBg : _kLightBg;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: _buildNeoContainer(
              bgColor: _kNeoOrange,
              borderColor: isDark ? Colors.white : Colors.black,
              shadowColor: isDark ? Colors.white : Colors.black,
              borderRadius: 12,
              padding: const EdgeInsets.all(10),
              child: const Icon(
                CupertinoIcons.back,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
          Text(
            'PROFILE',
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildAvatarCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 48),
          child: _buildNeoContainer(
            shadowColor: _kNeoOrange,
            borderRadius: 24,
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _kNeoOrange,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                        ],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '✦ MENTOR',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  (_mentorUser?['username'] ?? 'Mentor').toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                if (_liveStreamId != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      final allStreams = context
                          .read<LivestreamProvider>()
                          .liveStreams;
                      final index = allStreams.indexWhere(
                        (s) => s.id == _liveStreamId,
                      );
                      if (index >= 0) {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => LiveSwipeFeedScreen(
                              streams: allStreams.toList(),
                              initialIndex: index,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _kNeoRed,
                        border: Border.all(
                          color: isDark ? Colors.white : Colors.black,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.white : Colors.black,
                            offset: const Offset(3, 3),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '🔴 ĐANG LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 20,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? _kDarkCard : _kLightCard,
              border: Border.all(
                color: isDark ? Colors.white : Colors.black,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.white : Colors.black,
                  offset: const Offset(4, 4),
                ),
              ],
              image: (_mentorUser?['avatarUrl'] as String?)?.isNotEmpty == true
                  ? DecorationImage(
                      image: NetworkImage(_mentorUser!['avatarUrl']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (_mentorUser?['avatarUrl'] as String?)?.isNotEmpty != true
                ? Icon(
                    CupertinoIcons.person_solid,
                    color: isDark ? Colors.white54 : Colors.black54,
                    size: 48,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isSelf) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: isSelf ? null : _showRatingDialog,
            behavior: HitTestBehavior.opaque,
            child: _buildNeoContainer(
              bgColor: _kNeoOrange,
              borderColor: isDark ? Colors.white : Colors.black,
              shadowColor: isDark ? Colors.white : Colors.black,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _mentor!.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.star_fill,
                        color: Colors.black,
                        size: 14,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RATING',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: isSelf ? () => _showFollowerSheet() : null,
            behavior: HitTestBehavior.opaque,
            child: _buildNeoContainer(
              shadowColor: _kNeoOrange,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    '${_mentor!.followerCount}',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSelf ? 'FOLLOWERS ›' : 'FOLLOWERS',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildNeoContainer(
            shadowColor: _kNeoOrange,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  '${_mentor!.totalStreams}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'STREAMS',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final inactiveText = isDark ? Colors.white : Colors.black;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _activeTab = 0),
            child: _buildNeoContainer(
              bgColor: _activeTab == 0 ? _kNeoOrange : cardColor,
              shadowColor: _activeTab == 0 ? shadowColor : _kNeoOrange,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'THÔNG TIN',
                  style: TextStyle(
                    color: _activeTab == 0 ? Colors.black : inactiveText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _activeTab = 1),
            child: _buildNeoContainer(
              bgColor: _activeTab == 1 ? _kNeoOrange : cardColor,
              shadowColor: _activeTab == 1 ? shadowColor : _kNeoOrange,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'MEDIA',
                  style: TextStyle(
                    color: _activeTab == 1 ? Colors.black : inactiveText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = widget.mentorId == currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _kDarkBg : _kLightBg;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kNeoOrange))
          : _mentor == null
          ? Center(
              child: Text(
                'Không tìm thấy Mentor',
                style: TextStyle(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            )
          : SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Stack(
                    children: [
                      // Scrollable content
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 80, 16, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildAvatarCard(),
                            const SizedBox(height: 24),
                            _buildStatsGrid(isSelf),
                            const SizedBox(height: 24),
                            _buildTabs(),
                            const SizedBox(height: 24),
                            _buildTabContent(),
                          ],
                        ),
                      ),

                      // Custom Neo Header
                      Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),

                      // Bottom Action Bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildBottomBar(isSelf),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTabContent() {
    if (_activeTab == 0) return _buildInfoTab();
    if (_activeTab == 1) return _buildAlbumTab();
    return const SizedBox.shrink();
  }

  Widget _buildInfoTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final isSelf = widget.mentorId == FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chuyên môn
        if (_mentor!.games.isNotEmpty) ...[
          _buildNeoContainer(
            bgColor: isDark ? _kDarkCard : _kLightCard,
            shadowColor: _kNeoOrange,
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHUYÊN MÔN',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(top: 4, bottom: 16),
                  color: _kNeoOrange,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _mentor!.games.map((g) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _kNeoOrange,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                        ],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        g.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Giới thiệu
        if (_mentor!.bio.isNotEmpty) ...[
          _buildNeoContainer(
            shadowColor: _kNeoOrange,
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GIỚI THIỆU',
                  style: TextStyle(
                    color: _kNeoOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(top: 4, bottom: 16),
                  color: textColor,
                ),
                Text(
                  _mentor!.bio,
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Thành tích
        if (_mentor!.achievements.isNotEmpty) ...[
          _buildNeoContainer(
            shadowColor: _kNeoOrange,
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THÀNH TÍCH',
                  style: TextStyle(
                    color: _kNeoOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(top: 4, bottom: 16),
                  color: textColor,
                ),
                ..._mentor!.achievements
                    .split(RegExp(r'[\n•]'))
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty)
                    .map((line) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '✦',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                line,
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.9),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Đánh giá
        _buildNeoContainer(
          shadowColor: _kNeoOrange,
          borderRadius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ĐÁNH GIÁ',
                        style: TextStyle(
                          color: _kNeoOrange,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),
                      Container(
                        height: 4,
                        width: 40,
                        margin: const EdgeInsets.only(top: 4, bottom: 16),
                        color: textColor,
                      ),
                    ],
                  ),
                  if (!isSelf)
                    GestureDetector(
                      onTap: _showRatingDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _kNeoOrange,
                          border: Border.all(
                            color: isDark ? Colors.white : Colors.black,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.white : Colors.black,
                              offset: const Offset(2, 2),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '+ VIẾT ĐÁNH GIÁ',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _ratingsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _kNeoOrange,
                        strokeWidth: 3,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.black12,
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.2),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'CHƯA CÓ LƯỢT ĐÁNH GIÁ NÀO.',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }

                  final ratingDocs = [...snapshot.data!.docs]
                    ..sort((a, b) {
                      final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
                      final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
                      if (aTs == null && bTs == null) return 0;
                      if (aTs == null) return 1;
                      if (bTs == null) return -1;
                      return bTs.compareTo(aTs);
                    });

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ratingDocs.length,
                    itemBuilder: (context, index) {
                      final data =
                          ratingDocs[index].data() as Map<String, dynamic>;
                      return _ReviewItem(
                        fromUserId: data['fromUserId'] ?? '',
                        rating: (data['rating'] ?? 0.0).toDouble(),
                        comment: data['comment'] ?? '',
                        createdAt: data['createdAt'] as Timestamp?,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isSelf = widget.mentorId == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ALBUM MEDIA',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            if (isSelf)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MentorMediaScreen(
                      mentorId: widget.mentorId,
                      isSelf: true,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? _kDarkBg : _kLightBg,
                    border: Border.all(
                      color: isDark ? Colors.white : Colors.black,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: _kNeoOrange, offset: Offset(2, 2)),
                    ],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+ THÊM / SỬA',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _mediaStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _kNeoOrange,
                  strokeWidth: 3,
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    isSelf
                        ? 'BẠN CHƯA CÓ ẢNH/VIDEO NÀO.\nHÃY BẤM THÊM / SỬA ĐỂ ĐĂNG!'
                        : 'MENTOR CHƯA ĐĂNG MEDIA.',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final docs = [...snapshot.data!.docs]
              ..sort((a, b) {
                final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
                final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
                if (aTs == null) return 1;
                if (bTs == null) return -1;
                return bTs.compareTo(aTs);
              });

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final docId = docs[index].id;
                final isVideo = data['type'] == 'video';
                final url = data['url'] as String? ?? '';
                final likes = List<String>.from(data['likes'] ?? []);
                final isLiked = likes.contains(currentUserId);

                return GestureDetector(
                  onTap: () => _viewMedia(context, data, docId),
                  child: _buildNeoContainer(
                    shadowColor: _kNeoOrange,
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (url.isNotEmpty)
                            (isVideo &&
                                    (data['thumbnailUrl'] == null ||
                                        data['thumbnailUrl']
                                            .toString()
                                            .isEmpty))
                                ? Container(
                                    color: Colors.black26,
                                    child: const Center(
                                      child: Icon(
                                        CupertinoIcons.play_circle_fill,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                  )
                                : GamenectNetworkImage(
                                    imageUrl: isVideo
                                        ? data['thumbnailUrl']!
                                        : url,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.black26,
                                      child: const Icon(
                                        CupertinoIcons.exclamationmark_triangle,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                          else
                            Container(
                              color: Colors.black26,
                              child: const Icon(
                                CupertinoIcons.photo,
                                color: Colors.white,
                              ),
                            ),

                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),

                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: GestureDetector(
                              onTap: () async {
                                if (currentUserId.isNotEmpty) {
                                  await FirestoreService()
                                      .toggleLikeMentorMedia(
                                        docId,
                                        currentUserId,
                                      );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isLiked
                                          ? CupertinoIcons.heart_fill
                                          : CupertinoIcons.heart,
                                      color: isLiked
                                          ? Colors.red
                                          : Colors.black,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${likes.length}',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (isVideo)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _kNeoOrange,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.play_fill,
                                      color: Colors.black,
                                      size: 12,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'VIDEO',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isSelf) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _kDarkBg : _kLightBg;

    if (isSelf) {
      return Container(
        color: bgColor,
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MentorEditProfileScreen(mentor: _mentor!),
              ),
            );
            if (updated == true) _loadData();
          },
          icon: const Icon(
            CupertinoIcons.pencil,
            size: 20,
            color: Colors.black,
          ),
          label: const Text(
            'CHỈNH SỬA HỒ SƠ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNeoOrange,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white : Colors.black,
                width: 3,
              ),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Follow button
          GestureDetector(
            onTap: _toggleFollow,
            child: _buildNeoContainer(
              bgColor: _isFollowing
                  ? (isDark ? _kDarkCard : _kLightCard)
                  : Colors.white,
              borderColor: _isFollowing
                  ? (isDark ? Colors.white : Colors.black)
                  : Colors.black,
              shadowColor: _isFollowing
                  ? (isDark ? Colors.white : Colors.black)
                  : Colors.black,
              borderRadius: 16,
              padding: const EdgeInsets.all(16),
              child: Icon(
                _isFollowing ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                color: _isFollowing ? Colors.red : Colors.black,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Match button
          Expanded(
            child: GestureDetector(
              onTap: _hasMatchRequest ? null : _showMatchRequestSheet,
              child: _buildNeoContainer(
                bgColor: _hasMatchRequest
                    ? (isDark ? _kDarkCard : _kLightCard)
                    : _kNeoOrange,
                shadowColor: _hasMatchRequest
                    ? Colors.transparent
                    : (isDark ? Colors.white : Colors.black),
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    _hasMatchRequest ? 'ĐÃ GỬI YÊU CẦU' : 'MATCH NGAY',
                    style: TextStyle(
                      color: _hasMatchRequest
                          ? (isDark ? Colors.white54 : Colors.black54)
                          : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewMedia(
    BuildContext context,
    Map<String, dynamic> initialData,
    String docId,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isVideo = initialData['type'] == 'video';
    final url = initialData['url'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: isVideo
                  ? _VideoPlayer(url: url)
                  : InteractiveViewer(
                      child: GamenectNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('mentor_media')
                  .doc(docId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final caption = data['caption']?.toString() ?? '';
                final likes = List<String>.from(data['likes'] ?? []);
                final isLiked = likes.contains(currentUserId);

                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141416) : _kLightBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isLiked
                                  ? CupertinoIcons.heart_fill
                                  : CupertinoIcons.heart,
                              color: isLiked
                                  ? Colors.red
                                  : (isDark ? Colors.white : Colors.black),
                              size: 28,
                            ),
                            onPressed: () async {
                              if (currentUserId.isNotEmpty) {
                                await FirestoreService().toggleLikeMentorMedia(
                                  docId,
                                  currentUserId,
                                );
                              }
                            },
                          ),
                          Text(
                            '${likes.length} lượt thích',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            caption,
                            style: TextStyle(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.9),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// COMPONENT CLASS
// ---------------------------------------------------------

class _VideoPlayer extends StatefulWidget {
  final String url;
  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
          _ctrl.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: _kNeoOrange));
    }
    return GestureDetector(
      onTap: () {
        if (_ctrl.value.isPlaying) {
          _ctrl.pause();
        } else {
          _ctrl.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _ctrl.value.aspectRatio,
            child: VideoPlayer(_ctrl),
          ),
          if (!_ctrl.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.play_circle_fill,
                color: Colors.white,
                size: 36,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatefulWidget {
  final String fromUserId;
  final double rating;
  final String comment;
  final Timestamp? createdAt;

  const _ReviewItem({
    required this.fromUserId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  @override
  State<_ReviewItem> createState() => _ReviewItemState();
}

class _ReviewItemState extends State<_ReviewItem> {
  Future<DocumentSnapshot>? _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.fromUserId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final textColor = isDark ? Colors.white : Colors.black;

    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final username =
            userData?['username'] ??
            (snapshot.connectionState == ConnectionState.waiting
                ? 'Đang tải...'
                : 'Học viên');
        final avatarUrl = userData?['avatarUrl'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(
              color: isDark ? Colors.white : Colors.black,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: _kNeoOrange, offset: Offset(3, 3)),
            ],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white : Colors.black,
                        width: 2,
                      ),
                      image: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Icon(
                            CupertinoIcons.person_solid,
                            size: 20,
                            color: isDark ? Colors.white : Colors.black,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username.toUpperCase(),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.star_fill,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.comment,
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MentorFollowerSheet extends StatefulWidget {
  final String mentorId;
  const _MentorFollowerSheet({required this.mentorId});

  @override
  State<_MentorFollowerSheet> createState() => _MentorFollowerSheetState();
}

class _MentorFollowerSheetState extends State<_MentorFollowerSheet> {
  late final Stream<QuerySnapshot> _followersStream;
  final Map<String, Future<DocumentSnapshot>> _userFutures = {};

  @override
  void initState() {
    super.initState();
    _followersStream = FirebaseFirestore.instance
        .collection('mentor_followers')
        .where('mentorId', isEqualTo: widget.mentorId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1E) : _kLightBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kNeoOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _kNeoOrange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.person_2_fill,
                        color: _kNeoOrange,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Người theo dõi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _followersStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _kNeoOrange),
                      );
                    }

                    final docs = snap.data?.docs ?? [];
                    final sorted = [...docs]
                      ..sort((a, b) {
                        final aT =
                            (a.data() as Map<String, dynamic>)['followedAt'];
                        final bT =
                            (b.data() as Map<String, dynamic>)['followedAt'];
                        if (aT == null && bT == null) return 0;
                        if (aT == null) return 1;
                        if (bT == null) return -1;
                        return (bT as Timestamp).compareTo(aT as Timestamp);
                      });

                    if (sorted.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.person_badge_plus,
                              size: 52,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chưa có người theo dõi',
                              style: TextStyle(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.4),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollCtrl,
                      itemCount: sorted.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, i) {
                        final d = sorted[i].data() as Map<String, dynamic>;
                        final followerId = d['followerId'] as String? ?? '';

                        final future = _userFutures.putIfAbsent(
                          followerId,
                          () => FirebaseFirestore.instance
                              .collection('users')
                              .doc(followerId)
                              .get(),
                        );

                        return FutureBuilder<DocumentSnapshot>(
                          future: future,
                          builder: (ctx, userSnap) {
                            final userData =
                                userSnap.data?.data() as Map<String, dynamic>?;
                            final name =
                                userData?['username'] as String? ??
                                userData?['displayName'] as String? ??
                                'Người dùng';
                            final avatar =
                                userData?['avatarUrl'] as String? ?? '';

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: _kNeoOrange.withValues(
                                  alpha: 0.15,
                                ),
                                backgroundImage: avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar.isEmpty
                                    ? const Icon(
                                        CupertinoIcons.person_solid,
                                        color: _kNeoOrange,
                                        size: 22,
                                      )
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: Icon(
                                CupertinoIcons.chevron_forward,
                                size: 14,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                              onTap:
                                  (followerId.isNotEmpty &&
                                      userSnap.hasData &&
                                      userData != null)
                                  ? () {
                                      final userModel = UserModel.fromMap(
                                        userData,
                                        followerId,
                                      );
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PeerProfileScreen(
                                            peerUser: userModel,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                            );
                          },
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
  }
}
