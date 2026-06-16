import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/network_image.dart';
import 'moment_card.dart';
import 'video_player_widget.dart';

/// Item trong grid view của FeedTab.
/// Hiển thị thumbnail (ảnh/video), play icon nếu là video,
/// reactions count và username. Khi tap mở MomentCard chi tiết.
class MomentGridItem extends StatefulWidget {
  final dynamic moment;
  final String currentUserId;

  const MomentGridItem({
    super.key,
    required this.moment,
    required this.currentUserId,
  });

  @override
  State<MomentGridItem> createState() => _MomentGridItemState();
}

class _MomentGridItemState extends State<MomentGridItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final Map<String, Map<String, dynamic>> _userCache = {};
  Future<Map<String, dynamic>?>? _userInfoFuture;

  @override
  void initState() {
    super.initState();
    _userInfoFuture = _getUserInfo(widget.moment.userId);
  }

  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (doc.exists) {
      _userCache[userId] = doc.data() as Map<String, dynamic>;
      return _userCache[userId];
    }
    return null;
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
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: MomentCard(
                      key: ValueKey(widget.moment.id),
                      moment: widget.moment,
                      currentUserId: widget.currentUserId,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: widget.moment.isVideo ? null : () => _showMomentDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(4, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video giữ đúng tỷ lệ và có nền đen giống chế độ feed.
              ColoredBox(
                color: widget.moment.isVideo
                    ? Colors.black
                    : const Color(0xFFF4F4F4),
                child: widget.moment.isVideo
                    ? VideoPlayerWidget(
                        videoUrl: widget.moment.mediaUrl,
                        compactControls: true,
                        webAutoplayFallback: true,
                      )
                    : GamenectNetworkImage(
                        imageUrl: widget.moment.mediaUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.grey[900]!, Colors.grey[800]!],
                            ),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.white54,
                            size: 40,
                          ),
                        ),
                      ),
              ),

              // Solid bottom bar instead of gradient
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.black, width: 3),
                    ),
                  ),
                ),
              ),

              // Reactions badge
              if (widget.moment.reactions.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white, // White
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('❤️', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.moment.reactions.length}',
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

              // Username + caption at bottom
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showMomentDetail(context),
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: _userInfoFuture,
                    builder: (context, snapshot) {
                      final userInfo = snapshot.data;
                      final username = userInfo?['username'] ?? 'User';
                      final avatarUrl = userInfo?['avatarUrl'];

                      return Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF00E676),
                              child: avatarUrl != null
                                  ? ClipOval(
                                      child: GamenectNetworkImage(
                                        imageUrl: avatarUrl,
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Text(
                                      username.isNotEmpty
                                          ? username[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  username.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.moment.caption?.isNotEmpty == true)
                                  Text(
                                    widget.moment.caption!,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
