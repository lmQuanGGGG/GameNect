import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/models/user_model.dart';
import 'video_call_screen.dart';
import '../../core/widgets/profile_card.dart';
import 'dart:ui';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;
  final UserModel peerUser;
  const ChatScreen({super.key, required this.matchId, required this.peerUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.fetchMessages(widget.matchId);

      // Đánh dấu đã xem tin nhắn - SỬA ĐỂ REAL-TIME
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .set({
              'lastSeen_$userId':
                  FieldValue.serverTimestamp(), // DÙNG serverTimestamp
            }, SetOptions(merge: true));
      }
    });
  }

  Future<bool> _requestCameraAndMicPermissions() async {
    developer.log('Requesting permissions...', name: 'ChatScreen');

    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraStatus = statuses[Permission.camera]!;
    final micStatus = statuses[Permission.microphone]!;

    developer.log('Permission Results:', name: 'ChatScreen');
    developer.log('Camera: $cameraStatus', name: 'ChatScreen');
    developer.log('Microphone: $micStatus', name: 'ChatScreen');

    if (cameraStatus.isGranted && micStatus.isGranted) {
      developer.log('All permissions granted!', name: 'ChatScreen');
      return true;
    }

    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      if (!mounted) return false;

      developer.log('Permissions permanently denied', name: 'ChatScreen');

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Cần cấp quyền',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Bạn đã từ chối quyền vĩnh viễn.\n\n'
              'Để sử dụng video call, hãy:\n'
              '1. Bấm "Mở Cài đặt"\n'
              '2. Tìm "Gamenect"\n'
              '3. Bật Camera và Microphone',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Mở Cài đặt',
                  style: TextStyle(color: Color(0xFFFF453A)),
                ),
              ),
            ],
          ),
        ),
      );

      if (result == true) {
        await openAppSettings();
      }
      return false;
    }

    if (cameraStatus.isDenied || micStatus.isDenied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Bạn cần cho phép quyền Camera và Microphone để gọi video',
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Back button
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    color: Color(0xFFFF453A),
                                    size: 28,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Avatar + Name
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: Text(widget.peerUser.username),
                                  ),
                                  body: Center(
                                    child: ProfileCard(user: widget.peerUser),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF453A,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      widget.peerUser.avatarUrl != null &&
                                          widget.peerUser.avatarUrl!.isNotEmpty
                                      ? NetworkImage(widget.peerUser.avatarUrl!)
                                      : null,
                                  backgroundColor: const Color(
                                    0xFFFF453A,
                                  ).withValues(alpha: 0.3),
                                  child: widget.peerUser.avatarUrl == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.peerUser.username,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 17,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'Chạm ghé',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Call buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildGlassButton(
                            icon: Icons.phone_rounded,
                            onPressed: () async {
                              final granted = await Permission.microphone
                                  .request();
                              if (granted.isGranted) {
                                await FirebaseFirestore.instance
                                    .collection('calls')
                                    .doc(widget.matchId)
                                    .set({
                                      'status': 'active',
                                      'callerId':
                                          currentUserId, // THÊM dòng này
                                      'type': 'voice', // ĐÃ CÓ
                                      'answered': false, // THÊM dòng này
                                      'startedAt': DateTime.now()
                                          .toIso8601String(),
                                    }, SetOptions(merge: true));
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VideoCallScreen(
                                      channelName: widget.matchId,
                                      peerUserId: widget.peerUser.id,
                                      peerUsername: widget.peerUser.username,
                                      peerAvatarUrl: widget.peerUser.avatarUrl,
                                      isVoiceCall: true,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildGlassButton(
                            icon: Icons.videocam_rounded,
                            // Ví dụ cho nút gọi video
                            onPressed: () async {
                              final granted =
                                  await _requestCameraAndMicPermissions();
                              if (granted) {
                                // THÊM callerId vào đây
                                await FirebaseFirestore.instance
                                    .collection('calls')
                                    .doc(widget.matchId)
                                    .set({
                                      'status': 'active',
                                      'callerId':
                                          currentUserId, // THÊM dòng này
                                      'type':
                                          'video', // THÊM dòng này để phân biệt video/voice
                                      'answered': false, // THÊM dòng này
                                      'startedAt': DateTime.now()
                                          .toIso8601String(),
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
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background image với overlay
          Positioned.fill(
            child: Image.network(
              'https://i.pinimg.com/736x/27/0d/d2/270dd2fe9c3765a4dd48486bceba963e.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.black);
              },
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: chatProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF453A),
                        ),
                      )
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: chatProvider.messagesStream(
                          widget.matchId,
                          widget.peerUser,
                        ),
                        builder: (context, snapshot) {
                          final messages = snapshot.data ?? [];

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.only(
                              top: 110,
                              bottom: 8, // Padding nhỏ
                              left: 8,
                              right: 8,
                            ),
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
                                      left: isMe ? 0 : 44,
                                      right: isMe ? 20 : 0,
                                      top: 2,
                                      bottom: 8,
                                    ),
                                    child: Text(
                                      timeString,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.w500,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 4,
                                          ),
                                        ],
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

              // Typing indicator
              StreamBuilder<bool>(
                stream: chatProvider.peerTypingStream(
                  widget.matchId,
                  widget.peerUser.id,
                ),
                builder: (context, snapshot) {
                  final isPeerTyping = snapshot.data ?? false;
                  if (!isPeerTyping) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.peerUser.username} đang nhập...',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Input message box
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false, // Không cần padding top
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Nút cộng
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Color(0xFFFF453A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // TextField
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(
                              maxHeight:
                                  120, // Giới hạn chiều cao khi gõ nhiều dòng
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'iMessage',
                                hintStyle: TextStyle(
                                  color: Colors.grey.withValues(alpha: 0.5),
                                  fontSize: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF453A),
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                fillColor: Colors.black.withValues(alpha: 0.3),
                                filled: true,
                                isDense: true,
                              ),
                              onChanged: (text) {
                                chatProvider.setTyping(
                                  widget.matchId,
                                  isTyping: text.isNotEmpty,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Nút mic/send
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, child) {
                            final isEmpty = value.text.trim().isEmpty;
                            return Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  isEmpty ? Icons.mic : Icons.send,
                                  color: isEmpty
                                      ? Colors.white
                                      : const Color(0xFFFF453A),
                                  size: 20,
                                ),
                                onPressed: () async {
                                  if (!isEmpty) {
                                    await chatProvider.sendMessage(
                                      widget.matchId,
                                      value.text.trim(),
                                      peerUser: widget.peerUser,
                                    );

                                    _controller.clear();
                                    chatProvider.setTyping(
                                      widget.matchId,
                                      isTyping: false,
                                    );
                                  } else {
                                    // TODO: Gửi voice
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // XÓA bottomNavigationBar
      // XÓA bottomNavigationBar hoàn toàn
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: const Color(0xFFFF453A), size: 18),
            padding: EdgeInsets.zero,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  SnackBar _buildGlassSnackBar(String message) {
    return SnackBar(
      content: Text(message),
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 2),
      dismissDirection: DismissDirection.horizontal,
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    String avatarUrl,
    String timeString,
  ) {
    final isCall = msg['type'] == 'call';

    if (isCall) {
      final callStatus = msg['callStatus'] ?? '';
      String callText;
      IconData callIcon;
      Color callColor;

      switch (callStatus) {
        case 'missed':
          callText = 'Cuộc gọi nhỡ';
          callIcon = Icons.call_missed_rounded;
          callColor = const Color(0xFFFF453A);
          break;
        case 'declined':
          callText = 'Cuộc gọi bị từ chối';
          callIcon = Icons.phone_disabled_rounded;
          callColor = Colors.orange;
          break;
        case 'cancelled':
          callText = 'Đã hủy';
          callIcon = Icons.phone_missed_rounded;
          callColor = Colors.grey;
          break;
        case 'ended':
          callText = msg['text'] ?? 'Đã gọi';
          callIcon = Icons.call_rounded;
          callColor = Colors.green;
          break;
        default:
          callText = msg['text'] ?? 'Cuộc gọi';
          callIcon = Icons.call_rounded;
          callColor = Colors.white;
      }

      return Align(
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: (callStatus == 'missed' || callStatus == 'declined')
                      ? [callColor.withOpacity(0.3), callColor.withOpacity(0.2)]
                      : callStatus == 'cancelled'
                      ? [
                          Colors.grey.withOpacity(0.3),
                          Colors.grey.withOpacity(0.2),
                        ]
                      : [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(callIcon, color: callColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    callText,
                    style: TextStyle(
                      color: callColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final mediaUrl = msg['mediaUrl'] as String?;
    final isVideo = msg['isVideo'] == true;
    final text = msg['text'] ?? '';

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 6, bottom: 2),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF453A).withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: (avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                backgroundColor: const Color(0xFFFF453A).withValues(alpha: 0.3),
                child: (avatarUrl.isEmpty)
                    ? const Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
        Flexible(
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (mediaUrl != null && mediaUrl.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(
                    bottom: 6,
                    left: isMe ? 40 : 0,
                    right: isMe ? 8 : 40,
                  ),
                  constraints: const BoxConstraints(
                    maxWidth: 250,
                    maxHeight: 250,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: isVideo
                        ? VideoPlayerBubble(videoUrl: mediaUrl)
                        : CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF453A),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.error,
                                color: Color(0xFFFF453A),
                              ),
                            ),
                          ),
                  ),
                ),
              if (text.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      margin: EdgeInsets.only(
                        left: isMe ? 40 : 0,
                        right: isMe ? 8 : 40,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: isMe
                            ? LinearGradient(
                                colors: [
                                  const Color(
                                    0xFFFF453A,
                                  ).withValues(alpha: 0.8),
                                  const Color(
                                    0xFFFF6961,
                                  ).withValues(alpha: 0.8),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.white.withValues(alpha: 0.15),
                                ],
                              ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 20),
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: isMe
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF453A,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Widget video bubble
class VideoPlayerBubble extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerBubble({super.key, required this.videoUrl});

  @override
  State<VideoPlayerBubble> createState() => _VideoPlayerBubbleState();
}

class _VideoPlayerBubbleState extends State<VideoPlayerBubble> {
  late VideoPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isReady = true);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF453A)),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        children: [
          VideoPlayer(_controller),
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: _controller.value.isPlaying
                    ? const SizedBox.shrink()
                    : Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
