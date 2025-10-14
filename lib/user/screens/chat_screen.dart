import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/models/user_model.dart';
import 'video_call_screen.dart';
import '../../core/widgets/profile_card.dart';
import 'dart:developer' as developer; // thêm dòng này

class ChatScreen extends StatefulWidget {
  final String matchId;
  final UserModel peerUser;
  const ChatScreen({super.key, required this.matchId, required this.peerUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Đợi frame hiện tại build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(
        context,
        listen: false,
      ).fetchMessages(widget.matchId);
    });
  }

  Future<bool> _requestCameraAndMicPermissions() async {
    developer.log('Requesting permissions...', name: 'ChatScreen');

    // Request cả hai cùng lúc
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraStatus = statuses[Permission.camera]!;
    final micStatus = statuses[Permission.microphone]!;

    developer.log('Permission Results:', name: 'ChatScreen');
    developer.log('Camera: $cameraStatus', name: 'ChatScreen');
    developer.log('Microphone: $micStatus', name: 'ChatScreen');

    // Nếu cả hai đều granted
    if (cameraStatus.isGranted && micStatus.isGranted) {
      developer.log('All permissions granted!', name: 'ChatScreen');
      return true;
    }

    // Nếu permanently denied - theo docs phải dùng openAppSettings()
    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      if (!mounted) return false;

      developer.log('Permissions permanently denied', name: 'ChatScreen');

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cần cấp quyền'),
          content: const Text(
            'Bạn đã từ chối quyền vĩnh viễn.\n\n'
            'Để sử dụng video call, hãy:\n'
            '1. Bấm "Mở Cài đặt"\n'
            '2. Tìm "Gamenect"\n'
            '3. Bật Camera và Microphone',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mở Cài đặt'),
            ),
          ],
        ),
      );

      if (result == true) {
        // Theo docs: Dùng openAppSettings()
        await openAppSettings();
      }
      return false;
    }

    // Nếu bị denied (không phải permanently)
    if (cameraStatus.isDenied || micStatus.isDenied) {
      if (!mounted) return false;

      developer.log('Permissions denied (not permanently)', name: 'ChatScreen');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn cần cho phép quyền Camera và Microphone để gọi video',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }

    // Nếu restricted (do parental controls)
    if (cameraStatus.isRestricted || micStatus.isRestricted) {
      if (!mounted) return false;

      developer.log('Permissions restricted by OS', name: 'ChatScreen');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Quyền bị hạn chế bởi hệ thống (có thể do kiểm soát của cha mẹ)',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUserId = chatProvider.currentUserId;
    final myAvatarUrl = chatProvider.currentUser?.avatarUrl ?? '';
    final peerAvatarUrl = widget.peerUser.avatarUrl ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.peerUser.username),
            IconButton(
              icon: CircleAvatar(
                radius: 16,
                backgroundImage:
                    widget.peerUser.avatarUrl != null &&
                        widget.peerUser.avatarUrl!.isNotEmpty
                    ? NetworkImage(widget.peerUser.avatarUrl!)
                    : null,
                child: widget.peerUser.avatarUrl == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              tooltip: 'Xem trang cá nhân',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(widget.peerUser.username)),
                      body: Center(child: ProfileCard(user: widget.peerUser)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () async {
              final granted = await _requestCameraAndMicPermissions();
              if (granted) {
                // Tạo trạng thái cuộc gọi Firestore
                await FirebaseFirestore.instance.collection('calls').doc(widget.matchId).set({
                  'status': 'active',
                  'startedAt': DateTime.now().toIso8601String(),
                }, SetOptions(merge: true));
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoCallScreen(
                      channelName: widget.matchId,
                      peerUserId: widget.peerUser.id,
                      peerUsername: widget.peerUser.username,
                      peerAvatarUrl: widget.peerUser.avatarUrl,
                    ),
                  ),
                );
                // Hiển thị trạng thái sau khi gọi xong
                if (result == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cuộc gọi kết thúc')),
                  );
                }
              } else {
                var cameraStatus = await Permission.camera.status;
                var micStatus = await Permission.microphone.status;
                String message =
                    'Bạn cần cấp quyền camera và micro để gọi video!';
                if (cameraStatus.isPermanentlyDenied ||
                    micStatus.isPermanentlyDenied) {
                  message =
                      'Quyền camera hoặc micro bị từ chối vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền.';
                } else if (!cameraStatus.isGranted || !micStatus.isGranted) {
                  message =
                      'Không thể cấp quyền camera hoặc micro. Vui lòng thử lại.';
                }
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Nền gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFf8fafc), Color(0xFFe0e7ff)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: chatProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: chatProvider.messagesStream(widget.matchId),
                        builder: (context, snapshot) {
                          final messages = snapshot.data ?? [];
                          return ListView.builder(
                            reverse: true,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[messages.length - 1 - index];
                              final isMe = msg['senderId'] == currentUserId;
                              final avatarUrl = isMe
                                  ? myAvatarUrl
                                  : peerAvatarUrl;
                              final timestamp = msg['timestamp'];
                              String timeString = '';
                              if (timestamp != null) {
                                if (timestamp is DateTime) {
                                  timeString = _formatTime(timestamp);
                                } else if (timestamp is String) {
                                  timeString = _formatTime(
                                    DateTime.tryParse(timestamp) ??
                                        DateTime.now(),
                                  );
                                } else if (timestamp is Timestamp) {
                                  timeString = _formatTime(timestamp.toDate());
                                }
                              }

                              return Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  _buildMessageBubble(
                                    msg,
                                    isMe,
                                    avatarUrl,
                                    timeString,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: isMe ? 0 : 32,
                                      right: isMe ? 32 : 0,
                                      top: 2,
                                      bottom: 8,
                                    ),
                                    child: Text(
                                      timeString,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
              ),
              // Typing indicator (giả lập)
              AnimatedOpacity(
                opacity: chatProvider.isPeerTyping ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text('${widget.peerUser.username} đang nhập...'),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(16),
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (text) {
                            setState(
                              () {},
                            ); // Để hiệu ứng typing indicator hoạt động
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      chatProvider.isLoading
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.blueAccent,
                              ),
                              onPressed: () {
                                final text = _controller.text.trim();
                                if (text.isNotEmpty) {
                                  chatProvider.sendMessage(
                                    widget.matchId,
                                    text,
                                  );
                                  _controller.clear();
                                  setState(() {}); // Ẩn typing indicator
                                }
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    String avatarUrl,
    String timeString,
  ) {
    final isCall = msg['type'] == 'call';
    final isMissed = msg['callStatus'] == 'missed';

    if (isCall) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isMissed ? Colors.red[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMissed ? Icons.call_missed : Icons.call,
                color: isMissed ? Colors.red : Colors.blueAccent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isMissed
                    ? 'Cuộc gọi nhỡ'
                    : 'Đã gọi ${_formatDuration(msg['duration'] ?? 0)}',
                style: TextStyle(
                  color: isMissed ? Colors.red : Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4, bottom: 2),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
          ),
        Flexible(
          child: Container(
            margin: EdgeInsets.symmetric(
              vertical: 4,
              horizontal: isMe ? 12 : 0,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFFB2EBF2).withOpacity(
                      0.85,
                    ) // pastel xanh cho mình
                  : const Color(
                      0xFFFFF9C4,
                    ).withOpacity(0.85), // pastel vàng cho đối phương
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              msg['text'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.black : Colors.deepOrange,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        if (isMe)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8, bottom: 2),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.deepOrange[100],
              child: const Icon(
                Icons.person,
                size: 18,
                color: Colors.deepOrange,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes phút ${secs > 0 ? '$secs giây' : ''}';
    }
    return '$secs giây';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
