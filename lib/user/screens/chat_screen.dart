import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart'; // Import package record
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart'; // Thêm import
import 'package:image_picker/image_picker.dart'; // Thêm import
import '../../core/providers/chat_provider.dart';
import '../../core/models/user_model.dart';
import 'video_call_screen.dart';
import '../../core/widgets/profile_card.dart';
import 'dart:ui';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'media_preview_screen.dart';
import 'voice_preview_screen.dart';
import '../../user/screens/subscription_screen.dart';

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

  // Voice recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;

  bool isPremium = false; // Thêm biến lưu trạng thái premium

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      //final chatProvider = Provider.of<ChatProvider>(context, listen: false);
     //await chatProvider.fetchMessages(widget.matchId);

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .set({
              'lastSeen_$userId': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        // Lấy trạng thái premium
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (mounted) {
          setState(() {
            isPremium = userDoc.data()?['isPremium'] == true;
          });
        }
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

  // Bắt đầu ghi âm
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
      }
    } catch (e) {
      developer.log('Error starting recording: $e', name: 'ChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi ghi âm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Dừng và gửi tin nhắn thoại
  Future<void> _stopAndSendRecording() async {
  try {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path != null) {
      final audioPlayer = AudioPlayer();
      await audioPlayer.setFilePath(path);
      final duration = audioPlayer.duration?.inSeconds ?? 0;
      await audioPlayer.dispose();

      // HIỂN THỊ PREVIEW
      final shouldSend = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => VoicePreviewScreen(
            audioFile: File(path),
            duration: duration,
          ),
        ),
      );

      if (shouldSend == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text('Đang gửi tin nhắn thoại...'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.black87,
          ),
        );

        final file = File(path);
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('voice_messages')
            .child('${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}.m4a');

        await storageRef.putFile(file);
        final downloadUrl = await storageRef.getDownloadURL();

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.sendVoiceMessage(
          widget.matchId,
          downloadUrl,
          duration: duration,
        );

        await file.delete();
      } else {
        await File(path).delete();
      }
    }
  } catch (e) {
    developer.log('Error: $e', name: 'ChatScreen', error: e);
  }
}

  // Hủy ghi âm
  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      developer.log('Error canceling recording: $e', name: 'ChatScreen');
    }
  }

  void _sendMedia(String localPath, {bool isVideo = false, String? caption}) async {
  if (!isPremium) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
    return;
  }

  try {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 100,
        left: MediaQuery.of(context).size.width / 2 - 40,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFFFF453A),
                  strokeWidth: 3,
                ),
                SizedBox(height: 8),
                Text(
                  'Đang gửi...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(overlayEntry);

    final file = File(localPath);
    final fileName =
        '${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}${isVideo ? '.mp4' : '.jpg'}';
    final storageRef = FirebaseStorage.instance
        .ref()
        .child(isVideo ? 'chat_videos' : 'chat_images')
        .child(fileName);

    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    // GỌI ĐÚNG HÀM NÀY
    await Provider.of<ChatProvider>(context, listen: false).sendMediaWithNotify(
      widget.matchId,
      downloadUrl,
      isVideo: isVideo,
      caption: caption,
      peerUser: widget.peerUser,
    );

    overlayEntry.remove();

    developer.log('Media sent: $downloadUrl', name: 'ChatScreen');
  } catch (e) {
    developer.log('Error sending media: $e', name: 'ChatScreen', error: e);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi gửi ${isVideo ? 'video' : 'ảnh'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
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
                                      'callerId': currentUserId,
                                      'type': 'voice',
                                      'answered': false,
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
                            onPressed: () async {
                              final granted =
                                  await _requestCameraAndMicPermissions();
                              if (granted) {
                                await FirebaseFirestore.instance
                                    .collection('calls')
                                    .doc(widget.matchId)
                                    .set({
                                      'status': 'active',
                                      'callerId': currentUserId,
                                      'type': 'video',
                                      'answered': false,
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
                              bottom: 8,
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
                  top: false,
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
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Color(0xFFFF453A), size: 20),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final pickedFile = await showModalBottomSheet<XFile?>(
                                context: context,
                                builder: (context) => Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  child: SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.photo, color: Color(0xFFFF453A)),
                                          title: const Text('Chọn ảnh', style: TextStyle(color: Colors.white)),
                                          onTap: () async {
                                            final file = await picker.pickImage(source: ImageSource.gallery);
                                            Navigator.pop(context, file);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.videocam, color: Color(0xFFFF453A)),
                                          title: const Text('Chọn video', style: TextStyle(color: Colors.white)),
                                          onTap: () async {
                                            final file = await picker.pickVideo(source: ImageSource.gallery);
                                            Navigator.pop(context, file);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              if (pickedFile != null) {
                                final isVideo = pickedFile.path.endsWith('.mp4') ||
                                                pickedFile.path.endsWith('.mov') ||
                                                pickedFile.path.endsWith('.MOV');

                                // HIỂN THỊ PREVIEW
                                final caption = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MediaPreviewScreen(
                                      file: File(pickedFile.path),
                                      isVideo: isVideo,
                                    ),
                                  ),
                                );

                                // Chỉ gửi nếu user bấm "Gửi" (không bấm back)
                                if (caption != null) {
                                  _sendMedia(pickedFile.path, isVideo: isVideo);
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // TextField
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 120),
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

                        // Nút mic/send với recording indicator
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, child) {
                            final isEmpty = value.text.trim().isEmpty;
                            return GestureDetector(
                              onLongPressStart: isEmpty
                                  ? (_) => _startRecording()
                                  : null,
                              onLongPressEnd: isEmpty
                                  ? (_) => _stopAndSendRecording()
                                  : null,
                              onLongPressCancel: isEmpty
                                  ? () => _cancelRecording()
                                  : null,
                              child: Container(
                                width: 36,
                                height: 36,
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isRecording
                                        ? const Color(0xFFFF453A)
                                        : Colors.white.withValues(alpha: 0.2),
                                    width: _isRecording ? 2 : 1,
                                  ),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    isEmpty ? Icons.mic : Icons.send,
                                    color: isEmpty
                                        ? (_isRecording
                                              ? const Color(0xFFFF453A)
                                              : Colors.white)
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
                                    }
                                  },
                                ),
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

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    String avatarUrl,
    String timeString,
  ) {
    final isCall = msg['type'] == 'call';
    final isVoice = msg['type'] == 'voice';

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
                      ? [
                          callColor.withValues(alpha: 0.3),
                          callColor.withValues(alpha: 0.2),
                        ]
                      : callStatus == 'cancelled'
                      ? [
                          Colors.grey.withValues(alpha: 0.3),
                          Colors.grey.withValues(alpha: 0.2),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
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

    // Voice message bubble
    if (isVoice) {
      final audioUrl = msg['audioUrl'] as String?;
      final duration = msg['duration'] as int? ?? 0;
      final reactions = (msg['reactions'] as List?) ?? [];

      return Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: !isMe
                ? () async {
                    final emoji = await showModalBottomSheet<String>(
                      context: context,
                      builder: (context) => SizedBox(
                        height: 80,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ['👍', '❤️', '😂', '😮', '😢', '😡'].map((
                            e,
                          ) {
                            return GestureDetector(
                              onTap: () => Navigator.pop(context, e),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 28),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                    if (emoji != null) {
                      await Provider.of<ChatProvider>(
                        context,
                        listen: false,
                      ).reactToMessage(widget.matchId, msg['id'], emoji);
                    }
                  }
                : null,
            onDoubleTap: !isMe
                ? () async {
                    await Provider.of<ChatProvider>(
                      context,
                      listen: false,
                    ).reactToMessage(widget.matchId, msg['id'], '❤️');
                  }
                : null,
            child: _VoiceMessageBubble(
              audioUrl: audioUrl ?? '',
              duration: duration,
              isMe: isMe,
            ),
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 40 : 0,
                right: isMe ? 8 : 40,
                top: 4,
              ),
              child: Wrap(
                spacing: 4,
                children: reactions.map<Widget>((r) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      r['emoji'] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      );
    }

    final mediaUrl = msg['mediaUrl'] as String?;
    final isVideo = msg['isVideo'] == true;
    final text = msg['text'] ?? '';

    final reactions = (msg['reactions'] as List?) ?? [];
    final currentUserId = Provider.of<ChatProvider>(
      context,
      listen: false,
    ).currentUserId;

    return GestureDetector(
      onLongPress: !isMe
          ? () async {
              final emoji = await showModalBottomSheet<String>(
                context: context,
                builder: (context) => SizedBox(
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['👍', '❤️', '😂', '😮', '😢', '😡'].map((e) {
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, e),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      );
                    }).toList(),
                  ),
                ),
              );
              if (emoji != null) {
                await Provider.of<ChatProvider>(
                  context,
                  listen: false,
                ).reactToMessage(widget.matchId, msg['id'], emoji);
              }
            }
          : null,
      onDoubleTap: !isMe
          ? () async {
              await Provider.of<ChatProvider>(
                context,
                listen: false,
              ).reactToMessage(widget.matchId, msg['id'], '❤️');
            }
          : null,
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
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
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
                              const Color(0xFFFF453A).withValues(alpha: 0.8),
                              const Color(0xFFFF6961).withValues(alpha: 0.8),
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

          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 40 : 0,
                right: isMe ? 8 : 40,
                top: 4,
              ),
              child: Wrap(
                spacing: 4,
                children: reactions.map<Widget>((r) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      r['emoji'] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
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
    _audioRecorder.dispose();
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

class _VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isMe;

  const _VoiceMessageBubble({
    required this.audioUrl,
    required this.duration,
    required this.isMe,
    Key? key,
  }) : super(key: key);

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  late AudioPlayer _player;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
        bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
        bottomRight: Radius.circular(widget.isMe ? 4 : 20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          margin: EdgeInsets.only(
            left: widget.isMe ? 40 : 0,
            right: widget.isMe ? 8 : 40,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: widget.isMe
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFF453A).withValues(alpha: 0.8),
                      const Color(0xFFFF6961).withValues(alpha: 0.8),
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
              bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 20),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _player.pause();
              } else {
                await _player.setUrl(widget.audioUrl);
                await _player.play();
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 100,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.duration > 0
                      ? '${widget.duration ~/ 60}:${(widget.duration % 60).toString().padLeft(2, '0')}'
                      : '0:00',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
