import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/services/firestore_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Lấy App ID của Agora từ file .env hoặc Dart defines
String get agoraAppId {
  const envAppId = String.fromEnvironment('AGORA_APP_ID', defaultValue: '');
  if (envAppId.isNotEmpty) return envAppId.trim();
  return (dotenv.env['AGORA_APP_ID'] ?? '').trim();
}

// Màn hình video call và voice call sử dụng Agora RTC
// Hỗ trợ cả video call và voice call (chỉ audio)
// Tự động lưu lịch sử cuộc gọi vào Firestore
class VideoCallScreen extends StatefulWidget {
  final String channelName; // Tên kênh Agora (thường dùng matchId)
  final String peerUserId; // ID của người được gọi
  final String peerUsername; // Tên của người được gọi
  final String? peerAvatarUrl; // Avatar của người được gọi
  final bool isVoiceCall; // True nếu là cuộc gọi thoại, false nếu là video call
  
  static bool isCallActive = false;
  
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
  late final Stream<DocumentSnapshot> _callStream;
  DateTime? _callStartTime; // Thời gian bắt đầu cuộc gọi
  bool _isMuted = false; // Trạng thái tắt/bật mic
  bool _isCameraOff = false; // Trạng thái tắt/bật camera
  bool _isFrontCamera = true; // Trạng thái camera trước/sau
  Timer? _callTimeoutTimer; // Timer để timeout cuộc gọi sau 60s

  // Subscription để lắng nghe trạng thái cuộc gọi từ Firestore
  StreamSubscription<DocumentSnapshot>? _callStatusSubscription;

  // Flag để track xem cuộc gọi có được trả lời không
  bool _callAnswered = false;

  // Real-time Timer
  Timer? _activeCallTimer;
  int _activeDuration = 0;
  
  double _remoteVideoAspectRatio = 9 / 16; // Tỷ lệ khung hình remote

  // Draggable PiP Coordinates
  double _localViewX = 24.0;
  double _localViewY = 140.0;

