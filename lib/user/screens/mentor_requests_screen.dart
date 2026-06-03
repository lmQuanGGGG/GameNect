// lib/user/screens/mentor_requests_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/mentor_match_request_model.dart';
import '../../core/services/firestore_service.dart';

const _kBg = Color(0xFF101012);
const _kAccent = Color(0xFFFF6E40);


/// Màn hình quản lý Match Requests của Mentor — Task 6.6
class MentorRequestsScreen extends StatelessWidget {
  const MentorRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mentorId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Match Requests',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.white.withValues(alpha: 0.04)),
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
                color: _kAccent.withValues(alpha: 0.08),
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
                        Icon(Icons.sports_esports_outlined, size: 72, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có Match Request nào',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Người chơi sẽ gửi request để được\nbạn hướng dẫn gaming',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0x1FFFFFFF), width: 1.2),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildGlassContainer(
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _kAccent.withValues(alpha: 0.4), width: 2),
                      image: _avatarUrl.isNotEmpty
                          ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white38, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _username,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Message
              if (widget.request.message?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    '"${widget.request.message}"',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Actions
              _isActing
                  ? const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2))
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _reject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Từ chối'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _accept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Chấp nhận', style: TextStyle(fontWeight: FontWeight.bold)),
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
