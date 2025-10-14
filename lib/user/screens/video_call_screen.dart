import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/providers/chat_provider.dart';

final agoraAppId = dotenv.env['AGORA_APP_ID'] ?? '';

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String peerUserId;
  final String peerUsername;  // THÊM
  final String? peerAvatarUrl; // THÊM
  
  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.peerUserId,
    required this.peerUsername,  // THÊM
    this.peerAvatarUrl,          // THÊM
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _isInitialized = false;
  bool _isJoined = false;
  late DateTime _callStartTime;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  Timer? _callTimeoutTimer;
  bool _callAnswered = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
    _callStartTime = DateTime.now();
    _callTimeoutTimer = Timer(const Duration(seconds: 60), () {
      if (!_callAnswered && mounted) {
        Provider.of<ChatProvider>(context, listen: false)
            .endCall(widget.channelName, 0, missed: true);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không ai phản hồi, cuộc gọi đã kết thúc')),
        );
      }
    });
  }

  Future<void> _initAgora() async {
    try {
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

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: agoraAppId));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            debugPrint('Local user joined: ${connection.channelId}');
            if (mounted) {
              setState(() {
                _isJoined = true;
              });
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            debugPrint('Remote user joined: $remoteUid');
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
                _callAnswered = true;
              });
            }
          },
          onUserOffline: (connection, remoteUid, reason) {
            debugPrint('Remote user offline: $remoteUid');
            if (mounted) {
              setState(() {
                _remoteUid = null;
              });
            }
          },
          onError: (err, msg) {
            debugPrint('Agora Error: $err - $msg');
          },
        ),
      );

      await _engine!.enableVideo();
      await _engine!.startPreview();
      
      await _engine!.joinChannel(
        token: '',
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
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

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    _engine?.muteLocalVideoStream(_isCameraOff);
    if (_isCameraOff) {
      _engine?.stopPreview();
    } else {
      _engine?.startPreview();
    }
  }

  void _switchCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    _engine?.switchCamera();
  }

  @override
  void dispose() {
    _callTimeoutTimer?.cancel();
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (e) {
      debugPrint('Error disposing engine: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('calls').doc(widget.channelName).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.get('status') == 'ended') {
          // Thoát màn hình gọi nếu trạng thái là ended
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) Navigator.pop(context);
          });
        }

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
              // Video nền hoặc nền gradient
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
                                'Đang chờ ${widget.peerUsername} vào phòng...', // SỬA
                                style: const TextStyle(color: Colors.white70, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              // Avatar và tên đối phương
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white24,
                      backgroundImage: widget.peerAvatarUrl != null && widget.peerAvatarUrl!.isNotEmpty
                          ? NetworkImage(widget.peerAvatarUrl!) // SỬA
                          : null,
                      child: widget.peerAvatarUrl == null || widget.peerAvatarUrl!.isEmpty
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.peerUsername, // SỬA
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Video nhỏ của mình
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
              // Nút điều khiển IG style
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Nút kết thúc gọi
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      icon: const Icon(Icons.call_end, color: Colors.white),
                      label: const Text('Kết thúc', style: TextStyle(fontSize: 18, color: Colors.white)),
                      onPressed: () async {
                        final callDuration = DateTime.now().difference(_callStartTime);

                        if (_remoteUid == null) {
                          await Provider.of<ChatProvider>(context, listen: false)
                              .endCall(widget.channelName, 0, missed: true);
                        } else {
                          await Provider.of<ChatProvider>(context, listen: false)
                              .endCall(widget.channelName, callDuration.inSeconds, missed: false);
                        }

                        // Cập nhật trạng thái cuộc gọi Firestore
                        await FirebaseFirestore.instance.collection('calls').doc(widget.channelName).set({
                          'status': 'ended',
                          'endedAt': DateTime.now().toIso8601String(),
                        }, SetOptions(merge: true));

                        Navigator.pop(context, true);
                      },
                    ),
                    const SizedBox(height: 18),
                    // Dãy nút IG style
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