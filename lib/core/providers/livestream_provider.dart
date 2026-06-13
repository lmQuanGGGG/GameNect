// lib/core/providers/livestream_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/livestream_model.dart';
import '../services/firestore_service.dart';
import '../../user/screens/live/floating_live_window.dart';

/// LivestreamProvider — Quản lý state livestream cho cả streamer lẫn viewer.
/// Theo Plan Task 5.2.
class LivestreamProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  List<LivestreamModel> _liveStreams = [];
  LivestreamModel? _currentStream;
  List<Map<String, dynamic>> _messages = [];
  int _viewerCount = 0;
  String? _error;
  int _myCoins = 0;
  bool _isLandscapeVideo = false;
  double _remoteVideoAspectRatio = 9 / 16; // Lưu tỷ lệ khung hình thực tế

  // Agora
  RtcEngine? _engine;
  bool _localVideoOn = false;
  int? _remoteUid; // uid của broadcaster khi viewer join
  StreamSubscription<List<Map<String, dynamic>>>? _messageSub;
  StreamSubscription<List<LivestreamModel>>? _streamsSub;

  // PiP & Screen Sharing state
  bool _isMinimized = false;
  bool _isScreenSharing = false;
  bool _isSystemPiP = false;
  OverlayEntry? _overlayEntry;
  String? _joinedChannelId;
  StreamSubscription? _streamDocSub;

  // Viewer-side: broadcaster đang share màn hình hay không (phát hiện qua Agora sourceType)
  bool _remoteIsScreenSharing = false;

  static const _pipChannel = MethodChannel('com.qco.gamenect/pip');

  LivestreamProvider() {
    _initPiPChannel();
  }

  void _initPiPChannel() {
    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPModeChanged') {
        final isInPiP = call.arguments as bool? ?? false;
        _isSystemPiP = isInPiP;
        notifyListeners();
        developer.log('onPiPModeChanged: $isInPiP', name: 'LivestreamProvider');
      }
    });
  }

  Future<void> _updateNativeLiveState(bool isActive) async {
    try {
      await _pipChannel.invokeMethod('setIsLiveActive', {'isActive': isActive});
    } catch (e) {
      developer.log(
        'Error updating native live state: $e',
        name: 'LivestreamProvider',
      );
    }
  }

  // ─── Getters ──────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  List<LivestreamModel> get liveStreams => List.unmodifiable(_liveStreams);
  LivestreamModel? get currentStream => _currentStream;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  int get viewerCount => _viewerCount;
  String? get error => _error;
  bool get isStreaming => _currentStream?.status == 'live';
  RtcEngine? get engine => _engine;
  bool get localVideoOn => _localVideoOn;
  int? get remoteUid => _remoteUid;
  int get myCoins => _myCoins;
  bool get isLandscapeVideo => _isLandscapeVideo;
  double get remoteVideoAspectRatio => _remoteVideoAspectRatio;

  bool get isMinimized => _isMinimized;
  bool get isScreenSharing => _isScreenSharing;
  bool get isSystemPiP => _isSystemPiP;
  String? get joinedChannelId => _joinedChannelId;
  bool get remoteIsScreenSharing => _remoteIsScreenSharing;

  // ─── AGORA SETUP ──────────────────────────────────────────────────────────

  /// Khởi tạo Agora engine (gọi 1 lần trước khi join/start stream).
  Future<void> _initEngine() async {
    if (_engine != null) return;
    try {
      final envAppId = const String.fromEnvironment(
        'AGORA_APP_ID',
        defaultValue: '',
      );
      final appId = envAppId.isNotEmpty
          ? envAppId.trim()
          : (dotenv.env['AGORA_APP_ID'] ?? '').trim();
      if (appId.isEmpty) {
        developer.log('AGORA_APP_ID is missing!', name: 'LivestreamProvider');
        return;
      }
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));
      developer.log('Agora engine initialized', name: 'LivestreamProvider');
    } catch (e) {
      developer.log('_initEngine error: $e', name: 'LivestreamProvider');
    }
  }

  // ─── MENTOR SIDE ──────────────────────────────────────────────────────────

  /// Mentor bắt đầu livestream.
  /// Trả về streamId để navigate sang LiveStreamScreen.
  Future<String?> startStream({
    required String mentorId,
    required String mentorUsername,
    required String mentorAvatarUrl,
    required String title,
    required String game,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Tạo Firestore document trước để lấy streamId
      final stream = LivestreamModel(
        id: '',
        mentorId: mentorId,
        mentorUsername: mentorUsername,
        mentorAvatarUrl: mentorAvatarUrl,
        title: title,
        game: game,
        agoraChannel: '',
        status: 'live',
        viewerCount: 0,
        startedAt: DateTime.now(),
      );

      final streamId = await _service.createLivestream(stream);

      // Setup Agora cho broadcaster
      await _initEngine();
      if (_engine != null) {
        await _engine!.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster,
        );
        await _engine!.enableVideo();
        // Adaptive orientation: khi device xoay ngang, Agora tự encode đúng orientation
        await _engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 1920, height: 1080),
            frameRate: 30, // Camera 30fps là quá mượt và chuẩn điện ảnh
            orientationMode: OrientationMode.orientationModeAdaptive,
            degradationPreference: DegradationPreference.maintainQuality,
          ),
        );
        await _engine!.startPreview();
        _engine!.registerEventHandler(
          RtcEngineEventHandler(
            onUserJoined: (connection, uid, elapsed) {
              _viewerCount++;
              _service.updateViewerCount(streamId, _viewerCount);
              notifyListeners();
            },
            onUserOffline: (connection, uid, reason) {
              if (_viewerCount > 0) _viewerCount--;
              _service.updateViewerCount(streamId, _viewerCount);
              notifyListeners();
            },
            onError: (code, msg) {
              developer.log(
                'Agora error: $code $msg',
                name: 'LivestreamProvider',
              );
            },
            onVideoSizeChanged:
                (connection, sourceType, uid, width, height, rotation) {
                  bool isLandscape = width > height;
                  if (rotation == 90 || rotation == 270)
                    isLandscape = !isLandscape;
                  if (_isLandscapeVideo != isLandscape) {
                    _isLandscapeVideo = isLandscape;
                    notifyListeners();
                  }
                },
          ),
        );
        await _engine!.joinChannel(
          token: '',
          channelId: streamId,
          uid: 0,
          options: const ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishCameraTrack: true,
            publishMicrophoneTrack: true,
          ),
        );
        _localVideoOn = true;
      }

      // Lấy stream vừa tạo để set currentStream
      _currentStream = stream.copyWith(id: streamId, agoraChannel: streamId);

      // Bắt đầu listen messages
      listenToMessages(streamId);

      _joinedChannelId = streamId;
      _updateNativeLiveState(true);

      _isLoading = false;
      notifyListeners();
      developer.log(
        'startStream: streamId=$streamId',
        name: 'LivestreamProvider',
      );
      return streamId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      developer.log('startStream error: $e', name: 'LivestreamProvider');
      return null;
    }
  }

  /// Mentor kết thúc stream.
  Future<void> endStream(String streamId) async {
    try {
      _streamDocSub?.cancel();
      _streamDocSub = null;
      await _service.endLivestream(streamId).catchError((e) {
        developer.log(
          'endLivestream service error: $e',
          name: 'LivestreamProvider',
        );
      });
    } catch (e) {
      developer.log('endStream error: $e', name: 'LivestreamProvider');
    } finally {
      // Reset local state instantly so UI exits without freeze
      _joinedChannelId = null;
      _currentStream = null;
      _messages = [];
      _viewerCount = 0;
      _isScreenSharing = false;
      _isMinimized = false;
      _remoteIsScreenSharing = false;
      notifyListeners();

      // Clean up hardware resources asynchronously
      _cleanupAgora().catchError((e) {
        developer.log(
          '_cleanupAgora error in background: $e',
          name: 'LivestreamProvider',
        );
      });
      _updateNativeLiveState(false);
      developer.log(
        'endStream completed local cleanup: streamId=$streamId',
        name: 'LivestreamProvider',
      );
    }
  }

  // ─── VIEWER SIDE ──────────────────────────────────────────────────────────

  /// Viewer tham gia xem stream.
  Future<void> joinStream(String streamId) async {
    if (_joinedChannelId == streamId) {
      listenToMessages(streamId);
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initEngine();
      if (_engine != null) {
        await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
        _engine!.registerEventHandler(
          RtcEngineEventHandler(
            onUserJoined: (connection, uid, elapsed) {
              _remoteUid = uid;
              notifyListeners();
              developer.log(
                'Remote user joined: $uid',
                name: 'LivestreamProvider',
              );
            },
            onUserOffline: (connection, uid, reason) {
              _remoteUid = null;
              notifyListeners();
            },
            onError: (code, msg) {
              developer.log(
                'Agora error: $code $msg',
                name: 'LivestreamProvider',
              );
            },
            onVideoSizeChanged:
                (connection, sourceType, uid, width, height, rotation) {
                  bool isLandscape = width > height;
                  if (rotation == 90 || rotation == 270)
                    isLandscape = !isLandscape;
                  if (width > 0 && height > 0) {
                    final newRatio = width / height;
                    // Chỉ lấy 2 chữ số thập phân để tránh render lại liên tục vì sai số nhỏ
                    if ((_remoteVideoAspectRatio - newRatio).abs() > 0.01) {
                      _remoteVideoAspectRatio = newRatio;
                      notifyListeners();
                    }
                  }
                  if (_isLandscapeVideo != isLandscape) {
                    _isLandscapeVideo = isLandscape;
                    notifyListeners();
                  }
                },
            onRemoteVideoStats: (connection, stats) {
              // Log ra mỗi vài giây để biết người xem đang nhận được hình ảnh chất lượng bao nhiêu
              print('[Người Xem] Đang nhận video: ${stats.width}x${stats.height} | ${stats.rendererOutputFrameRate} FPS | Bitrate: ${stats.receivedBitrate} kbps');
            },
          ),
        );
        await _engine!.joinChannel(
          token: '',
          channelId: streamId,
          uid: 0,
          options: const ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            clientRoleType: ClientRoleType.clientRoleAudience,
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
          ),
        );
      }
      listenToMessages(streamId);

      _joinedChannelId = streamId;
      await _updateNativeLiveState(true);

      // Tăng viewerCount trong Firestore
      _service.incrementViewerCount(streamId, 1).catchError((e) {
        developer.log(
          'Failed to increment viewerCount: $e',
          name: 'LivestreamProvider',
        );
      });

      // Lắng nghe trạng thái stream để tự động đóng khi stream ended và để biết broadcaster có đang share màn hình không.
      _streamDocSub?.cancel();
      _streamDocSub = FirebaseFirestore.instance
          .collection('livestreams')
          .doc(streamId)
          .snapshots()
          .listen((doc) {
            if (!doc.exists) return;
            final data = doc.data()!;
            final status = data['status'] as String?;
            if (status == 'ended') {
              if (_isMinimized) {
                closeMinimizedStream(streamId);
              }
            }
            // Đồng bộ trạng thái share màn hình từ Firestore (broadcaster ghi, viewer đọc).
            final remoteScreenSharing =
                data['isScreenSharing'] as bool? ?? false;
            if (_remoteIsScreenSharing != remoteScreenSharing) {
              _remoteIsScreenSharing = remoteScreenSharing;
              notifyListeners();
              developer.log(
                'remoteIsScreenSharing from Firestore: $remoteScreenSharing',
                name: 'LivestreamProvider',
              );
            }
          });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      developer.log('joinStream error: $e', name: 'LivestreamProvider');
    }
  }

  /// Viewer rời khỏi stream.
  Future<void> leaveStream(String streamId) async {
    try {
      _streamDocSub?.cancel();
      _streamDocSub = null;

      // Reset state instantly
      _joinedChannelId = null;
      _currentStream = null;
      _messages = [];
      _remoteUid = null;
      _isMinimized = false;
      notifyListeners();

      // Giảm viewerCount trong Firestore
      _service.incrementViewerCount(streamId, -1).catchError((e) {
        developer.log(
          'Failed to decrement viewerCount: $e',
          name: 'LivestreamProvider',
        );
      });

      // Clean up hardware asynchronously
      _cleanupAgora().catchError((e) {
        developer.log(
          '_cleanupAgora error in background: $e',
          name: 'LivestreamProvider',
        );
      });
      _updateNativeLiveState(false);
    } catch (e) {
      developer.log('leaveStream error: $e', name: 'LivestreamProvider');
    }
  }

  // ─── MESSAGES ─────────────────────────────────────────────────────────────

  /// Bắt đầu lắng nghe messages realtime.
  void listenToMessages(String streamId) {
    _messageSub?.cancel();
    _messageSub = _service
        .getStreamMessages(streamId)
        .listen(
          (msgs) {
            _messages = msgs;
            notifyListeners();
          },
          onError: (e) {
            developer.log(
              'listenToMessages error: $e',
              name: 'LivestreamProvider',
            );
          },
        );
  }

  /// Gửi text message trong stream.
  Future<void> sendMessage(
    String streamId,
    String userId,
    String username,
    String avatarUrl,
    String text,
  ) async {
    if (text.trim().isEmpty) return;
    try {
      await _service.sendStreamMessage(streamId, {
        'userId': userId,
        'username': username,
        'avatarUrl': avatarUrl,
        'text': text.trim(),
        'type': 'text',
        'giftType': null,
        'giftCoinValue': null,
      });
    } catch (e) {
      developer.log('sendMessage error: $e', name: 'LivestreamProvider');
    }
  }

  /// Tặng gift trong stream.
  Future<bool> sendGift({
    required String streamId,
    required String fromUserId,
    required String toMentorId,
    required String fromUsername,
    required String fromAvatarUrl,
    required String giftType,
    required int coinValue,
  }) async {
    try {
      await _service.sendGift(
        fromUserId: fromUserId,
        toMentorId: toMentorId,
        streamId: streamId,
        giftType: giftType,
        coinValue: coinValue,
        fromUsername: fromUsername,
        fromAvatarUrl: fromAvatarUrl,
      );

      _myCoins -= coinValue;
      if (_myCoins < 0) _myCoins = 0;
      notifyListeners();

      return true;
    } catch (e) {
      developer.log('sendGift error: $e', name: 'LivestreamProvider');
      return false;
    }
  }

  // ─── GENERAL ──────────────────────────────────────────────────────────────

  /// Bắt đầu lắng nghe danh sách livestreams đang live.
  void listenToLiveStreams({String? gameFilter}) {
    _streamsSub?.cancel();
    _streamsSub = _service
        .getLivestreams(gameFilter: gameFilter)
        .listen(
          (streams) {
            _liveStreams = streams;
            notifyListeners();
          },
          onError: (e) {
            developer.log(
              'listenToLiveStreams error: $e',
              name: 'LivestreamProvider',
            );
          },
        );
  }

  /// Load coin balance của user.
  Future<void> loadUserCoins(String userId) async {
    try {
      _myCoins = await _service.getUserCoins(userId);
      notifyListeners();
    } catch (e) {
      developer.log('loadUserCoins error: $e', name: 'LivestreamProvider');
    }
  }

  /// Set currentStream để hiển thị trong LiveStreamScreen.
  void setCurrentStream(LivestreamModel stream) {
    _currentStream = stream;
    notifyListeners();
  }

  // ─── CLEANUP ──────────────────────────────────────────────────────────────

  Future<void> _cleanupAgora() async {
    try {
      _messageSub?.cancel();
      _messageSub = null;
      if (_engine != null) {
        await _engine!.leaveChannel();
        await _engine!.release();
        _engine = null;
      }
      _localVideoOn = false;
      _remoteUid = null;
    } catch (e) {
      developer.log('_cleanupAgora error: $e', name: 'LivestreamProvider');
    }
  }

  @override
  void dispose() {
    _streamsSub?.cancel();
    _messageSub?.cancel();
    _cleanupAgora();
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─── PIP & SCREEN SHARING METHODS ──────────────────────────────────────────

  void minimize(BuildContext context, String streamId, bool isMentor) {
    if (_isMinimized) return;
    _isMinimized = true;
    notifyListeners();

    _overlayEntry = OverlayEntry(
      builder: (ctx) => FloatingLiveWindow(
        streamId: streamId,
        isMentor: isMentor,
        onClose: () {
          closeMinimizedStream(streamId);
        },
        onRestore: () {
          restoreStream(context, streamId, isMentor);
        },
      ),
    );

    final overlayState = Navigator.of(context).overlay;
    if (overlayState != null) {
      overlayState.insert(_overlayEntry!);
    }
  }

  void closeMinimizedStream(String streamId) {
    if (!_isMinimized) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isMinimized = false;
    notifyListeners();
    leaveStream(streamId);
  }

  void restoreStream(BuildContext context, String streamId, bool isMentor) {
    if (!_isMinimized) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isMinimized = false;
    notifyListeners();

    Navigator.pushNamed(
      context,
      '/live-stream',
      arguments: {'streamId': streamId, 'isMentor': isMentor},
    );
  }

  Future<void> startScreenShare() async {
    if (_engine == null) return;
    try {
      // Dừng camera preview trước để tránh conflict với Extension
      await _engine!.stopPreview(sourceType: VideoSourceType.videoSourceCamera);

      // Khởi động screen capture trước để mở cổng IPC lắng nghe Extension
      await _engine!.startScreenCapture(
        const ScreenCaptureParameters2(
          captureAudio: true,
          captureVideo: true,
          videoParams: ScreenVideoParameters(
            dimensions: VideoDimensions(width: 1920, height: 1080),
            frameRate: 60, // 60 fps cho trải nghiệm chơi game siêu mượt trên các máy đời mới
            contentHint: VideoContentHint.contentHintMotion, // Ưu tiên fps (độ mượt chuyển động) hơn là độ phân giải tĩnh
          ),
        ),
      );

      await _engine!.startPreview(
        sourceType: VideoSourceType.videoSourceScreen,
      );

      // Sau đó cập nhật channel options để publish screen track
      await _engine!.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishCameraTrack: false,
          publishScreenCaptureVideo: true,
          publishScreenTrack: true, // Bổ sung cho Web
          publishMicrophoneTrack: true,
          publishScreenCaptureAudio: true,
        ),
      );

      _isScreenSharing = true;
      notifyListeners();

      // Ghi trạng thái lên Firestore để viewer biết không cần lật cam.
      if (_joinedChannelId != null) {
        FirebaseFirestore.instance
            .collection('livestreams')
            .doc(_joinedChannelId)
            .update({'isScreenSharing': true})
            .catchError(
              (e) => developer.log(
                'Failed to write isScreenSharing: $e',
                name: 'LivestreamProvider',
              ),
            );
      }

      developer.log('Screen sharing started', name: 'LivestreamProvider');
    } catch (e) {
      developer.log('startScreenShare error: $e', name: 'LivestreamProvider');
    }
  }

  Future<void> stopScreenShare() async {
    if (_engine == null) return;
    try {
      await _engine!.stopPreview(sourceType: VideoSourceType.videoSourceScreen);
      await _engine!.stopScreenCapture();

      // Bật lại camera preview sau khi dừng screen share
      await _engine!.startPreview(
        sourceType: VideoSourceType.videoSourceCamera,
      );

      await _engine!.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishCameraTrack: true,
          publishScreenCaptureVideo: false,
          publishScreenTrack: false, // Bổ sung
          publishMicrophoneTrack: true,
          publishScreenCaptureAudio: false,
        ),
      );

      _isScreenSharing = false;
      notifyListeners();

      // Ghi trạng thái lên Firestore để viewer biết để lật cam trở lại.
      if (_joinedChannelId != null) {
        FirebaseFirestore.instance
            .collection('livestreams')
            .doc(_joinedChannelId)
            .update({'isScreenSharing': false})
            .catchError(
              (e) => developer.log(
                'Failed to write isScreenSharing: $e',
                name: 'LivestreamProvider',
              ),
            );
      }

      developer.log('Screen sharing stopped', name: 'LivestreamProvider');
    } catch (e) {
      developer.log('stopScreenShare error: $e', name: 'LivestreamProvider');
    }
  }
}
