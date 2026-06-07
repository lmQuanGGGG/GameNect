import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/mentor_match_request_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/theme_helper.dart';

const _kAccent = Color(0xFFFF6E40);

/// Màn hình quản lý Match Requests của Mentor — Task 6.6
class MentorRequestsScreen extends StatelessWidget {
  const MentorRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mentorId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Match Requests',
          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: context.appBarBgColor),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background orbs
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kAccent.withValues(alpha: 0.15 * context.bgOrbOpacityMultiplier),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.08 * context.bgOrbOpacityMultiplier),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<List<MentorMatchRequestModel>>(
              stream: service.getMentorMatchRequests(mentorId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _kAccent));
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
                            color: _kAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.game_controller_solid, size: 64, color: _kAccent.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Chưa có Match Request nào',
                          style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Người chơi sẽ gửi request để được\nbạn hướng dẫn gaming',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.textTertiaryColor, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, i) =>
                      _RequestCard(request: requests[i], service: service),
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
  String _username = '';
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
          _username = doc.data()!['username'] ?? 'User';
          _avatarUrl = doc.data()!['avatarUrl'] ?? '';
        });
      }
    } catch (_) {}
  }

  Widget _buildGlassContainer({required Widget child, double radius = 16}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardBgColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: context.cardBorderColor, width: 1.2),
          ),
          child: child,
        ),
      ),
    );
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
          SnackBar(content: Text('Đã chấp nhận request của $_username!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi, thử lại'), backgroundColor: Colors.red),
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
          const SnackBar(content: Text('Đã từ chối request'), backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi, thử lại'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = _timeAgo(widget.request.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassContainer(
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _kAccent.withValues(alpha: 0.5), width: 2),
                      image: _avatarUrl.isNotEmpty
                          ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _avatarUrl.isEmpty
                        ? Icon(Icons.person, color: context.textTertiaryColor, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _username,
                          style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(CupertinoIcons.time, size: 12, color: context.textTertiaryColor),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo,
                              style: TextStyle(color: context.textTertiaryColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Match', style: TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),

              // Message
              if (widget.request.message?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(CupertinoIcons.quote_bubble, size: 16, color: context.textTertiaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${widget.request.message}"',
                          style: TextStyle(color: context.textSecondaryColor, fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Actions
              _isActing
                  ? const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2))
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _reject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.textSecondaryColor,
                              side: BorderSide(color: context.cardBorderColor, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _accept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: const Text('Chấp nhận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
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
