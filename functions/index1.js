const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

// Cấu hình global cho tất cả Cloud Functions
// Region: Asia Southeast 1 (Singapore) - gần VN nhất
// Memory: 512MB - đủ cho push notification
// Timeout: 30s - timeout mặc định
setGlobalOptions({ region: 'asia-southeast1', memory: '512MiB', timeoutSeconds: 30 });

/**
 * Cloud Function: Gửi push notification khi có tin nhắn mới
 * 
 * Trigger: Khi có document mới được tạo trong collection messages
 * Path: matches/{matchId}/messages/{messageId}
 * 
 * Flow:
 * 1. Lấy thông tin tin nhắn và match
 * 2. Xác định người nhận (user còn lại trong match)
 * 3. Lấy FCM token của người nhận
 * 4. Gửi notification với payload Android-optimized
 */
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
      
      // Lấy thông tin match để biết ai là người nhận
      const matchDoc = await db.collection('matches').doc(matchId).get();
      if (!matchDoc.exists) return console.log('Match not found');

      const matchData = matchDoc.data();
      // Người nhận là user còn lại (không phải sender)
      const receiverId = matchData.user1Id === message.senderId
        ? matchData.user2Id
        : matchData.user1Id;

      console.log('Receiver ID:', receiverId);

      // Lấy FCM token của người nhận
      const receiverDoc = await db.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) return console.log('Receiver not found');

      const fcmToken = receiverDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token');

      // Lấy tên người gửi để hiển thị trong notification
      const senderDoc = await db.collection('users').doc(message.senderId).get();
      const senderName = senderDoc.exists
        ? senderDoc.data()?.username || 'User'
        : 'User';

      // Format nội dung tin nhắn
      let messageBody = message.message || '';
      if (message.imageUrl) messageBody = 'Sent a photo'; // Nếu là ảnh
      else if (message.type === 'call') messageBody = 'Missed call'; // Nếu là cuộc gọi nhỡ

      // QUAN TRỌNG: Payload cho Android với cả notification và data
      // Notification: Hiển thị trên notification tray
      // Data: Dữ liệu để app xử lý khi tap vào notification
      const payload = {
        token: fcmToken,
        android: {
          priority: 'high', // Priority cao để notification hiện ngay
          notification: {
            channelId: 'gamenect_channel', // Channel ID phải match với app
            sound: 'default', 
            clickAction: 'FLUTTER_NOTIFICATION_CLICK', // Action khi tap vào 
          },
        },
        notification: {
          title: senderName,
          body: messageBody,
          sound: 'default',  
          click_action: 'FLUTTER_NOTIFICATION_CLICK', 
        },
        // Data payload cho app Flutter xử lý
        data: {
          type: 'chat', // Loại notification
          matchId: matchId,
          peerUserId: message.senderId,
          peerUsername: senderName,
          message: messageBody,
          // Các field cho awesome_notifications plugin
          'content.id': Date.now().toString(),
          'content.channelKey': 'gamenect_channel',
          'content.title': senderName,
          'content.body': messageBody,
          'content.notificationLayout': 'Messaging',
          'content.category': 'Message',
          'content.wakeUpScreen': true, // Đánh thức màn hình
          // Payload để app navigate đến chat screen
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

/**
 * Cloud Function: Gửi push notification khi có cuộc gọi đến
 * 
 * Trigger: Khi có document mới được tạo trong collection calls
 * Path: calls/{matchId}
 * 
 * Flow:
 * 1. Lấy thông tin cuộc gọi
 * 2. Lấy FCM token của người nhận
 * 3. Gửi notification với priority cao và action buttons
 * 4. Hiển thị full screen intent để có thể trả lời ngay
 */
exports.sendCallNotification = onDocumentCreated(
  'calls/{matchId}',
  async (event) => {
    try {
      const call = event.data?.data();
      const matchId = event.params.matchId;
      if (!call) return;

      console.log('New call:', call);

      const db = admin.firestore();
      
      // Lấy FCM token của người nhận cuộc gọi
      const receiverDoc = await db.collection('users').doc(call.receiverId).get();
      if (!receiverDoc.exists) return console.log('Receiver not found');

      const fcmToken = receiverDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token');

      // Lấy tên người gọi
      const callerDoc = await db.collection('users').doc(call.callerId).get();
      const callerName = callerDoc.exists
        ? callerDoc.data()?.username || 'User'
        : 'User';

      // Payload cho notification cuộc gọi
      // Priority max và full screen intent để hiển thị ngay cả khi màn hình khóa
      const payload = {
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            channelId: 'call_channel', // Channel riêng cho cuộc gọi
            sound: 'default',
            priority: 'max', // Priority cao nhất
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        notification: {
          title: 'Cuộc gọi đến',
          body: `${callerName} đang gọi cho bạn`,
          sound: 'default',  
          click_action: 'FLUTTER_NOTIFICATION_CLICK',  
        },
        // Data payload với action buttons để nhận/từ chối cuộc gọi
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
          'content.wakeUpScreen': true, // Đánh thức màn hình
          'content.fullScreenIntent': true, // Hiển thị full screen
          'content.criticalAlert': true, // Alert quan trọng
          'content.locked': true, // Hiển thị khi màn hình khóa
          'content.payload.type': 'call',
          'content.payload.matchId': matchId,
          'content.payload.peerUserId': call.callerId,
          'content.payload.peerUsername': callerName,
          // Action buttons để trả lời hoặc từ chối
          'actionButtons.0.key': 'accept',
          'actionButtons.0.label': 'Nghe',
          'actionButtons.0.autoDismissible': true, // Tự động dismiss khi tap
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

/**
 * Cloud Function: Gửi push notification khi có người react vào moment
 * 
 * Trigger: Khi có document mới được tạo trong subcollection reactions
 * Path: moments/{momentId}/reactions/{reactionId}
 * 
 * Flow:
 * 1. Lấy thông tin reaction
 * 2. Lấy thông tin moment để biết chủ nhân
 * 3. Skip nếu tự react vào moment của mình
 * 4. Gửi notification cho chủ moment
 */
exports.sendMomentReactionNotification = onDocumentCreated(
  'moments/{momentId}/reactions/{reactionId}',
  async (event) => {
    try {
      const reaction = event.data?.data();
      const momentId = event.params.momentId;
      if (!reaction) return;

      console.log('New reaction:', reaction);

      const db = admin.firestore();
      
      // Lấy thông tin moment để biết ai là chủ nhân
      const momentDoc = await db.collection('moments').doc(momentId).get();
      if (!momentDoc.exists) return console.log('Moment not found');

      const momentOwnerId = momentDoc.data()?.userId;
      // Skip nếu tự react vào moment của mình
      if (reaction.userId === momentOwnerId) return console.log('Self reaction, skip');

      // Lấy FCM token của chủ moment
      const ownerDoc = await db.collection('users').doc(momentOwnerId).get();
      if (!ownerDoc.exists) return console.log('Owner not found');

      const fcmToken = ownerDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token');

      // Lấy tên người react
      const reactorDoc = await db.collection('users').doc(reaction.userId).get();
      const reactorName = reactorDoc.exists
        ? reactorDoc.data()?.username || 'Someone'
        : 'Someone';

      // Payload notification moment reaction
      const payload = {
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            channelId: 'moment_channel', // Channel riêng cho moment
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
        // Data payload để app navigate đến moment screen
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