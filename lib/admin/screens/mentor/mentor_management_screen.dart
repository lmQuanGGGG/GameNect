// lib/admin/screens/mentor/mentor_management_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/mentor_model.dart';
import '../../../core/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../user/screens/mentor_profile_screen.dart';

const _kAdminBg = Color(0xFF0D0D10);
const _kAccent = Color(0xFFFF6E40);
const _kGlassBg = Color(0x14FFFFFF);
const _kGlassBorder = Color(0x1FFFFFFF);

/// Admin: Màn hình quản lý đơn đăng ký Mentor — Task 7.1
class MentorManagementScreen extends StatefulWidget {
  const MentorManagementScreen({super.key});

  @override
  State<MentorManagementScreen> createState() => _MentorManagementScreenState();
}

class _MentorManagementScreenState extends State<MentorManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final FirestoreService _service = FirestoreService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildGlass({required Widget child, double radius = 16}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _kGlassBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _kGlassBorder, width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kAdminBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _buildGlass(
          radius: 12,
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm theo tên mentor...',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: _kAccent,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _kAccent,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Chờ duyệt'),
            Tab(text: 'Đã duyệt'),
            Tab(text: 'Từ chối'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildList('pending'),
          _buildList('approved'),
          _buildList('rejected'),
        ],
      ),
    );
  }

  Widget _buildList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mentor_profiles')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Lỗi tải dữ liệu: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kAccent));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_rounded, size: 56, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 8),
                Text(
                  'Không có đơn nào',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                ),
              ],
            ),
          );
        }

        // Sắp xếp danh sách cục bộ theo appliedAt giảm dần (mới nhất lên đầu)
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aMap = a.data() as Map<String, dynamic>? ?? {};
          final bMap = b.data() as Map<String, dynamic>? ?? {};
          
          final aTime = aMap['appliedAt'];
          final bTime = bMap['appliedAt'];
          
          DateTime aDate = DateTime.fromMillisecondsSinceEpoch(0);
          DateTime bDate = DateTime.fromMillisecondsSinceEpoch(0);
          
          if (aTime is Timestamp) aDate = aTime.toDate();
          if (bTime is Timestamp) bDate = bTime.toDate();
          if (aTime is String) aDate = DateTime.tryParse(aTime) ?? aDate;
          if (bTime is String) bDate = DateTime.tryParse(bTime) ?? bDate;
          
          return bDate.compareTo(aDate);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, i) {
            final mentor = MentorModel.fromMap(
              sortedDocs[i].data() as Map<String, dynamic>,
              sortedDocs[i].id,
            );
            return _ApplicationCard(
              mentor: mentor,
              service: _service,
              glassBuilder: _buildGlass,
              searchQuery: _searchQuery,
            );
          },
        );
      },
    );
  }
}

// ── ApplicationCard ────────────────────────────────────────────────────────────
class _ApplicationCard extends StatefulWidget {
  final MentorModel mentor;
  final FirestoreService service;
  final Widget Function({required Widget child, double radius}) glassBuilder;
  final String searchQuery;

  const _ApplicationCard({
    required this.mentor,
    required this.service,
    required this.glassBuilder,
    this.searchQuery = '',
  });

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  String _username = '';
  String _avatarUrl = '';
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.mentor.userId)
          .get();
      if (mounted && doc.data() != null) {
        setState(() {
          _username = doc.data()!['username'] ?? 'User';
          _avatarUrl = doc.data()!['avatarUrl'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _approve() async {
    setState(() => _isActing = true);
    try {
      await widget.service.approveMentor(widget.mentor.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã duyệt Mentor: $_username'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _showRejectDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Từ chối đơn của $_username?', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập lý do từ chối:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'VD: Thiếu thông tin thành tích...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(context);
              setState(() => _isActing = true);
              try {
                await widget.service.rejectMentor(widget.mentor.userId, reason);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã từ chối đơn'), backgroundColor: Colors.grey),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isActing = false);
              }
            },
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF181A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MentorProfileScreen(mentorId: widget.mentor.userId),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _kAccent.withValues(alpha: 0.4), width: 2),
                          image: _avatarUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _avatarUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white38, size: 26)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            Text(
                              'Ứng tuyển ${_timeAgo(widget.mentor.appliedAt)}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Tựa game đăng ký', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: widget.mentor.games.map((g) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(g, style: const TextStyle(color: _kAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Giới thiệu bản thân (Bio)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                  child: Text(widget.mentor.bio, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                const SizedBox(height: 16),
                const Text('Thành tích / Kinh nghiệm', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                  child: Text(widget.mentor.achievements, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                if (widget.mentor.rejectReason?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lý do từ chối trước đó:', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.mentor.rejectReason!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng', style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.searchQuery.isNotEmpty && _username.isNotEmpty) {
      if (!_username.toLowerCase().contains(widget.searchQuery.toLowerCase())) {
        return const SizedBox.shrink();
      }
    } else if (widget.searchQuery.isNotEmpty && _username.isEmpty) {
      return const SizedBox.shrink();
    }

    final status = widget.mentor.status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _showDetailDialog,
        borderRadius: BorderRadius.circular(16),
        child: widget.glassBuilder(
          radius: 16,
          child: Padding(
            padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MentorProfileScreen(mentorId: widget.mentor.userId),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _kAccent.withValues(alpha: 0.4), width: 2),
                              image: _avatarUrl.isNotEmpty
                                  ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: _avatarUrl.isEmpty
                                ? const Icon(Icons.person, color: Colors.white38, size: 22)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(
                                  _timeAgo(widget.mentor.appliedAt),
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildStatusBadge(status),
                ],
              ),

              // Games
              if (widget.mentor.games.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: widget.mentor.games.map((g) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
                    ),
                    child: Text(g, style: const TextStyle(color: _kAccent, fontSize: 11)),
                  )).toList(),
                ),
              ],

              // Bio & Achievements
              if (widget.mentor.bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('📝 ${widget.mentor.bio}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (widget.mentor.achievements.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('🏆 ${widget.mentor.achievements}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],

              // Reject reason
              if (widget.mentor.rejectReason?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Text('Lý do: ${widget.mentor.rejectReason}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],

              // Actions — chỉ hiển thị nếu pending
              if (status == 'pending') ...[
                const SizedBox(height: 12),
                _isActing
                    ? const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2))
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _showRejectDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Từ chối'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _approve,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Duyệt', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
              ],
            ],
          ),
        ),
      ),
      )
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved': color = Colors.green; label = '✅ Đã duyệt'; break;
      case 'rejected': color = Colors.red; label = '❌ Từ chối'; break;
      default: color = Colors.amber; label = '⏳ Chờ duyệt';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    return '${diff.inMinutes} phút trước';
  }
}
