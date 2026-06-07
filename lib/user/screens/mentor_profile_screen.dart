// lib/user/screens/mentor_profile_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import '../../core/models/mentor_model.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/mentor_provider.dart';
import '../../core/services/firestore_service.dart';
import 'mentor_media_screen.dart';
import 'mentor_edit_profile_screen.dart';
import 'shared/peer_profile_screen.dart';

const _kBg = Color(0xFF101012);
const _kAccent = Color(0xFFFF6E40);
const _kLiveBadge = Color(0xFFFF3B30);
const _kGlassBg = Color(0x14FFFFFF);
const _kGlassBorder = Color(0x1FFFFFFF);

/// Màn hình profile chi tiết của 1 Mentor — Task 6.2
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeMentorStream();
  }

  @override
  void dispose() {
    _mentorSub?.cancel();
    super.dispose();
  }

  void _subscribeMentorStream() {
    _mentorSub = FirestoreService().getMentorProfileStream(widget.mentorId).listen((mentor) {
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
      // Load mentor profile
      _mentor = await FirebaseFirestore.instance
          .collection('mentor_profiles')
          .doc(widget.mentorId)
          .get()
          .then((doc) => doc.exists
              ? MentorModel.fromMap(doc.data()!, doc.id)
              : null);

      // Load user info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.mentorId)
          .get();
      _mentorUser = userDoc.data();

      // Check follow & match request
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

      // Check if currently live
      final liveSnap = await FirebaseFirestore.instance
          .collection('livestreams')
          .where('mentorId', isEqualTo: widget.mentorId)
          .where('status', isEqualTo: 'live')
          .limit(1)
          .get();
      if (liveSnap.docs.isNotEmpty) {
        _liveStreamId = liveSnap.docs.first.id;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGlassContainer({required Widget child, double radius = 24}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: _kGlassBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _kGlassBorder, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || widget.mentorId == currentUserId) return;
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (widget.mentorId == currentUserId) return;
    final msgCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gửi Match Request',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Viết lời nhắn cho Mentor (tùy chọn)',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ví dụ: Mình muốn học Valorant, nhờ Mentor hướng dẫn...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  if (currentUserId == null) return;
                  final ok = await context.read<MentorProvider>().sendMatchRequest(
                    currentUserId,
                    widget.mentorId,
                    msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
                  );
                  if (mounted) {
                    setState(() => _hasMatchRequest = ok);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'Đã gửi Match Request!' : 'Gửi thất bại, thử lại'),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ));
                  }
                },
                child: const Text('Gửi Request', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog() {
    double selectedRating = 5.0;
    final commentCtrl = TextEditingController();
    bool isSubmitting = false;
    final messenger = ScaffoldMessenger.of(context);
    final mentorProvider = context.read<MentorProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Đánh giá Mentor',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Bạn cảm thấy thế nào về Mentor này?',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Stars row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1.0;
                  return IconButton(
                    icon: Icon(
                      selectedRating >= starVal ? CupertinoIcons.star_fill : CupertinoIcons.star,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = starVal;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Nhập ý kiến nhận xét của bạn...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                      });
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      if (currentUserId == null) return;

                      final navigator = Navigator.of(dialogContext);

                      final ok = await mentorProvider.rateMentor(
                        fromUserId: currentUserId,
                        toMentorId: widget.mentorId,
                        rating: selectedRating,
                        comment: commentCtrl.text.trim(),
                      );

                      navigator.pop();

                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Cảm ơn bạn đã gửi đánh giá!' : 'Đánh giá thất bại, hãy thử lại'),
                            backgroundColor: ok ? Colors.green : Colors.red,
                          ),
                        );
                        if (ok) {
                          _loadData();
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Gửi', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = widget.mentorId == currentUserId;
    return Scaffold(
      backgroundColor: _kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mentor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : _mentor == null
              ? const Center(child: Text('Không tìm thấy Mentor', style: TextStyle(color: Colors.white70)))
              : Stack(
                  children: [
                    // Background
                    Positioned(
                      top: -50, right: -50,
                      child: Container(
                        width: 250, height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kAccent.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    // Content
                    SafeArea(
                      bottom: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar + name
                            Center(
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        width: 96, height: 96,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: _kAccent, width: 2.5),
                                          image: (_mentorUser?['avatarUrl'] as String?)?.isNotEmpty == true
                                              ? DecorationImage(
                                                  image: NetworkImage(_mentorUser!['avatarUrl']),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: (_mentorUser?['avatarUrl'] as String?)?.isNotEmpty != true
                                            ? const Icon(CupertinoIcons.person_solid, color: Colors.white54, size: 48)
                                            : null,
                                      ),
                                      if (_liveStreamId != null)
                                        Positioned(
                                          bottom: 2, right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _kLiveBadge,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _mentorUser?['username'] ?? 'Mentor',
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _kAccent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(CupertinoIcons.star_fill, color: _kAccent, size: 14),
                                        SizedBox(width: 4),
                                        Text('Mentor', style: TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Stats
                            _buildGlassContainer(
                              radius: 16,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    GestureDetector(
                                      onTap: isSelf ? null : _showRatingDialog,
                                      behavior: HitTestBehavior.opaque,
                                      child: _buildStat(CupertinoIcons.star_fill, Colors.amber, _mentor!.rating.toStringAsFixed(1), 'Rating'),
                                    ),
                                    Container(width: 1, height: 30, color: Colors.white12),
                                    GestureDetector(
                                      onTap: isSelf ? () => _showFollowerSheet() : null,
                                      behavior: HitTestBehavior.opaque,
                                      child: _buildStat(
                                        CupertinoIcons.person_2_fill,
                                        isSelf ? _kAccent : const Color(0xFF64B5F6),
                                        '${_mentor!.followerCount}',
                                        isSelf ? 'Followers ›' : 'Followers',
                                      ),
                                    ),
                                    Container(width: 1, height: 30, color: Colors.white12),
                                    _buildStat(CupertinoIcons.play_rectangle_fill, const Color(0xFFFF5252), '${_mentor!.totalStreams}', 'Streams'),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            _buildTabs(),

                            const SizedBox(height: 16),

                            _buildTabContent(),
                          ],
                        ),
                      ),
                    ),

                    // Bottom action bar
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: _buildGlassContainer(
                        radius: 0,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                if (isSelf) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final updated = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MentorEditProfileScreen(mentor: _mentor!),
                                          ),
                                        );
                                        if (updated == true) {
                                          _loadData();
                                        }
                                      },
                                      icon: const Icon(CupertinoIcons.pencil, size: 18),
                                      label: const Text('Chỉnh sửa hồ sơ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _kAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  if (_liveStreamId != null) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => Navigator.pushNamed(
                                          context, '/live-stream',
                                          arguments: {'streamId': _liveStreamId!, 'isMentor': true},
                                        ),
                                        icon: const Icon(CupertinoIcons.play_circle_fill, size: 18),
                                        label: const Text('Vào Live của bạn'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _kLiveBadge,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ] else ...[
                                  // Follow/Unfollow
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _toggleFollow,
                                      icon: Icon(_isFollowing ? CupertinoIcons.heart_fill : CupertinoIcons.heart, size: 18),
                                      label: Text(_isFollowing ? 'Đang theo dõi' : 'Theo dõi'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _isFollowing ? Colors.red : Colors.white,
                                        side: BorderSide(color: _isFollowing ? Colors.red : Colors.white38),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  if (_liveStreamId != null) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => Navigator.pushNamed(
                                          context, '/live-stream',
                                          arguments: {'streamId': _liveStreamId!, 'isMentor': false},
                                        ),
                                        icon: const Icon(CupertinoIcons.play_circle_fill, size: 18),
                                        label: const Text('Xem Live'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _kLiveBadge,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  // Match Request
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _hasMatchRequest ? null : _showMatchRequestSheet,
                                      icon: Icon(_hasMatchRequest ? CupertinoIcons.checkmark_alt : CupertinoIcons.gamecontroller_fill, size: 18),
                                      label: Text(_hasMatchRequest ? 'Đã gửi' : 'Match'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _hasMatchRequest ? Colors.grey : _kAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStat(IconData icon, Color iconColor, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11)),
      ],
    );
  }


  Widget _buildSlidingSwitch({
    required int selectedIndex,
    required List<String> options,
    required ValueChanged<int> onChange,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                left: selectedIndex * width,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: _kAccent,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 1.5),
                      )
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(options.length, (index) {
                  final isSelected = selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChange(index),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          child: Text(options[index]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    return _buildSlidingSwitch(
      selectedIndex: _activeTab,
      options: const ['Thông tin', 'Ảnh & Video'],
      onChange: (val) => setState(() => _activeTab = val),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildInfoTab();
      case 1:
        return _buildAlbumTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInfoTab() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = widget.mentorId == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_mentor!.games.isNotEmpty) ...[
          _buildGlassContainer(
            radius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(CupertinoIcons.gamecontroller_fill, 'Games chuyên môn'),
                  const SizedBox(height: 14),
                  _buildGamesList(_mentor!.games),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_mentor!.bio.isNotEmpty) ...[
          _buildGlassContainer(
            radius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(CupertinoIcons.person_crop_circle_fill, 'Giới thiệu bản thân'),
                  const SizedBox(height: 14),
                  _buildBioCard(_mentor!.bio),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_mentor!.achievements.isNotEmpty) ...[
          _buildGlassContainer(
            radius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(CupertinoIcons.rosette, 'Thành tích nổi bật'),
                  const SizedBox(height: 14),
                  _buildAchievementsCard(_mentor!.achievements),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildGlassContainer(
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader(CupertinoIcons.text_bubble_fill, 'Nhận xét từ Học viên'),
                    if (!isSelf)
                      GestureDetector(
                        onTap: _showRatingDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _kAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.add, color: _kAccent, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Đánh giá',
                                style: TextStyle(
                                  color: _kAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('mentor_ratings')
                      .where('toMentorId', isEqualTo: widget.mentorId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.01),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Chưa có lượt đánh giá nào.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                          ),
                        ),
                      );
                    }

                    final ratingDocs = [...snapshot.data!.docs];
                    ratingDocs.sort((a, b) {
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
                        final doc = ratingDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final fromUserId = data['fromUserId'] as String? ?? '';
                        final rating = (data['rating'] ?? 0.0).toDouble();
                        final comment = data['comment'] as String? ?? '';
                        final createdAt = data['createdAt'] as Timestamp?;

                        return _ReviewItem(
                          fromUserId: fromUserId,
                          rating: rating,
                          comment: comment,
                          createdAt: createdAt,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kAccent.withValues(alpha: 0.3), width: 1),
          ),
          child: Icon(icon, color: _kAccent, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildGamesList(List<dynamic> games) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: games.map((g) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kAccent.withValues(alpha: 0.2),
                const Color(0xFFBF360C).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _kAccent.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.gamecontroller_fill, color: _kAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                g.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBioCard(String bio) {
    return Stack(
      children: [
        Positioned(
          right: -5,
          bottom: -10,
          child: Icon(
            CupertinoIcons.quote_bubble_fill,
            size: 48,
            color: Colors.white.withValues(alpha: 0.03),
          ),
        ),
        Text(
          bio,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsCard(String achievements) {
    final lines = achievements
        .split(RegExp(r'[\n•]'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                CupertinoIcons.checkmark_seal_fill,
                color: Colors.amber,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlbumTab() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isSelf = widget.mentorId == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('🖼️ Album Ảnh & Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            if (isSelf)
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MentorMediaScreen(mentorId: widget.mentorId, isSelf: true),
                    ),
                  );
                },
                icon: const Icon(CupertinoIcons.photo_on_rectangle, color: _kAccent, size: 18),
                label: const Text('Thêm / Sửa', style: TextStyle(color: _kAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirestoreService().getMentorMedia(widget.mentorId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: _kAccent),
              ));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    isSelf ? 'Bạn chưa có ảnh/video nào.\nHãy bấm Thêm / Sửa để đăng!' : 'Mentor chưa đăng ảnh/video nào',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final docs = [...snapshot.data!.docs];
            docs.sort((a, b) {
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
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final url = data['url'] as String? ?? '';
                final isVideo = data['type'] == 'video';
                final likes = List<String>.from(data['likes'] ?? []);
                final isLiked = likes.contains(currentUserId);

                return GestureDetector(
                  onTap: () => _viewMedia(context, data, docId),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (url.isNotEmpty)
                            Image.network(
                              isVideo ? (data['thumbnailUrl'] ?? url) : url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.white10,
                                child: const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white38),
                              ),
                            )
                          else
                            Container(color: Colors.white10, child: const Icon(CupertinoIcons.photo, color: Colors.white24)),
                          
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                          
                          Positioned(
                            bottom: 10,
                            left: 10,
                            child: GestureDetector(
                              onTap: () async {
                                if (currentUserId.isNotEmpty) {
                                  await FirestoreService().toggleLikeMentorMedia(docId, currentUserId);
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                          color: isLiked ? const Color(0xFFFF2D55) : Colors.white70,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${likes.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          if (isVideo)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white24, width: 0.8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.play_fill,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          'Video',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          
                          if (data['caption'] != null && data['caption'].toString().isNotEmpty)
                            Positioned(
                              top: 10,
                              left: 10,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    color: Colors.black.withValues(alpha: 0.3),
                                    child: Text(
                                      data['caption'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
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
              },
            );
          },
        ),
      ],
    );
  }

  void _viewMedia(BuildContext context, Map<String, dynamic> initialData, String docId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isVideo = initialData['type'] == 'video';
    final url = initialData['url'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: isVideo
                  ? _VideoPlayer(url: url)
                  : InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('mentor_media').doc(docId).snapshots(),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF141416),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                              color: isLiked ? Colors.red : Colors.white,
                              size: 28,
                            ),
                            onPressed: () async {
                              if (currentUserId.isNotEmpty) {
                                await FirestoreService().toggleLikeMentorMedia(docId, currentUserId);
                              }
                            },
                          ),
                          Text(
                            '${likes.length} lượt thích',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      if (caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            caption,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.4),
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
      return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
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
          AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl)),
          if (!_ctrl.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 36),
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
    _userFuture = FirebaseFirestore.instance.collection('users').doc(widget.fromUserId).get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final username = userData?['username'] ??
            (snapshot.connectionState == ConnectionState.waiting ? 'Đang tải...' : 'Học viên');
        final avatarUrl = userData?['avatarUrl'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _kAccent.withValues(alpha: 0.3), width: 1.5),
                      image: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? const Icon(CupertinoIcons.person_solid, size: 18, color: Colors.white38)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < widget.rating ? CupertinoIcons.star_fill : CupertinoIcons.star,
                              color: Colors.amber,
                              size: 13,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  if (widget.createdAt != null)
                    Text(
                      _formatDate(widget.createdAt!.toDate()),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10.5),
                    ),
                ],
              ),
              if (widget.comment.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    widget.comment,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ── Follower List Bottom Sheet (for Mentor's own profile) ──────────────────
class _MentorFollowerSheet extends StatelessWidget {
  final String mentorId;
  const _MentorFollowerSheet({required this.mentorId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6E40).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(CupertinoIcons.person_2_fill, color: Color(0xFFFF6E40), size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Người theo dõi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              // List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('mentor_followers')
                      .where('mentorId', isEqualTo: mentorId)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFF6E40)),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    final sorted = [...docs];
                    sorted.sort((a, b) {
                      final aT = (a.data() as Map<String,dynamic>)['followedAt'];
                      final bT = (b.data() as Map<String,dynamic>)['followedAt'];
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
                            Icon(CupertinoIcons.person_badge_plus, size: 52, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            Text(
                              'Chưa có người theo dõi',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
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
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(followerId).get(),
                          builder: (ctx, userSnap) {
                            final userData = userSnap.data?.data() as Map<String, dynamic>?;
                            final name = userData?['username'] as String? ?? userData?['displayName'] as String? ?? 'Người dùng';
                            final avatar = userData?['avatarUrl'] as String? ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFFF6E40).withValues(alpha: 0.15),
                                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar.isEmpty
                                    ? const Icon(CupertinoIcons.person_solid, color: Color(0xFFFF6E40), size: 22)
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              trailing: const Icon(CupertinoIcons.chevron_forward, size: 14, color: Colors.white30),
                              onTap: (followerId.isNotEmpty && userSnap.hasData && userData != null) ? () {
                                final userModel = UserModel.fromMap(userData, followerId);
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PeerProfileScreen(peerUser: userModel),
                                  ),
                                );
                              } : null,
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
