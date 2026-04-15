import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'moment_card.dart';

/// Item trong grid view của FeedTab.
/// Hiển thị thumbnail (ảnh/video), play icon nếu là video,
/// reactions count và username. Khi tap mở MomentCard chi tiết.
class MomentGridItem extends StatelessWidget {
  final dynamic moment;
  final String currentUserId;

  const MomentGridItem({
    super.key,
    required this.moment,
    required this.currentUserId,
  });

  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  void _showMomentDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: MomentCard(moment: moment, currentUserId: currentUserId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMomentDetail(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            CachedNetworkImage(
              imageUrl: (moment.isVideo && moment.thumbnailUrl != null)
                  ? moment.thumbnailUrl!
                  : moment.mediaUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.grey[900]!, Colors.grey[800]!],
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.deepOrange, strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[900]!, Colors.grey[800]!],
                  ),
                ),
                child: const Icon(Icons.error_outline, color: Colors.white54, size: 40),
              ),
            ),

            // Gradient overlay
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

            // Play icon overlay for videos
            if (moment.isVideo)
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                ),
              ),

            // Reactions badge
            if (moment.reactions.isNotEmpty)
              Positioned(
                top: 10, right: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('❤️', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('${moment.reactions.length}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Username + caption at bottom
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _getUserInfo(moment.userId),
                builder: (context, snapshot) {
                  final userInfo = snapshot.data;
                  final username = userInfo?['username'] ?? 'User';
                  final avatarUrl = userInfo?['avatarUrl'];

                  return Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(username[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(username,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (moment.caption?.isNotEmpty == true)
                              Text(moment.caption!,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
