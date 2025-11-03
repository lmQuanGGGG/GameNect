import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/services/firestore_service.dart';

// Lấy App ID của Agora từ file .env
final agoraAppId = dotenv.env['AGORA_APP_ID'] ?? '';

// Màn hình video call và voice call sử dụng Agora RTC
// Hỗ trợ cả video call và voice call (chỉ audio)
// Tự động lưu lịch sử cuộc gọi vào Firestore
class VideoCallScreen extends StatefulWidget {
  final String channelName; // Tên kênh Agora (thường dùng matchId)
  final String peerUserId; // ID của người được gọi
  final String peerUsername; // Tên của người được gọi
  final String? peerAvatarUrl; // Avatar của người được gọi
  final bool isVoiceCall; // True nếu là cuộc gọi thoại, false nếu là video call
  
  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.peerUserId,
    required this.peerUsername,
    this.peerAvatarUrl,
    this.isVoiceCall = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RtcEngine? _engine; // Agora RTC Engine instance
  int? _remoteUid; // UID của người dùng remote (người được gọi)
  bool _isInitialized = false; // Trạng thái engine đã khởi tạo chưa
  bool _isJoined = false; // Trạng thái đã join channel chưa
  DateTime? _callStartTime; // Thời gian bắt đầu cuộc gọi
  bool _isMuted = false; // Trạng thái tắt/bật mic
  bool _isCameraOff = false; // Trạng thái tắt/bật camera
  bool _isFrontCamera = true; // Trạng thái camera trước/sau
  Timer? _callTimeoutTimer; // Timer để timeout cuộc gọi sau 60s

  // Subscription để lắng nghe trạng thái cuộc gọi từ Firestore
  StreamSubscription<DocumentSnapshot>? _callStatusSubscription;

  // Flag để track xem cuộc gọi có được trả lời không
  bool _callAnswered = false;