  void _startActiveTimer() {
    if (_activeCallTimer != null) return;
    _activeCallTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _activeDuration++;
        });
      }
    });
  }

  String _formatActiveDuration() {
    final m = (_activeDuration ~/ 60).toString().padLeft(2, '0');
    final s = (_activeDuration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    VideoCallScreen.isCallActive = true;
    _callStream = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.channelName)
        .snapshots();
    try {
      WakelockPlus.enable().catchError((e) {
        debugPrint('WakelockPlus enable async error: $e');
      });
    } catch (e) {
      debugPrint('WakelockPlus enable error: $e');
    }
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
      // Yêu cầu quyền truy cập camera và microphone (Chỉ dành cho Mobile)
      if (!kIsWeb) {
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
      }

      // Tạo Agora RTC Engine instance
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: agoraAppId));
      
      // Nếu là voice call thì chỉ enable audio, còn không thì enable video
      if (widget.isVoiceCall) {
        await _engine!.enableAudio();
      } else {
        await _engine!.enableVideo();
        // Ép lật video gửi đi cho camera trước (để người nhận nhìn thấy ảnh lật như soi gương giống mình)
        await _engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 1280, height: 720),
            frameRate: 30,
            orientationMode: OrientationMode.orientationModeAdaptive,
            mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
          ),
        );
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
                _startActiveTimer(); // Bắt đầu đếm thời gian thực
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
          // Lấy tỷ lệ video remote
          onVideoSizeChanged: (connection, sourceType, uid, width, height, rotation) {
            if (uid != 0 && width > 0 && height > 0) {
              double newRatio = width / height;
              // Nếu video bị xoay 90 hoặc 270 độ (thường gặp trên thiết bị thật cầm dọc)
              if (rotation == 90 || rotation == 270) {
                newRatio = height / width;
              }
              
              if (mounted && (_remoteVideoAspectRatio - newRatio).abs() > 0.01) {
                setState(() {
                  _remoteVideoAspectRatio = newRatio;
                });
              }
            }
          },
        ),
      );

      // Join vào channel với channelName
      await _engine!.joinChannel(
        token: '', // Token để xác thực (để trống nếu không dùng)
        channelId: widget.channelName,
        uid: 0, // UID = 0 thì Agora tự động generate
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster, // Broadcaster để có thể gửi stream
          publishCameraTrack: !widget.isVoiceCall,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: !widget.isVoiceCall,
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
  void _switchCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _engine?.switchCamera();
    
    // Cập nhật lại chế độ lật video tùy theo đang dùng cam trước hay sau
    await _engine?.setVideoEncoderConfiguration(
      VideoEncoderConfiguration(
        dimensions: const VideoDimensions(width: 1280, height: 720),
        frameRate: 30,
        orientationMode: OrientationMode.orientationModeAdaptive,
        mirrorMode: _isFrontCamera
            ? VideoMirrorModeType.videoMirrorModeEnabled
            : VideoMirrorModeType.videoMirrorModeDisabled,
      ),
    );
  }

  @override
  void dispose() {
    VideoCallScreen.isCallActive = false;
    try {
      WakelockPlus.disable().catchError((e) {
        debugPrint('WakelockPlus disable async error: $e');
      });
    } catch (e) {
      debugPrint('WakelockPlus disable error: $e');
    }
    _activeCallTimer?.cancel();
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
    _activeCallTimer?.cancel();
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
    return StreamBuilder<DocumentSnapshot>(
      stream: _callStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.get('status') == 'ended') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) Navigator.pop(context);
          });
        }

        if (_engine == null || !_isInitialized) {
          return const Scaffold(
            backgroundColor: Color(0xFF101012),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6E40)),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF101012),
          body: Stack(
            children: [
              // ================= BACKGROUND =================
              if (widget.isVoiceCall) ...[
                // Nền đen chủ đạo
                Positioned.fill(child: Container(color: const Color(0xFF101012))),
                // Orbs phát sáng ảo diệu cho Voice Call
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.2,
                  left: -50,
                  child: Container(
                    width: 300, height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF6E40).withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.15), blurRadius: 100, spreadRadius: 40),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.2,
                  right: -80,
                  child: Container(
                    width: 350, height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFBF360C).withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFBF360C).withValues(alpha: 0.15), blurRadius: 120, spreadRadius: 50),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ] else ...[
                // Video Remote Full Màn Hình
                Positioned.fill(
                  child: _remoteUid != null
                      ? AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(
                              uid: _remoteUid,
                              renderMode: (MediaQuery.of(context).size.width / MediaQuery.of(context).size.height > 1.0) == (_remoteVideoAspectRatio > 1.0)
                                  ? RenderModeType.renderModeHidden
                                  : RenderModeType.renderModeFit,
                            ),
                            connection: RtcConnection(channelId: widget.channelName),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF101012),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person, size: 80, color: Colors.white24),
                                const SizedBox(height: 16),
                                Text('Đang kết nối tới ${widget.peerUsername}...', style: const TextStyle(color: Colors.white54, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                ),
              ],

              // ================= GRADIENT OVERLAYS =================
              Positioned.fill(
                child: IgnorePointer(
                  child: Column(
                    children: [
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.black.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.black.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ================= HEADER: INFO & TIMER =================
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0, right: 0,
                child: Column(
                  children: [
                    Text(
                      widget.peerUsername,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2))],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _callAnswered ? _formatActiveDuration() : 'Đang đổ chuông...',
                      style: TextStyle(
                        color: _callAnswered ? const Color(0xFFFF6E40) : Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        shadows: const [Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 1))],
                      ),
                    ),
                  ],
                ),
              ),

              // ================= VOICE CALL AVATAR (Pulsating) =================
              if (widget.isVoiceCall)
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: _callAnswered ? 1.05 : 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (_callAnswered)
                                BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 10),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 80,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            backgroundImage: widget.peerAvatarUrl?.isNotEmpty == true
                                ? NetworkImage(widget.peerAvatarUrl!)
                                : null,
                            child: widget.peerAvatarUrl?.isEmpty ?? true
                                ? const Icon(Icons.person, size: 60, color: Colors.white)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ================= LOCAL VIDEO (Draggable PiP) =================
              if (!widget.isVoiceCall)
                Positioned(
                  bottom: _localViewY,
                  right: _localViewX,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        // Kéo thả và giới hạn trong khung hình
                        final screenW = MediaQuery.of(context).size.width;
                        final screenH = MediaQuery.of(context).size.height;
                        
                        _localViewX -= details.delta.dx;
                        _localViewY -= details.delta.dy;
                        
                        // Clamp để không văng ra ngoài
                        _localViewX = _localViewX.clamp(16.0, screenW - 136.0); // 120 = width + 16 padding
                        _localViewY = _localViewY.clamp(130.0, screenH - 180.0); // Chừa chỗ cho Control Bar dưới
                      });
                    },
                    child: Container(
                      width: 110, height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14.5),
                        child: _isCameraOff
                            ? BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  child: const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 36)),
                                ),
                              )
                            : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                aspectRatio: 9 / 16,
                                child: AgoraVideoView(
                                  controller: VideoViewController(
                                    rtcEngine: _engine!,
                                    canvas: const VideoCanvas(
                                      uid: 0,
                                      renderMode: RenderModeType.renderModeFit,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),

              // ================= LIQUID GLASS CONTROL BAR =================
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 24, right: 24,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGlassButton(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            isActive: !_isMuted,
                            onTap: _toggleMute,
                          ),
                          _buildGlassButton(
                            icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                            isActive: !_isCameraOff,
                            onTap: _toggleCamera,
                          ),
                          _buildGlassButton(
                            icon: Icons.cameraswitch_rounded,
                            isActive: true,
                            onTap: _switchCamera,
                          ),
                          // Nút End Call đặc biệt (Đỏ)
                          GestureDetector(
                            onTap: _leaveChannel,
                            child: Container(
                              width: 54, height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFF3B30),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFFFF3B30).withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Nút bấm hiệu ứng kính mờ bên trong Control Bar
  Widget _buildGlassButton({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54, height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.3),
        ),
        child: Icon(icon, color: isActive ? Colors.white : const Color(0xFF101012), size: 26),
      ),
    );
  }
}