import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'firestore_service.dart';
import '../models/user_model.dart';
import '../../user/screens/chat/chat_screen.dart';
import '../../user/screens/call/video_call_screen.dart';
import '../routes/app_router.dart';

class AppNotificationHandler {
  // Hàm xử lý khi người dùng tương tác với thông báo (nhấn nút hành động)
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    final payload = receivedAction.payload ?? {};
    final actionKey = receivedAction.buttonKeyPressed;
    
    developer.log('Notification action: $actionKey, payload: $payload', name: 'Notification');

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
        _showIncomingCallDialog(matchId, peerUserId);
      }
    } else if (payload['type'] == 'chat') {
      final matchId = payload['matchId'] ?? '';
      final peerUserId = payload['peerUserId'] ?? '';
      
      developer.log('Navigate to chat: $matchId', name: 'Notification');
      
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(peerUserId)
            .get();
            
        if (userDoc.exists && userDoc.data() != null) {
          final peerUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                matchId: matchId,
                peerUser: peerUser,
              ),
            ),
          );
        }
      } catch (e) {
        developer.log('Error: $e', name: 'Notification');
      }
    } else if (payload['type'] == 'moment_reaction') {
      final momentId = payload['momentId'] ?? '';
      // final reactorUserId = payload['reactorUserId'] ?? '';
      developer.log('Navigate to moment: $momentId', name: 'Notification');
      navigatorKey.currentState?.pushNamed(
        '/moments',
        arguments: {'momentId': momentId}
      );
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    developer.log('Notification created: ${receivedNotification.id}', name: 'Notification');
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    developer.log('Notification displayed: ${receivedNotification.id}', name: 'Notification');
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    developer.log('Notification dismissed: ${receivedAction.id}', name: 'Notification');
  }

  static Future<void> _handleAcceptCall(String matchId, String peerUserId) async {
    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(matchId)
          .set({'answered': true, 'status': 'accepted'}, SetOptions(merge: true));

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
    
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(matchId)
        .set({
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

  static void _showIncomingCallDialog(String matchId, String peerUserId) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      developer.log('Cannot show dialog: context is null', name: 'Notification');
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
                child: peerAvatarUrl.isEmpty ? const Icon(Icons.person, size: 36) : null,
              ),
              const SizedBox(height: 16),
              Text('Cuộc gọi đến từ', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                peerUsername,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
