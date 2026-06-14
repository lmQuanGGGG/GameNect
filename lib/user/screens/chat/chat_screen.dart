import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'chat_info_screen.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:record/record.dart'; 
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart'; 
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/models/user_model.dart';
import '../call/video_call_screen.dart';
import 'dart:ui';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import '../media/voice_preview_screen.dart';
import '../premium/subscription_screen.dart';
import 'message_bubble.dart';
import '../shared/peer_profile_screen.dart';
import 'chat_input_bar.dart';
import '../../../core/theme/theme_helper.dart';
import '../../../core/utils/cdn_helper.dart';

/// Màn hình chat giữa 2 user đã match
/// Sử dụng các sub-components trong thư mục `chat/` cho UI.
class ChatScreen extends StatefulWidget {
  final String matchId; // ID của match (dùng làm room chat)
  final UserModel peerUser; // Thông tin user đối phương
  final bool showBackButton; // Có hiển thị nút back không
  
  const ChatScreen({
    super.key,
    required this.matchId,
    required this.peerUser,
    this.showBackButton = true,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder(); 
  bool _isRecording = false; 
  String? _recordingPath; 

  bool _showInfoPane = false;
  Map<String, dynamic>? _repliedMessage;

  // Realtime streams initialized once to prevent rebuild lag
  late Stream<List<Map<String, dynamic>>> _messagesStream;
  late Stream<bool> _peerTypingStream;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _messagesStream = chatProvider.messagesStream(widget.matchId, widget.peerUser);
    _peerTypingStream = chatProvider.peerTypingStream(widget.matchId, widget.peerUser.id);

    // Lưu lại matchId hiện tại đang chat để tránh hiện notification trùng lặp
    ChatProvider.currentActiveMatchId = widget.matchId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .set({
              'lastSeen_$userId': FieldValue.serverTimestamp(),
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

    if (cameraStatus.isGranted && micStatus.isGranted) return true;

    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      if (!mounted) return false;

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Cần cấp quyền', style: TextStyle(color: Colors.white)),
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
                child: const Text('Hủy', style: TextStyle(color: Colors.black)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Mở Cài đặt', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      );

      if (result == true) await openAppSettings();
      return false;
    }

    if (cameraStatus.isDenied || micStatus.isDenied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bạn cần cho phép quyền Camera và Microphone để gọi video'),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }

    return false;
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final String path;
        if (kIsWeb) {
          path = '';
        } else {
          final directory = await getTemporaryDirectory();
          path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        if (!kIsWeb) {
          HapticFeedback.lightImpact(); // Hiệu ứng rung nhẹ khi bắt đầu ghi âm
        }
        
        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi ghi âm: $e'), backgroundColor: Colors.black),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        final audioPlayer = AudioPlayer();
        if (kIsWeb) {
          await audioPlayer.setUrl(path);
        } else {
          await audioPlayer.setFilePath(path);
        }
        final duration = audioPlayer.duration?.inSeconds ?? 0;
        await audioPlayer.dispose();

        final shouldSend = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => VoicePreviewScreen(
              audioPath: path,
              duration: duration,
            ),
          ),
        );

        if (shouldSend == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Đang gửi tin nhắn thoại...'),
                ],
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.black87,
            ),
          );

          final storageRef = FirebaseStorage.instance
              .ref()
              .child('voice_messages')
              .child('${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}.m4a');

          if (kIsWeb) {
            final response = await http.get(Uri.parse(path));
            final bytes = response.bodyBytes;
            await storageRef.putData(
              bytes,
              SettableMetadata(
                contentType: 'audio/mp4',
                cacheControl: 'public, max-age=31536000',
              ),
            );
          } else {
            final file = File(path);
            await storageRef.putFile(
              file,
              SettableMetadata(
                contentType: 'audio/mp4',
                cacheControl: 'public, max-age=31536000',
              ),
            );
            await file.delete();
          }
          final downloadUrl = await storageRef.getDownloadURL();

          if (!mounted) return;
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          await chatProvider.sendVoiceMessage(
            widget.matchId,
            downloadUrl,
            duration: duration,
          );
        } else {
          if (!kIsWeb) {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error: $e', name: 'ChatScreen', error: e);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (!kIsWeb && _recordingPath != null) {
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
    final isPremium = context.read<ProfileProvider>().userData?.isPremium == true;
    if (!isPremium) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
      return;
    }

    try {
      OverlayEntry? overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.of(context).padding.top + 100,
          left: MediaQuery.of(context).size.width / 2 - 40,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                  SizedBox(height: 8),
                  Text('Đang gửi...', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),
        ),
      );
      
      Overlay.of(context).insert(overlayEntry);

      final fileName = '${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}${isVideo ? '.mp4' : '.jpg'}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(isVideo ? 'chat_videos' : 'chat_images')
          .child(fileName);

      if (kIsWeb) {
        final response = await http.get(Uri.parse(localPath));
        final bytes = response.bodyBytes;
        await storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: isVideo ? 'video/mp4' : 'image/jpeg',
            cacheControl: 'public, max-age=31536000',
          ),
        );
      } else {
        final file = File(localPath);
        await storageRef.putFile(
          file,
          SettableMetadata(
            contentType: isVideo ? 'video/mp4' : 'image/jpeg',
            cacheControl: 'public, max-age=31536000',
          ),
        );
      }
      final downloadUrl = await storageRef.getDownloadURL();

      if (mounted) {
        await Provider.of<ChatProvider>(context, listen: false).sendMediaWithNotify(
          widget.matchId,
          downloadUrl,
          isVideo: isVideo,
          caption: caption,
          peerUser: widget.peerUser, 
        );
      }

      overlayEntry.remove();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi ${isVideo ? 'video' : 'ảnh'}: $e'),
            backgroundColor: Colors.black,
          ),
        );
      }
    }
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onPressed}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.black, size: 18),
            padding: EdgeInsets.zero,
            onPressed: onPressed,
          ),
        ),
      ),
    );
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
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final myAvatarUrl = chatProvider.currentUser?.avatarUrl ?? '';
    final peerAvatarUrl = widget.peerUser.avatarUrl ?? '';

    final isLargeScreen = MediaQuery.of(context).size.width > 800;

    final chatScaffold = Scaffold(
      backgroundColor: Colors.white,
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
                  stops: const [0.0, 0.6, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: 0.6),
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 0.8),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      if (widget.showBackButton) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.black, width: 0.8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PeerProfileScreen(
                                  peerUser: widget.peerUser,
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
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8, spreadRadius: 2,
                                    ),
                                  ],
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: widget.peerUser.avatarUrl?.isNotEmpty == true
                                      ? cdnImageProvider(widget.peerUser.avatarUrl!)
                                      : null,
                                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                                  child: widget.peerUser.avatarUrl == null
                                      ? const Icon(Icons.person, size: 20, color: Colors.white)
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
                                      style: TextStyle(
                                        color: Colors.black, fontWeight: FontWeight.w600, fontSize: 17,
                                        shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text('Chạm ghé', style: TextStyle(color: context.textSecondaryColor, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildGlassButton(
                            icon: Icons.phone_rounded,
                             onPressed: () async {
                              final bool granted;
                              if (kIsWeb) {
                                granted = true;
                              } else {
                                final status = await Permission.microphone.request();
                                granted = status.isGranted;
                              }
                              if (granted) {
                                await FirebaseFirestore.instance.collection('calls').doc(widget.matchId).set({
                                  'status': 'active',
                                  'callerId': currentUserId,
                                  'receiverId': widget.peerUser.id,
                                  'type': 'voice',
                                  'answered': false,
                                  'startedAt': DateTime.now().toIso8601String(),
                                }, SetOptions(merge: true));
                                
                                if (!context.mounted) return;
                                await Navigator.push(
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
                              final bool granted;
                              if (kIsWeb) {
                                granted = true;
                              } else {
                                granted = await _requestCameraAndMicPermissions();
                              }
                              if (granted) {
                                await FirebaseFirestore.instance.collection('calls').doc(widget.matchId).set({
                                  'status': 'active',
                                  'callerId': currentUserId,
                                  'receiverId': widget.peerUser.id,
                                  'type': 'video',
                                  'answered': false,
                                  'startedAt': DateTime.now().toIso8601String(),
                                }, SetOptions(merge: true));

                                if (!context.mounted) return;
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
                          const SizedBox(width: 8),
                          _buildGlassButton(
                            icon: Icons.info_outline,
                            onPressed: () {
                              if (isLargeScreen) {
                                setState(() {
                                  _showInfoPane = !_showInfoPane;
                                });
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatInfoScreen(
                                      matchId: widget.matchId,
                                      peerName: widget.peerUser.username,
                                      myAvatarUrl: myAvatarUrl,
                                      peerAvatarUrl: peerAvatarUrl,
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
          // ── Nền tối chủ đạo ──
          Positioned.fill(
            child: Container(color: Colors.white),
          ),
          
          // ── Orb Phát Sáng Cam trên cùng bên trái ──
          Positioned(
            top: 50, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          
          // ── Orb Phát Sáng Đỏ Cam dưới cùng bên phải ──
          Positioned(
            bottom: 100, right: -80,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 120,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.6),
                      Colors.white.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _messagesStream,
                  initialData: chatProvider.getPreloadedMessages(widget.matchId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      developer.log('ChatScreen MessagesStream error: ${snapshot.error}', name: 'ChatScreen', error: snapshot.error);
                      return Center(
                        child: Text(
                          'Đã xảy ra lỗi tải tin nhắn: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Colors.black));
                    }
                    
                    final messages = snapshot.data ?? [];
                          
                    return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.only(top: 110, bottom: 100, left: 8, right: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[messages.length - 1 - index];
                              final isMe = msg['senderId'] == currentUserId;
                              final avatarUrl = isMe ? myAvatarUrl : peerAvatarUrl;
                              
                              final timestamp = msg['timestamp'];
                              String timeString = '';
                              if (timestamp != null) {
                                if (timestamp is DateTime) {
                                  timeString = _formatTime(timestamp);
                                } else if (timestamp is String) {
                                  timeString = _formatTime(DateTime.tryParse(timestamp) ?? DateTime.now());
                                } else if (timestamp is Timestamp) {
                                  timeString = _formatTime(timestamp.toDate());
                                }
                              }

                              return Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  MessageBubbleWidget(
                                    key: ValueKey(msg['id']),
                                    msg: msg,
                                    isMe: isMe,
                                    avatarUrl: avatarUrl,
                                    timeString: timeString,
                                    matchId: widget.matchId,
                                    onReply: () {
                                      setState(() {
                                        _repliedMessage = msg;
                                      });
                                      _focusNode.requestFocus();
                                    },
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: isMe ? 0 : 44,
                                      right: isMe ? 20 : 0,
                                      top: 2, bottom: 8,
                                    ),
                                    child: Text(
                                      timeString,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.textTertiaryColor,
                                        fontWeight: FontWeight.w500,
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

              StreamBuilder<bool>(
                stream: _peerTypingStream,
                builder: (context, snapshot) {
                  final isPeerTyping = snapshot.data ?? false;
                  if (!isPeerTyping) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.textSecondaryColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.peerUser.username} đang nhập...',
                          style: TextStyle(
                            color: context.textSecondaryColor,
                            fontSize: 13, fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              if (_repliedMessage != null)
                Container(
                  margin: EdgeInsets.only(
                    right: isLargeScreen ? (_showInfoPane ? 0.0 : 80.0) : 0.0,
                    left: 0.0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: const Border(top: BorderSide(color: Colors.black, width: 2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, color: Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đang trả lời ${_repliedMessage!['senderId'] == currentUserId ? 'chính bạn' : widget.peerUser.username}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _repliedMessage!['text'] ?? (_repliedMessage!['type'] == 'media' ? '[Hình ảnh/Video]' : '[Tin nhắn]'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _repliedMessage = null),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: EdgeInsets.only(
                  bottom: isLargeScreen ? 90.0 : 0.0,
                  right: isLargeScreen ? (_showInfoPane ? 0.0 : 80.0) : 0.0,
                  left: 0.0,
                ),
                child: ChatInputBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  isRecording: _isRecording,
                  matchId: widget.matchId,
                  peerUserId: widget.peerUser.id,
                  onStartRecording: _startRecording,
                  onStopRecording: _stopAndSendRecording,
                  onCancelRecording: _cancelRecording,
                  onSendMedia: _sendMedia,
                  onSendMessage: (text) {
                    chatProvider.sendMessage(
                      widget.matchId, 
                      text, 
                      peerUser: widget.peerUser,
                      repliedMessage: _repliedMessage,
                    );
                    if (_repliedMessage != null) {
                      setState(() => _repliedMessage = null);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Row(
      children: [
        Expanded(child: chatScaffold),
        if (isLargeScreen && _showInfoPane) ...[
          Container(width: 2, color: Colors.black), // Neo divider
          SizedBox(
            width: 350,
            child: ChatInfoScreen(
              matchId: widget.matchId,
              peerName: widget.peerUser.username,
              myAvatarUrl: myAvatarUrl,
              peerAvatarUrl: peerAvatarUrl,
              onClose: () {
                setState(() {
                  _showInfoPane = false;
                });
              },
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    ChatProvider.currentActiveMatchId = null; // Clear khi thoát màn hình chat
    super.dispose();
  }
}
