import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:ui';
import '../../../core/providers/moment_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/theme/theme_helper.dart';
import '../../../core/widgets/network_image.dart';
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
          backgroundColor: context.dialogBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Xóa khoảnh khắc?',
              style: TextStyle(color: context.textColor)),
          content: Text('Bạn có chắc muốn xóa khoảnh khắc này?',
              style: TextStyle(color: context.textSecondaryColor)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Hủy', style: TextStyle(color: context.textSecondaryColor)),
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
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Colors.white24,
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 6,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: MomentCard(
                  key: ValueKey(moment.id),
                  moment: moment,
                  currentUserId: userId,
                ),
              ),
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
    final profileProvider = context.watch<ProfileProvider>();
    final avatarUrl = profileProvider.userData?.avatarUrl;

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
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.textColor, width: 3),
                    boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(4, 4))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_rounded, size: 64, color: context.textColor),
                      const SizedBox(height: 12),
                      Text(
                        'CHƯA CÓ KHOẢNH KHẮC',
                        style: TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(8, topPadding, 8, 120),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: myMoments.length,
          itemBuilder: (context, index) {
            final moment = myMoments[index];
            return GestureDetector(
              onTap: () => _showMomentDetail(context, moment, userId),
              onLongPress: () => _deleteMoment(context, moment.id),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.textColor, width: 3),
                  boxShadow: [BoxShadow(color: context.textColor, offset: const Offset(3, 3))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail image/video
                      GamenectNetworkImage(
                        imageUrl: (moment.isVideo && moment.thumbnailUrl != null)
                            ? moment.thumbnailUrl!
                            : moment.mediaUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.grey[900]),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.2),
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                      if (moment.isVideo)
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      Positioned(
                        bottom: 8, left: 8, right: 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (moment.caption?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  moment.caption!,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500, height: 1.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Row(
                              children: [
                                Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6E40),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                    image: (avatarUrl?.isNotEmpty == true)
                                        ? DecorationImage(
                                            image: NetworkImage(avatarUrl!), 
                                            fit: BoxFit.cover
                                          ) 
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: (avatarUrl?.isNotEmpty != true)
                                      ? const Text('B', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Bạn',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)]
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }
}
