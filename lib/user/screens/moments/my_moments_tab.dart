import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:ui';
import '../../../core/providers/moment_provider.dart';
import 'moment_card.dart';

/// Tab "Của tôi" — hiển thị moments do user hiện tại đăng.
/// Hỗ trợ xóa moment (long press) với xác nhận dialog.
class MyMomentsTab extends StatelessWidget {
  const MyMomentsTab({super.key});

  Future<void> _deleteMoment(BuildContext context, String momentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Xóa khoảnh khắc?',
              style: TextStyle(color: Colors.white)),
          content: const Text('Bạn có chắc muốn xóa khoảnh khắc này?',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('moments')
            .doc(momentId)
            .get();
        final data = doc.data() ?? {};
        final mediaUrl = data['mediaUrl'] as String?;
        final thumbUrl = data['thumbnailUrl'] as String?;

        await FirebaseFirestore.instance.collection('moments').doc(momentId).delete();

        // Thử xóa file trên Storage (bỏ qua lỗi)
        try {
          if (mediaUrl != null && mediaUrl.startsWith('http')) {
            await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
          }
          if (thumbUrl != null && thumbUrl.startsWith('http')) {
            await FirebaseStorage.instance.refFromURL(thumbUrl).delete();
          }
        } catch (_) {}

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã xóa khoảnh khắc'),
              backgroundColor: Colors.deepOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }

  void _showMomentDetail(BuildContext context, dynamic moment, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, _) => Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(child: MomentCard(moment: moment, currentUserId: userId)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final topPadding = MediaQuery.of(context).padding.top + 120;

    return Consumer<MomentProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.deepOrange, strokeWidth: 3),
          );
        }

        final myMoments = provider.moments.where((m) => m.userId == userId).toList();

        if (myMoments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.deepOrange.withValues(alpha: 0.2),
                        Colors.orange.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: Icon(Icons.photo_library_rounded, size: 80,
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
                const SizedBox(height: 24),
                const Text('Bạn chưa đăng khoảnh khắc nào',
                    style: TextStyle(color: Colors.white70, fontSize: 17, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(8, topPadding, 8, 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: myMoments.length,
          itemBuilder: (context, index) {
            final moment = myMoments[index];
            return GestureDetector(
              onTap: () => _showMomentDetail(context, moment, userId),
              onLongPress: () => _deleteMoment(context, moment.id),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail image/video
                    Image.network(
                      (moment.isVideo && moment.thumbnailUrl != null)
                          ? moment.thumbnailUrl!
                          : moment.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey[900]),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    if (moment.isVideo)
                      Positioned(
                        top: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    if (moment.caption?.isNotEmpty == true)
                      Positioned(
                        bottom: 12, left: 12, right: 12,
                        child: Text(moment.caption!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