  @override
  void initState() {
    super.initState();
    _callStartTime = DateTime.now(); // Lưu thời gian bắt đầu cuộc gọi

    // Lắng nghe realtime trạng thái cuộc gọi từ Firestore
    _callStatusSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.channelName)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data != null) {
        // Nếu cuộc gọi được trả lời (accepted), set flag
        if (data['answered'] == true || data['status'] == 'accepted') {
          _callAnswered = true;
        }

        // Nếu bị từ chối (declined), tự động thoát màn hình
        if (data['status'] == 'declined' && mounted) {
          _callTimeoutTimer?.cancel();
          _callStatusSubscription?.cancel();
          _engine?.leaveChannel();
          _engine?.release();
          Navigator.of(context).pop(true);
        }
      }
    });

    // Timeout sau 60s - nếu không trả lời thì là cuộc gọi nhỡ
    _callTimeoutTimer = Timer(const Duration(seconds: 60), () async {
      if (!_callAnswered && mounted) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null) {
          // Lưu tin nhắn "Cuộc gọi nhỡ" vào chat
          await FirestoreService().addCallMessage(
            matchId: widget.channelName,
            senderId: currentUserId,
            duration: 0,
            missed: true, // Đánh dấu là cuộc gọi nhỡ
          );
        }

        // Cập nhật trạng thái cuộc gọi trong Firestore
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.channelName)
            .set({
              'status': 'missed',
              'endedAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));

        // Cleanup và thoát màn hình
        await _engine?.leaveChannel();
        await _engine?.release();
        Navigator.pop(context, true);
      }
    });

    // Khởi tạo Agora engine
    _initAgora();
  }

  // Khởi tạo Agora RTC Engine
  Future<void> _initAgora() async {
    try {
      // Yêu cầu quyền truy cập camera và microphone
      final statuses = await [Permission.microphone, Permission.camera].request();

      if (statuses[Permission.microphone] != PermissionStatus.granted ||
          statuses[Permission.camera] != PermissionStatus.granted) {
        debugPrint('Permission denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cần cấp quyền camera và mic')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Tạo Agora RTC Engine instance
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: agoraAppId));
      
      // Nếu là voice call thì chỉ enable audio, còn không thì enable video
      if (widget.isVoiceCall) {
        await _engine!.enableAudio();
      } else {
        await _engine!.enableVideo();
        await _engine!.startPreview(); // Bật preview video của mình
      }

      // Đăng ký event handler để lắng nghe các sự kiện từ Agora
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          // Khi join channel thành công
          onJoinChannelSuccess: (connection, elapsed) {
            debugPrint('Local user joined: ${connection.channelId}');
            if (mounted) {
              setState(() {
                _isJoined = true;
              });
            }
          },
          // Khi có user remote join vào
          onUserJoined: (connection, remoteUid, elapsed) {
            debugPrint('Remote user joined: $remoteUid');
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
                _callAnswered = true; // Đánh dấu cuộc gọi đã được trả lời
              });
            }
          },
          // Khi user remote offline (rời kênh)
          onUserOffline: (connection, remoteUid, reason) {
            debugPrint('Remote user offline: $remoteUid');
            if (mounted) {
              setState(() {
                _remoteUid = null;
              });
            }
          },
          // Khi có lỗi xảy ra
          onError: (err, msg) {
            debugPrint('Agora Error: $err - $msg');
          },
        ),
      );

      // Join vào channel với channelName
      await _engine!.joinChannel(
        token: '', // Token để xác thực (để trống nếu không dùng)
        channelId: widget.channelName,
        uid: 0, // UID = 0 thì Agora tự động generate
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster, // Broadcaster để có thể gửi stream
        ),
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khởi tạo video call: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  // Toggle tắt/bật mic
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine?.muteLocalAudioStream(_isMuted);
  }

  // Toggle tắt/bật camera
  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    _engine?.muteLocalVideoStream(_isCameraOff);
    if (_isCameraOff) {
      _engine?.stopPreview(); // Dừng preview khi tắt camera
    } else {
      _engine?.startPreview(); // Bật preview khi bật camera
    }
  }

  // Đổi camera trước/sau
  void _switchCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    _engine?.switchCamera();
  }

  @override
  void dispose() {
    _callStatusSubscription?.cancel(); // Hủy subscription Firestore
    _callTimeoutTimer?.cancel(); // Hủy timer timeout
    _dispose(); // Cleanup Agora engine
    super.dispose();
  }

  // Cleanup Agora engine
  Future<void> _dispose() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (e) {
      debugPrint('Error disposing engine: $e');
    }
  }

  // Kết thúc cuộc gọi và lưu lịch sử
  Future<void> _leaveChannel() async {
    _callTimeoutTimer?.cancel();
    _callStatusSubscription?.cancel();
    
    // Tính toán thời lượng cuộc gọi
    if (_callStartTime != null) {
      final duration = DateTime.now().difference(_callStartTime!).inSeconds;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (_callAnswered) {
        // Trường hợp đã nghe máy: Lưu tin nhắn "Đã gọi X phút Y giây"
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.channelName)
            .set({
              'status': 'ended',
              'endedAt': DateTime.now().toIso8601String(),
              'duration': duration,
            }, SetOptions(merge: true));
        
        if (currentUserId != null) {
          await FirestoreService().addCallMessage(
            matchId: widget.channelName,
            senderId: currentUserId,
            duration: duration,
            missed: false,
            declined: false,
          );
        }
      } else {
        // Trường hợp chưa nghe máy: Lưu tin nhắn "Đã hủy"
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.channelName)
            .set({
              'status': 'cancelled',
              'endedAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
        
        if (currentUserId != null) {
          await FirestoreService().addCallMessage(
            matchId: widget.channelName,
            senderId: currentUserId,
            duration: 0,
            missed: false,
            declined: false,
            cancelled: true, // Đánh dấu là cuộc gọi bị hủy
          );
        }
      }
    }

    // Cleanup Agora engine và thoát màn hình
    await _engine?.leaveChannel();
    await _engine?.release();

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  // Format thời lượng thành "X phút Y giây"
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes phút $secs giây';
    }
    return '$secs giây';
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe trạng thái cuộc gọi từ Firestore để tự động thoát khi ended
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('calls').doc(widget.channelName).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.get('status') == 'ended') {
          // Thoát màn hình gọi nếu trạng thái là ended
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) Navigator.pop(context);
          });
        }

        // Hiển thị loading khi đang khởi tạo engine
        if (_engine == null || !_isInitialized) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  const Text('Đang kết nối...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // UI cho voice call: hiển thị avatar và tên
              if (widget.isVoiceCall)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white24,
                        backgroundImage: widget.peerAvatarUrl != null && widget.peerAvatarUrl!.isNotEmpty
                            ? NetworkImage(widget.peerAvatarUrl!)
                            : null,
                        child: widget.peerAvatarUrl == null || widget.peerAvatarUrl!.isEmpty
                            ? const Icon(Icons.person, size: 60, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.peerUsername,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text('Đang gọi thoại...', style: TextStyle(color: Colors.white70, fontSize: 18)),
                    ],
                  ),
                )
              // UI cho video call: hiển thị video remote và local
              else ...[
                // Video remote chiếm toàn màn hình
                Positioned.fill(
                  child: _remoteUid != null
                    ? AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _engine!,
                          canvas: VideoCanvas(uid: _remoteUid),
                          connection: RtcConnection(channelId: widget.channelName),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF232526), Color(0xFF414345)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person, size: 100, color: Colors.white54),
                              const SizedBox(height: 16),
                              Text(
                                'Đang chờ ${widget.peerUsername} vào phòng...',
                                style: const TextStyle(color: Colors.white70, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                ),
                // Video local (của mình) ở góc dưới bên phải
                Positioned(
                  bottom: 100,
                  right: 20,
                  child: Container(
                    width: 100,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _isCameraOff
                          ? Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Icon(Icons.videocam_off, color: Colors.white, size: 40),
                              ),
                            )
                          : AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine!,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
              // Các nút điều khiển ở dưới cùng (Instagram style)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Nút kết thúc gọi màu đỏ
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      icon: const Icon(Icons.call_end, color: Colors.white),
                      label: const Text('Kết thúc', style: TextStyle(fontSize: 18, color: Colors.white)),
                      onPressed: () async {
                        // Kết thúc cuộc gọi và lưu lịch sử
                        await _leaveChannel();
                      },
                    ),
                    const SizedBox(height: 18),
                    // Dãy nút điều khiển: Mute, Camera, Switch Camera
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCircleButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          color: _isMuted ? Colors.red : Colors.white,
                          onTap: _toggleMute,
                        ),
                        const SizedBox(width: 28),
                        _buildCircleButton(
                          icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                          color: _isCameraOff ? Colors.red : Colors.white,
                          onTap: _toggleCamera,
                        ),
                        const SizedBox(width: 28),
                        _buildCircleButton(
                          icon: Icons.cameraswitch,
                          color: Colors.white,
                          onTap: _switchCamera,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget helper để tạo nút tròn điều khiển
  Widget _buildCircleButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}