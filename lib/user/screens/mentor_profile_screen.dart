// lib/user/screens/mentor_profile_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/mentor_model.dart';
import '../../core/providers/mentor_provider.dart';
import '../../core/services/firestore_service.dart';

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
                      selectedRating >= starVal ? Icons.star : Icons.star_border,
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
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
                                            ? const Icon(Icons.person, color: Colors.white54, size: 48)
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
                                        Icon(Icons.star, color: _kAccent, size: 14),
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
                                      child: _buildStat('⭐', _mentor!.rating.toStringAsFixed(1), 'Rating'),
                                    ),
                                    _buildStatDivider(),
                                    _buildStat('👥', '${_mentor!.followerCount}', 'Followers'),
                                    _buildStatDivider(),
                                    _buildStat('📺', '${_mentor!.totalStreams}', 'Streams'),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Games
                            if (_mentor!.games.isNotEmpty) ...[
                              const Text('🎮 Games', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: _mentor!.games.map((g) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _kAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(g, style: const TextStyle(color: _kAccent, fontSize: 13)),
                                )).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Bio
                            if (_mentor!.bio.isNotEmpty) ...[
                              const Text('📝 Giới thiệu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 8),
                              _buildGlassContainer(
                                radius: 14,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(_mentor!.bio, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), height: 1.6)),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Achievements
                            if (_mentor!.achievements.isNotEmpty) ...[
                              const Text('🏆 Thành tích', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 8),
                              _buildGlassContainer(
                                radius: 14,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(_mentor!.achievements, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), height: 1.6)),
                                ),
                              ),
                            ],
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
                                    child: TextButton.icon(
                                      onPressed: null,
                                      icon: const Icon(Icons.person, color: Colors.white54, size: 18),
                                      label: const Text('Hồ sơ của bạn', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                                      style: TextButton.styleFrom(
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
                                        icon: const Icon(Icons.live_tv, size: 18),
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
                                      icon: Icon(_isFollowing ? Icons.favorite : Icons.favorite_border, size: 18),
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
                                        icon: const Icon(Icons.live_tv, size: 18),
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
                                      icon: Icon(_hasMatchRequest ? Icons.check : Icons.sports_esports, size: 18),
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

  Widget _buildStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11)),
      ],
    );
  }

  Widget _buildStatDivider() => Container(
    width: 1, height: 40,
    color: Colors.white.withValues(alpha: 0.12),
  );
}
