// lib/user/screens/mentor_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/mentor_match_request_model.dart';
import '../../../core/services/firestore_service.dart';

const _kAccent = Color(0xFFFF6E40);
const _kLiveRed = Color(0xFFFF2D55);

const _kDarkBg = Color(0xFF121214);
const _kLightBg = Color(0xFFF4F4F0);
const _kDarkCard = Color(0xFF2A2A32);
const _kLightCard = Colors.white;

/// Màn hình quản lý Match Requests của Mentor — Neo-Brutalism
class MentorRequestsScreen extends StatefulWidget {
  const MentorRequestsScreen({super.key});

  @override
  State<MentorRequestsScreen> createState() => _MentorRequestsScreenState();
}

class _MentorRequestsScreenState extends State<MentorRequestsScreen> {
  late final Stream<List<MentorMatchRequestModel>> _requestsStream;
  final FirestoreService _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    final mentorId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _requestsStream = _service.getMentorMatchRequests(mentorId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _kDarkBg : _kLightBg;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ── Neo App Bar ───────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(bottom: BorderSide(color: borderColor, width: 3)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _kAccent,
                        border: Border.all(color: borderColor, width: 3),
                        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: Colors.black, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'MATCH REQUESTS',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<MentorMatchRequestModel>>(
              stream: _requestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 3));
                }

                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardColor,
                            border: Border.all(color: borderColor, width: 3),
                            boxShadow: [BoxShadow(color: _kAccent, offset: const Offset(5, 5))],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(CupertinoIcons.game_controller_solid, size: 64, color: textColor),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'TRỐNG TRƠN!',
                          style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chưa có ai gửi yêu cầu ghép đội\nvới bạn lúc này.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                  physics: const BouncingScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, i) =>
                      _RequestCard(request: requests[i], service: _service),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final MentorMatchRequestModel request;
  final FirestoreService service;

  const _RequestCard({required this.request, required this.service});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  String _username = 'PLAYER';
  String _avatarUrl = '';
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.request.fromUserId)
          .get();
      if (mounted && doc.data() != null) {
        setState(() {
          _username = (doc.data()!['username'] ?? 'Player').toString().toUpperCase();
          _avatarUrl = doc.data()!['avatarUrl'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _accept() async {
    setState(() => _isActing = true);
    try {
      await widget.service.acceptMentorMatchRequest(
        widget.request.id,
        widget.request.fromUserId,
        widget.request.toMentorId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ĐÃ CHẤP NHẬN $_username!', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            backgroundColor: Colors.green,
            shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.white, width: 2)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('LỖI KHI XỬ LÝ', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            backgroundColor: _kLiveRed,
            shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.white, width: 2)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isActing = true);
    try {
      await widget.service.rejectMentorMatchRequest(widget.request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ĐÃ TỪ CHỐI YÊU CẦU', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            backgroundColor: Colors.grey.shade800,
            shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.white, width: 2)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('LỖI KHI XỬ LÝ', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            backgroundColor: _kLiveRed,
            shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.white, width: 2)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _kDarkBg : _kLightBg;
    final cardColor = isDark ? _kDarkCard : _kLightCard;
    final borderColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    final timeAgo = _timeAgo(widget.request.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 4, right: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: const [BoxShadow(color: _kAccent, offset: Offset(5, 5))],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(2, 2))],
                  image: _avatarUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: _avatarUrl.isEmpty
                    ? Icon(Icons.person, color: textColor.withValues(alpha: 0.5), size: 28)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _username,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(CupertinoIcons.time_solid, size: 14, color: textColor.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo.toUpperCase(),
                          style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kAccent,
                  border: Border.all(color: borderColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('MATCH', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),

          // ── Lời nhắn ───────────────────────────────────────────────────────
          if (widget.request.message?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(CupertinoIcons.quote_bubble_fill, size: 16, color: _kAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${widget.request.message}"',
                      style: TextStyle(color: textColor, fontSize: 14, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Actions ────────────────────────────────────────────────────────
          _isActing
              ? const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 3))
              : Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _reject,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            border: Border.all(color: borderColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(2, 2))],
                          ),
                          child: Center(
                            child: Text(
                              'TỪ CHỐI',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _accept,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _kAccent,
                            border: Border.all(color: borderColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(3, 3))],
                          ),
                          child: const Center(
                            child: Text(
                              'CHẤP NHẬN',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }
}