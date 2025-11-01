const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

setGlobalOptions({ region: 'asia-southeast1', memory: '512MiB', timeoutSeconds: 30 });

// Gửi thông báo khi có tin nhắn mới
exports.sendMessageNotification = onDocumentCreated(
  'matches/{matchId}/messages/{messageId}',
  async (event) => {
    try {
      const snap = event.data;
      if (!snap) return;

      const message = snap.data();
      const matchId = event.params.matchId;
      console.log('New message:', message);

      const db = admin.firestore();
      const matchDoc = await db.collection('matches').doc(matchId).get();
      if (!matchDoc.exists) return console.log('Match not found');

      const matchData = matchDoc.data();
      const receiverId = matchData.user1Id === message.senderId
        ? matchData.user2Id
        : matchData.user1Id;

      console.log('Receiver ID:', receiverId);

      const receiverDoc = await db.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) return console.log('Receiver not found');

      const fcmToken = receiverDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token');

      const senderDoc = await db.collection('users').doc(message.senderId).get();
      const senderName = senderDoc.exists
        ? senderDoc.data()?.username || 'User'
        : 'User';

      let messageBody = message.message || '';
      if (message.imageUrl) messageBody = 'Sent a photo';
      else if (message.type === 'call') messageBody = 'Missed call';

      // QUAN TRONG: Payload cho Android với cả notification và data
      const payload = {
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            channelId: 'gamenect_channel',
            sound: 'default', 
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',  
          },
        },
        notification: {
          title: senderName,
          body: messageBody,
          sound: 'default',  
          click_action: 'FLUTTER_NOTIFICATION_CLICK', 
        },
        data: {
          type: 'chat',
          matchId: matchId,
          peerUserId: message.senderId,
          peerUsername: senderName,
          message: messageBody,
          'content.id': Date.now().toString(),
          'content.channelKey': 'gamenect_channel',
          'content.title': senderName,
          'content.body': messageBody,
          'content.notificationLayout': 'Messaging',
          'content.category': 'Message',
          'content.wakeUpScreen': true,  
          'content.payload.type': 'chat',
          'content.payload.matchId': matchId,
          'content.payload.peerUserId': message.senderId,
          'content.payload.peerUsername': senderName,
        },
      };

      console.log('Sending notification...');
      const response = await admin.messaging().send(payload);
      console.log('Notification sent:', response);
      return response;
    } catch (error) {
      console.error('Error:', error);
      return null;
    }
  }
);

// Gửi thông báo khi có cuộc gọi
exports.sendCallNotification = onDocumentCreated(
  'calls/{matchId}',
  async (event) => {
    try {
      const call = event.data?.data();
      const matchId = event.params.matchId;
      if (!call) return;

      console.log('New call:', call);

      const db = admin.firestore();
      const receiverDoc = await db.collection('users').doc(call.receiverId).get();
      if (!receiverDoc.exists) return console.log('Receiver not found');

      const fcmToken = receiverDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token');

      const callerDoc = await db.collection('users').doc(call.callerId).get();
      const callerName = callerDoc.exists
        ? callerDoc.data()?.username || 'User'
        : 'User';

      const payload = {
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            channelId: 'call_channel',
            sound: 'default',
            priority: 'max',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        notification: {
          title: 'Cuộc gọi đến',
          body: `${callerName} đang gọi cho bạn`,
          sound: 'default',  
          click_action: 'FLUTTER_NOTIFICATION_CLICK',  
        },
        data: {
          type: 'call',
          matchId: matchId,
          peerUserId: call.callerId,
          peerUsername: callerName,
          'content.id': matchId,
          'content.channelKey': 'call_channel',
          'content.title': 'Cuộc gọi đến',
          'content.body': `${callerName} đang gọi cho bạn`,
          'content.category': 'Call',
          'content.wakeUpScreen': true,  
          'content.fullScreenIntent': true,  
          'content.criticalAlert': true,  
          'content.locked': true,  
          'content.payload.type': 'call',
          'content.payload.matchId': matchId,
          'content.payload.peerUserId': call.callerId,
          'content.payload.peerUsername': callerName,
          'actionButtons.0.key': 'accept',
          'actionButtons.0.label': 'Nghe',
          'actionButtons.0.autoDismissible': true, 
          'actionButtons.1.key': 'decline',
          'actionButtons.1.label': 'Từ chối',
          'actionButtons.1.autoDismissible': true,  
        },
      };

      console.log('Sending call notification...');
      const response = await admin.messaging().send(payload);
      console.log('Call notification sent');
      return response;
    } catch (error) {
      console.error('Error:', error);
      return null;
    }
  }
);

// Gửi thông báo khi có reaction moment
exports.sendMomentReactionNotification = onDocumentCreated(
  'moments/{momentId}/reactions/{reactionId}',
  async (event) => {
    try {
      const reaction = event.data?.data();
      const momentId = event.params.momentId;
      if (!reaction) return;

      console.log('New reaction:', reaction);

      const db = admin.firestore();
      const momentDoc = await db.collection('moments').doc(momentId).get();
      if (!momentDoc.exists) return console.log('Moment not found');

      const momentOwnerId = momentDoc.data()?.userId;
      if (reaction.userId === momentOwnerId) return console.log('Self reaction, skip');

      const ownerDoc = await db.collection('users').doc(momentOwnerId).get();
      if (!ownerDoc.exists) return console.log('Owner not found');

      const fcmToken = ownerDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token');

      const reactorDoc = await db.collection('users').doc(reaction.userId).get();
      const reactorName = reactorDoc.exists
        ? reactorDoc.data()?.username || 'Someone'
        : 'Someone';

      const payload = {
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            channelId: 'moment_channel',
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        notification: {
          title: `${reactorName} đã thả cảm xúc ${reaction.emoji || '❤️'}`,
          body: 'Vào moment của bạn',
          sound: 'default',  
          click_action: 'FLUTTER_NOTIFICATION_CLICK',  
        },
        data: {
          type: 'moment_reaction',
          momentId: momentId,
          reactorUserId: reaction.userId,
          reactorUsername: reactorName,
          emoji: reaction.emoji || '❤️',
          momentOwnerId: momentOwnerId,
          'content.id': momentId,
          'content.channelKey': 'moment_channel',
          'content.title': `${reactorName} đã thả cảm xúc ${reaction.emoji || '❤️'}`,
          'content.body': 'Vào moment của bạn',
          'content.category': 'Social',
          'content.payload.type': 'moment_reaction',
          'content.payload.momentId': momentId,
          'content.payload.reactorUserId': reaction.userId,
          'content.payload.reactorUsername': reactorName,
          'content.payload.emoji': reaction.emoji || '❤️',
          'content.payload.momentOwnerId': momentOwnerId,
        },
      };

      console.log('Sending moment notification...');
      const response = await admin.messaging().send(payload);
      console.log('Moment notification sent');
      return response;
    } catch (error) {
      console.error('Error:', error);
      return null;
    }
  }
);