import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart'; 
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart'; 
import 'package:image_picker/image_picker.dart'; 
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

// Màn hình chat giữa 2 user đã match
// Hỗ trợ gửi text, ảnh, video, voice message, video call/voice call
// Real-time messaging với Firestore, typing indicator, reactions
// Glassmorphism UI theo phong cách iMessage iOS
class ChatScreen extends StatefulWidget {
  final String matchId; // ID của match (dùng làm room chat)
  final UserModel peerUser; // Thông tin user đối phương
  
  const ChatScreen({super.key, required this.matchId, required this.peerUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder(); // Package record để ghi âm
  bool _isRecording = false; // Trạng thái đang ghi âm
  String? _recordingPath; // Đường dẫn file âm thanh tạm

  bool isPremium = false; // Trạng thái Premium của user hiện tại

  @override
  void initState() {
    super.initState();
    // Sau khi build xong, fetch messages và update lastSeen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      //final chatProvider = Provider.of<ChatProvider>(context, listen: false);
     //await chatProvider.fetchMessages(widget.matchId);

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // Update lastSeen để đánh dấu user đã đọc tin nhắn
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .set({
              'lastSeen_$userId': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        
        // Kiểm tra trạng thái Premium của user
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

  // Request quyền Camera và Microphone để video call
  // Hiển thị dialog hướng dẫn nếu bị từ chối vĩnh viễn
  Future<bool> _requestCameraAndMicPermissions() async {
    developer.log('Requesting permissions...', name: 'ChatScreen');

    // Request 2 quyền cùng lúc
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraStatus = statuses[Permission.camera]!;
    final micStatus = statuses[Permission.microphone]!;

    developer.log('Permission Results:', name: 'ChatScreen');
    developer.log('Camera: $cameraStatus', name: 'ChatScreen');
    developer.log('Microphone: $micStatus', name: 'ChatScreen');

    // Cả 2 quyền đều granted -> OK
    if (cameraStatus.isGranted && micStatus.isGranted) {
      developer.log('All permissions granted!', name: 'ChatScreen');
      return true;
    }

    // Nếu bị permanently denied -> hiển thị dialog yêu cầu mở Settings
    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      if (!mounted) return false;

      developer.log('Permissions permanently denied', name: 'ChatScreen');

      // Dialog hướng dẫn user vào Settings
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

      // Nếu user chọn Mở Cài đặt
      if (result == true) {
        await openAppSettings();
      }
      return false;
    }

    // Nếu bị denied (chưa permanently) -> hiển thị snackbar
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

  // Bắt đầu ghi âm tin nhắn thoại
  // Sử dụng package record để ghi âm với encoder AAC
  Future<void> _startRecording() async {
    try {
      // Kiểm tra quyền microphone
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Bắt đầu ghi âm với config AAC LC
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc, // AAC Low Complexity
            bitRate: 128000, // 128 kbps
            sampleRate: 44100, // 44.1 kHz
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

  // Dừng ghi âm và hiển thị preview để user nghe lại trước khi gửi
  Future<void> _stopAndSendRecording() async {
    try {
      // Dừng ghi âm và lấy path file
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        // Lấy thời lượng audio bằng just_audio
        final audioPlayer = AudioPlayer();
        await audioPlayer.setFilePath(path);
        final duration = audioPlayer.duration?.inSeconds ?? 0;
        await audioPlayer.dispose();

        // Hiển thị màn hình preview để user nghe lại và quyết định gửi
        final shouldSend = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => VoicePreviewScreen(
              audioFile: File(path),
              duration: duration,
            ),
          ),
        );

        // Nếu user bấm Gửi trong preview
        if (shouldSend == true) {
          // Hiển thị loading snackbar
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

          // Upload file lên Firebase Storage
          final file = File(path);
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('voice_messages')
              .child('${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}.m4a');

          await storageRef.putFile(file);
          final downloadUrl = await storageRef.getDownloadURL();

          // Gửi tin nhắn thoại vào Firestore
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          await chatProvider.sendVoiceMessage(
            widget.matchId,
            downloadUrl,
            duration: duration,
          );

          // Xóa file tạm
          await file.delete();
        } else {
          // User hủy -> xóa file tạm
          await File(path).delete();
        }
      }
    } catch (e) {
      developer.log('Error: $e', name: 'ChatScreen', error: e);
    }
  }

  // Hủy ghi âm (khi user kéo ngón tay ra ngoài)
  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      // Xóa file tạm nếu có
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

  // Gửi ảnh hoặc video
  // Kiểm tra Premium trước khi cho phép gửi media
  void _sendMedia(String localPath, {bool isVideo = false, String? caption}) async {
    // Nếu chưa Premium -> chuyển sang màn hình đăng ký
    if (!isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
      return;
    }

    try {
      // Hiển thị loading overlay trong khi upload
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

      // Upload file lên Firebase Storage
      final file = File(localPath);
      final fileName =
          '${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}${isVideo ? '.mp4' : '.jpg'}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(isVideo ? 'chat_videos' : 'chat_images')
          .child(fileName);

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Gửi tin nhắn media với notification
      await Provider.of<ChatProvider>(context, listen: false).sendMediaWithNotify(
        widget.matchId,
        downloadUrl,
        isVideo: isVideo,
        caption: caption,
        peerUser: widget.peerUser, // Để gửi push notification
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
      
      // AppBar với glassmorphism effect
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
                      // Nút Back với glassmorphism
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

                      // Avatar + Tên user (tap để xem profile)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            // Mở màn hình xem ProfileCard của peer user
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
                              // Avatar với shadow và border
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
                              // Tên user
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

                      // Nút Voice Call và Video Call
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nút gọi thoại
                          _buildGlassButton(
                            icon: Icons.phone_rounded,
                            onPressed: () async {
                              // Request quyền microphone
                              final granted = await Permission.microphone
                                  .request();
                              if (granted.isGranted) {
                                // Tạo document trong collection calls
                                await FirebaseFirestore.instance
                                    .collection('calls')
                                    .doc(widget.matchId)
                                    .set({
                                      'status': 'active',
                                      'callerId': currentUserId,
                                      'receiverId': widget.peerUser.id,
                                      'type': 'voice',
                                      'answered': false,
                                      'startedAt': DateTime.now()
                                          .toIso8601String(),
                                    }, SetOptions(merge: true));
                                
                                // Mở màn hình gọi thoại
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VideoCallScreen(
                                      channelName: widget.matchId,
                                      peerUserId: widget.peerUser.id,
                                      peerUsername: widget.peerUser.username,
                                      peerAvatarUrl: widget.peerUser.avatarUrl,
                                      isVoiceCall: true, // Đánh dấu là voice call
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          // Nút gọi video
                          _buildGlassButton(
                            icon: Icons.videocam_rounded,
                            onPressed: () async {
                              // Request quyền camera và mic
                              final granted =
                                  await _requestCameraAndMicPermissions();
                              if (granted) {
                                // Tạo document trong collection calls
                                await FirebaseFirestore.instance
                                    .collection('calls')
                                    .doc(widget.matchId)
                                    .set({
                                      'status': 'active',
                                      'callerId': currentUserId,
                                      'receiverId': widget.peerUser.id,
                                      'type': 'video',
                                      'answered': false,
                                      'startedAt': DateTime.now()
                                          .toIso8601String(),
                                    }, SetOptions(merge: true));

                                // Mở màn hình gọi video
                                await Navigator.push(
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
          // Background image với overlay gradient
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
              // ListView hiển thị tin nhắn
              Expanded(
                child: chatProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF453A),
                        ),
                      )
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        // Stream tin nhắn real-time từ Firestore
                        stream: chatProvider.messagesStream(
                          widget.matchId,
                          widget.peerUser,
                        ),
                        builder: (context, snapshot) {
                          final messages = snapshot.data ?? [];

                          // Auto scroll xuống tin nhắn mới nhất
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                          
                          // ListView reverse để tin mới nhất ở dưới cùng
                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true, // Scroll từ dưới lên
                            padding: const EdgeInsets.only(
                              top: 110,
                              bottom: 8,
                              left: 8,
                              right: 8,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              // Lấy message từ cuối danh sách
                              final msg = messages[messages.length - 1 - index];
                              final isMe = msg['senderId'] == currentUserId;
                              final avatarUrl = isMe
                                  ? myAvatarUrl
                                  : peerAvatarUrl;
                              
                              // Parse timestamp để hiển thị thời gian
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

                              // Hiển thị bubble tin nhắn với thời gian
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
                                  // Thời gian gửi tin nhắn
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

              // Typing indicator (hiển thị khi peer đang nhập)
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

              // Input box để gửi tin nhắn
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
                        // Nút cộng (+) để gửi ảnh/video
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
                              // Show bottom sheet để chọn ảnh hoặc video
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
                                // Check xem là video hay ảnh
                                final isVideo = pickedFile.path.endsWith('.mp4') ||
                                                pickedFile.path.endsWith('.mov') ||
                                                pickedFile.path.endsWith('.MOV');

                                // Hiển thị màn hình preview trước khi gửi
                                final caption = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MediaPreviewScreen(
                                      file: File(pickedFile.path),
                                      isVideo: isVideo,
                                    ),
                                  ),
                                );

                                // Chỉ gửi nếu user bấm "Gửi" (không back)
                                if (caption != null) {
                                  _sendMedia(pickedFile.path, isVideo: isVideo);
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // TextField nhập tin nhắn
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
                              maxLines: null, // Cho phép nhiều dòng
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
                              // Update typing indicator khi user gõ
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
                        // - Nếu TextField rỗng: hiển thị nút mic, giữ lâu để ghi âm
                        // - Nếu có text: hiển thị nút send, tap để gửi
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, child) {
                            final isEmpty = value.text.trim().isEmpty;
                            return GestureDetector(
                              // Long press để ghi âm (chỉ khi TextField rỗng)
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
                                    // Nếu có text thì gửi tin nhắn
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

  // Widget helper để tạo nút glass (voice call, video call)
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

  // Build bubble tin nhắn
  // Xử lý các loại tin: text, image, video, voice, call
  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    String avatarUrl,
    String timeString,
  ) {
    // Nếu là tin nhắn của đối phương -> hiện avatar bên trái
    if (!isMe) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 2),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              backgroundColor: Colors.deepOrange.withOpacity(0.18),
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 18)
                  : null,
            ),
          ),
          Flexible(child: _buildMessageBubbleContent(msg, isMe, timeString)),
        ],
      );
    } else {
      // Tin nhắn của mình thì không có avatar
      return _buildMessageBubbleContent(msg, isMe, timeString);
    }
  }

// Tách phần nội dung bubble cũ ra hàm riêng để dễ bảo trì
Widget _buildMessageBubbleContent(
  Map<String, dynamic> msg,
  bool isMe,
  String timeString,
) {
  final isCall = msg['type'] == 'call';
  final isVoice = msg['type'] == 'voice';

    // Tin nhắn cuộc gọi (missed, declined, ended, cancelled)
    if (isCall) {
      final callStatus = msg['callStatus'] ?? '';
      String callText;
      IconData callIcon;
      Color callColor;

      // Xác định text, icon và màu theo trạng thái cuộc gọi
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

      // Bubble giữa màn hình cho tin nhắn cuộc gọi
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

    // Tin nhắn thoại
    if (isVoice) {
      final audioUrl = msg['audioUrl'] as String?;
      final duration = msg['duration'] as int? ?? 0;
      final reactions = (msg['reactions'] as List?) ?? [];

      return Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Gesture để react vào tin nhắn (chỉ với tin nhắn của peer)
          GestureDetector(
            onLongPress: !isMe
                ? () async {
                    // Show bottom sheet chọn emoji
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
                    // Double tap để react nhanh bằng ❤️
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
          // Hiển thị reactions nếu có
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

    // Tin nhắn thường (text, image, video)
    final mediaUrl = msg['mediaUrl'] as String?;
    final isVideo = msg['isVideo'] == true;
    final text = msg['text'] ?? '';
    final reactions = (msg['reactions'] as List?) ?? [];

    return GestureDetector(
      // Long press để chọn emoji react
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
      // Double tap để react nhanh bằng ❤️
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
          // Hiển thị media (ảnh hoặc video) nếu có
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
                    // Video player bubble
                    ? VideoPlayerBubble(videoUrl: mediaUrl)
                    // Image bubble
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
          // Hiển thị text nếu có
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
                    // Gradient đỏ cho tin nhắn của mình, trắng mờ cho tin nhắn peer
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

          // Hiển thị reactions nếu có
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

  // Format thời gian hiển thị
  // Nếu trong ngày hôm nay: HH:mm
  // Nếu khác ngày: dd/MM/yyyy
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

// Widget video player bubble
// Hiển thị video với nút play/pause overlay
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
    // Initialize video player từ URL
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
      // Hiển thị loading khi video chưa initialize
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
          // Overlay với nút play/pause
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
                // Nút play chỉ hiển thị khi video không phát
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

// Widget voice message bubble
// Hiển thị waveform và nút play/pause để phát tin nhắn thoại
class _VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int duration; // Thời lượng tính bằng giây
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
  late AudioPlayer _player; // just_audio player
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    // Lắng nghe trạng thái play/pause
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
