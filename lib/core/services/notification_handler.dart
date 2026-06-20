import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'firestore_service.dart';
import '../models/user_model.dart';
import '../../user/screens/chat/chat_screen.dart';
import '../../user/screens/call/video_call_screen.dart';
import '../../user/screens/main/main_screen.dart';
import '../routes/app_router.dart';
import 'moment_notification_navigation.dart';

class AppNotificationHandler {
  static const _pendingActionStorageKey = 'pending_notification_action';
  static ReceivedAction? _pendingAction;
  static bool _isProcessingPending = false;

  static Future<void> _savePendingAction(
    Map<String, String?> payload,
    String actionKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingActionStorageKey,
      jsonEncode({'payload': payload, 'actionKey': actionKey}),
    );
  }

  static Future<Map<String, dynamic>?> _takeStoredPendingAction() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingActionStorageKey);
    if (raw == null || raw.isEmpty) return null;
    await prefs.remove(_pendingActionStorageKey);

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final payload = decoded['payload'];
    return {
      'payload': payload is Map
          ? payload.map((key, value) => MapEntry('$key', value?.toString()))
          : <String, String?>{},
      'actionKey': decoded['actionKey']?.toString() ?? '',
    };
  }

  static void _navigateToMainTab(int tabIndex) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.popUntil((route) => route.isFirst);
    mainScreenTabIndex.value = tabIndex;
  }

  static Future<NavigatorState?> _waitForNavigator() async {
    for (var i = 0; i < 20; i++) {
      final navigator = navigatorKey.currentState;
      if (navigator != null) return navigator;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return null;
  }

  static Future<String> _resolvePeerUserId(
    String matchId,
    String peerUserId,
  ) async {
    if (peerUserId.isNotEmpty) return peerUserId;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || matchId.isEmpty) return '';

    final matchDoc = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .get();
    final userIds = List<String>.from(matchDoc.data()?['userIds'] ?? const []);
    return userIds.firstWhere((id) => id != currentUserId, orElse: () => '');
  }

  static Future<void> _navigateToChat(String matchId, String peerUserId) async {
    final navigator = await _waitForNavigator();
    if (navigator == null) {
      developer.log('Navigator not ready for chat', name: 'Notification');
      return;
    }

    final resolvedPeerUserId = await _resolvePeerUserId(matchId, peerUserId);
    if (matchId.isEmpty || resolvedPeerUserId.isEmpty) {
      developer.log(
        'Missing chat payload: matchId=$matchId peerUserId=$peerUserId',
        name: 'Notification',
      );
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(resolvedPeerUserId)
        .get();

    if (userDoc.exists && userDoc.data() != null) {
      final peerUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(matchId: matchId, peerUser: peerUser),
        ),
      );
      developer.log('Pushed ChatScreen', name: 'Notification');
    } else {
      developer.log(
        'User doc not found for peerUserId=$resolvedPeerUserId',
        name: 'Notification',
      );
    }
  }

  static Future<void> _navigateToLiveStream(String streamId) async {
    if (streamId.isEmpty) return;
    final navigator = await _waitForNavigator();
    if (navigator == null) {
      developer.log(
        'Navigator not ready for live stream',
        name: 'Notification',
      );
      return;
    }

    navigator.popUntil((route) => route.isFirst);
    navigator.pushNamed(
      '/live-stream',
      arguments: {'streamId': streamId, 'isMentor': false},
    );
    developer.log(
      'Pushed /live-stream streamId=$streamId',
      name: 'Notification',
    );
  }

  // Hàm xử lý khi người dùng tương tác với thông báo (nhấn nút hành động)
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    final payload = receivedAction.payload ?? {};
    final actionKey = receivedAction.buttonKeyPressed;

    developer.log(
      '>>> onActionReceivedMethod called | type: ${payload['type']} | actionKey: "$actionKey" | payload: $payload',
      name: 'Notification',
    );

    // Luôn queue để xử lý lại nếu action chạy ở background isolate (iOS)
    _pendingAction = receivedAction;
    await _savePendingAction(payload, actionKey);

    // Đợi navigator sẵn sàng (cần thiết khi app vừa mở từ notification)
    await Future.delayed(const Duration(milliseconds: 300));

    if (navigatorKey.currentState == null) {
      developer.log('Navigator not ready, queued action', name: 'Notification');
      return;
    }

    await _handleAction(receivedAction);
    _pendingAction = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingActionStorageKey);
  }

  static Future<void> processPendingAction() async {
    if (_isProcessingPending) return;
    if (navigatorKey.currentState == null) return;

    _isProcessingPending = true;
    final action = _pendingAction;
    _pendingAction = null;

    if (action != null) {
      await _handleAction(action);
    } else {
      final storedAction = await _takeStoredPendingAction();
      if (storedAction != null) {
        await _handlePayload(
          Map<String, String?>.from(storedAction['payload'] as Map),
          storedAction['actionKey'] as String,
        );
      }
    }

    _isProcessingPending = false;
  }

  static Future<void> _handleAction(ReceivedAction receivedAction) async {
    final payload = receivedAction.payload ?? {};
    final actionKey = receivedAction.buttonKeyPressed;
    await _handlePayload(payload, actionKey);
  }

  static Future<void> _handlePayload(
    Map<String, String?> payload,
    String actionKey,
  ) async {
    if (payload['type'] == 'call') {
      final matchId = payload['matchId'] ?? '';
      final peerUserId = payload['peerUserId'] ?? '';

      if (actionKey == 'accept') {
        developer.log('Accept call', name: 'Notification');
        await _handleAcceptCall(matchId, peerUserId);
      } else if (actionKey == 'decline') {
        developer.log('Decline call', name: 'Notification');
        await _handleDeclineCall(matchId);
      } else {
        if (!VideoCallScreen.isCallActive) {
          showIncomingCallDialog(matchId, peerUserId);
        }
      }
    } else if (payload['type'] == 'chat' || payload['type'] == 'match') {
      final matchId = payload['matchId'] ?? '';
      final peerUserId = payload['peerUserId'] ?? '';

      developer.log(
        'Navigate to ${payload['type']}: matchId=$matchId peerUserId=$peerUserId',
        name: 'Notification',
      );
      developer.log(
        'Navigator state: ${navigatorKey.currentState}',
        name: 'Notification',
      );

      try {
        await _navigateToChat(matchId, peerUserId);
      } catch (e) {
        developer.log('Error navigating to chat: $e', name: 'Notification');
      }
    } else if (payload['type'] == 'moment_reaction') {
      final momentId = payload['momentId'] ?? '';
      developer.log(
        'Navigate to moment: momentId=$momentId',
        name: 'Notification',
      );
      developer.log(
        'Navigator state: ${navigatorKey.currentState}',
        name: 'Notification',
      );
      _navigateToMainTab(1);
      if (momentId.isNotEmpty) {
        pendingMomentIdToOpen.value = momentId;
      }
      developer.log(
        'Switched to Moment feed tab and queued momentId=$momentId',
        name: 'Notification',
      );
    } else if (payload['type'] == 'like') {
      developer.log('Navigate to liked-me', name: 'Notification');
      _navigateToMainTab(2);
    } else if (payload['type'] == 'mentor_live') {
      final streamId = payload['streamId'] ?? '';
      developer.log(
        'Navigate to mentor live: streamId=$streamId',
        name: 'Notification',
      );
      await _navigateToLiveStream(streamId);
    } else {
      developer.log(
        'Unknown notification type: ${payload['type']}',
        name: 'Notification',
      );
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    developer.log(
      'Notification created: ${receivedNotification.id}',
      name: 'Notification',
    );
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    developer.log(
      'Notification displayed: ${receivedNotification.id}',
      name: 'Notification',
    );
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    developer.log(
      'Notification dismissed: ${receivedAction.id}',
      name: 'Notification',
    );
  }

  static Future<void> _handleAcceptCall(
    String matchId,
    String peerUserId,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('calls').doc(matchId).set({
        'answered': true,
        'status': 'accepted',
      }, SetOptions(merge: true));

      final peerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peerUserId)
          .get();

      if (peerDoc.exists && peerDoc.data() != null) {
        final peerUser = UserModel.fromMap(peerDoc.data()!, peerDoc.id);
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              channelName: matchId,
              peerUserId: peerUserId,
              peerUsername: peerUser.username,
              peerAvatarUrl: peerUser.avatarUrl,
              isVoiceCall: false,
            ),
          ),
        );
      }
    } catch (e) {
      developer.log('Error accepting call: $e', name: 'Notification');
    }
  }

  static Future<void> _handleDeclineCall(String matchId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    await FirebaseFirestore.instance.collection('calls').doc(matchId).set({
      'status': 'declined',
      'answered': false,
      'endedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    await FirestoreService().addCallMessage(
      matchId: matchId,
      senderId: currentUserId,
      duration: 0,
      declined: true,
    );
  }

  static void showIncomingCallDialog(String matchId, String peerUserId) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      developer.log(
        'Cannot show dialog: context is null',
        name: 'Notification',
      );
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(peerUserId)
        .get();

    if (!userDoc.exists || userDoc.data() == null) {
      developer.log('User not found for dialog', name: 'Notification');
      return;
    }

    final peerUsername = userDoc.data()!['username'] ?? '';
    final peerAvatarUrl = userDoc.data()!['avatarUrl'] ?? '';

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: peerAvatarUrl.isNotEmpty
                    ? NetworkImage(peerAvatarUrl)
                    : null,
                child: peerAvatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 36)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Cuộc gọi đến từ',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                peerUsername,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.call),
                    label: const Text('Nghe'),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _handleAcceptCall(matchId, peerUserId);
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.call_end),
                    label: const Text('Từ chối'),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _handleDeclineCall(matchId);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
