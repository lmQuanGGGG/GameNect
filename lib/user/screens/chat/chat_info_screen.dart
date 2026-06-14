import 'package:flutter/material.dart';
import '../../../core/theme/theme_helper.dart';
import '../../../core/widgets/network_image.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'full_screen_media_viewer.dart';
import '../../../core/services/firestore_service.dart';

class ChatInfoScreen extends StatefulWidget {
  final String matchId;
  final String peerName;
  final String peerAvatarUrl;
  final String myAvatarUrl;
  final VoidCallback? onClose;

  const ChatInfoScreen({
    super.key,
    required this.matchId,
    required this.peerName,
    required this.peerAvatarUrl,
    required this.myAvatarUrl,
    this.onClose,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _messagesStream = FirestoreService().messagesStream(widget.matchId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _extractUrl(String text) {
    final urlRegExp = RegExp(
      r'(?:(?:https?):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+',
      caseSensitive: false,
    );
    final match = urlRegExp.firstMatch(text);
    if (match != null) {
      String url = text.substring(match.start, match.end);
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Kho lưu trữ',
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: widget.onClose == null,
        iconTheme: IconThemeData(color: context.textColor),
        actions: widget.onClose != null
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.textColor, width: 2)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFF6E40),
              unselectedLabelColor: context.textSecondaryColor,
              indicatorColor: const Color(0xFFFF6E40),
              indicatorWeight: 4,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              tabs: const [
                Tab(text: 'Ảnh/Video'),
                Tab(text: 'Liên kết'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _messagesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6E40)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Đã có lỗi xảy ra: ${snapshot.error}', style: TextStyle(color: context.textColor)));
          }

          final messages = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              KeepAliveWrapper(child: _buildMediaTab(messages)),
              KeepAliveWrapper(child: _buildLinksTab(messages)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMediaTab(List<Map<String, dynamic>> messages) {
    final mediaMessages = messages.where((msg) {
      return msg['isRecalled'] != true && msg['mediaUrl'] != null;
    }).toList().reversed.toList();

    if (mediaMessages.isEmpty) {
      return Center(child: Text('Chưa có ảnh/video nào được chia sẻ', style: TextStyle(color: context.textSecondaryColor)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: mediaMessages.length,
      itemBuilder: (context, index) {
        final data = mediaMessages[index];
        final mediaUrl = data['mediaUrl'] as String;
        final isVideo = data['isVideo'] == true;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenMediaViewer(
                  mediaUrl: mediaUrl,
                  isVideo: isVideo,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.textColor, width: 1.5),
              color: context.cardBgColor,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GamenectNetworkImage(
                  imageUrl: isVideo ? '' : mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: context.cardBgColor),
                  errorWidget: (context, url, error) => Container(color: context.cardBgColor, child: Icon(Icons.videocam, color: context.textSecondaryColor)),
                ),
                if (isVideo)
                  const Center(
                    child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      data['senderId'] == FirebaseAuth.instance.currentUser?.uid
                          ? 'Bạn'
                          : widget.peerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinksTab(List<Map<String, dynamic>> messages) {
    final linkMessages = messages.where((msg) {
      if (msg['isRecalled'] == true) return false;
      final text = msg['text'] as String? ?? '';
      return _extractUrl(text) != null;
    }).toList().reversed.toList();

    if (linkMessages.isEmpty) {
      return Center(child: Text('Chưa có liên kết nào được chia sẻ', style: TextStyle(color: context.textSecondaryColor)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: linkMessages.length,
      itemBuilder: (context, index) {
        final data = linkMessages[index];
        final text = data['text'] as String;
        final url = _extractUrl(text)!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.cardBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.textColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: context.textColor,
                      offset: const Offset(4, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AnyLinkPreview(
                    link: url,
                    displayDirection: UIDirection.uiDirectionHorizontal,
                    showMultimedia: true,
                    bodyMaxLines: 2,
                    bodyTextOverflow: TextOverflow.ellipsis,
                    titleStyle: TextStyle(
                      color: context.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    bodyStyle: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.transparent,
                    borderRadius: 0,
                    removeElevation: true,
                    errorWidget: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              url,
                              style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gửi bởi: ${data['senderId'] == FirebaseAuth.instance.currentUser?.uid ? 'Bạn' : widget.peerName}',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: context.textTertiaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
