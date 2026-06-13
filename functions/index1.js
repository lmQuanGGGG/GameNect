const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

setGlobalOptions({ region: 'asia-southeast1', memory: '512MiB', timeoutSeconds: 30, maxInstances: 10 });

// ─────────────────────────────────────────────
// Helper: Gửi FCM hybrid notification
// ─────────────────────────────────────────────
async function sendFcmNotification({ token, title, body, channelId, androidPriority = 'high', data = {} }) {
  // Đảm bảo tất cả data values là string (FCM yêu cầu)
  const stringData = Object.fromEntries(
    Object.entries({ ...data, title, body }).map(([k, v]) => [k, String(v ?? '')])
  );

  return admin.messaging().send({
    token,
    // KHÔNG dùng top-level notification field — mỗi platform xử lý riêng:
    // - Android: android.notification
    // - iOS:     apns.payload.aps.alert
    // - Web:     KHÔNG có notification → data-only → onBackgroundMessage() được gọi đúng
    android: {
      priority: 'high',
      notification: { title, body, channelId, sound: 'default', priority: androidPriority },
    },
    apns: {
      payload: {
        aps: {
          alert: { title, body },
          sound: 'default',
          badge: 1,
          'content-available': 1, // ← BẮT BUỘC để iOS wake app ở background/killed
        },
      },
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'alert',
      },
    },
    webpush: {
      headers: { Urgency: 'high' },
      // Không có notification field → web nhận data-only
      // → firebase-messaging-sw.js onBackgroundMessage() được gọi với đầy đủ payload
      data: stringData,
    },
    data, // data gốc cho Android/iOS
  });
}

// Helper riêng cho Call notification: dùng 'voip' push type để bypass DND
// và luôn hiển thị ngay cả khi app bị kill
async function sendCallFcmNotification({ token, title, body, data = {} }) {
  const stringData = Object.fromEntries(
    Object.entries({ ...data, title, body }).map(([k, v]) => [k, String(v ?? '')])
  );

  return admin.messaging().send({
    token,
    android: {
      priority: 'high',
      // Bỏ 'notification' field để Android nhận dạng là data-only push,
      // từ đó trigger mySilentDataHandle tạo AwesomeNotification với nút Nghe/Từ chối
    },
    apns: {
      payload: {
        aps: {
          alert: { title, body },
          sound: 'default',
          badge: 1,
          'content-available': 1,
        },
      },
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'alert',
      },
    },
    webpush: {
      headers: { Urgency: 'high' },
      data: stringData,
    },
    data,
  });
}

// ─────────────────────────────────────────────
// 1. sendMessageNotification
//    Trigger: chats/{matchId}/messages/{messageId} — document mới
// ─────────────────────────────────────────────
exports.sendMessageNotification = onDocumentCreated(
  'chats/{matchId}/messages/{messageId}',
  async (event) => {
    try {
      const snap = event.data;
      if (!snap) return;

      const message = snap.data();
      const matchId = event.params.matchId;

      // Bỏ qua react message (không cần notification)
      if (message.type === 'react') return console.log('React message — skip');

      const db = admin.firestore();

      // Lấy match để tìm người nhận
      const matchDoc = await db.collection('matches').doc(matchId).get();
      if (!matchDoc.exists) return console.log('Match not found');

      // userIds là array [userId1, userId2]
      const userIds = matchDoc.data().userIds || [];
      const receiverId = userIds.find(id => id !== message.senderId);
      if (!receiverId) return console.log('Receiver not found in userIds');

      // Lấy FCM token người nhận
      const receiverDoc = await db.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) return console.log('Receiver not found');
      const fcmToken = receiverDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token for receiver');

      // Lấy tên người gửi
      const senderDoc = await db.collection('users').doc(message.senderId).get();
      const senderName = senderDoc.exists ? senderDoc.data()?.username || 'User' : 'User';

      // Format nội dung tin nhắn (field là 'text', không phải 'message')
      let body = message.text || '';
      if (message.mediaUrl) body = message.isVideo ? 'Đã gửi video 🎥' : 'Đã gửi ảnh 🖼️';
      else if (message.audioUrl) body = 'Đã gửi tin nhắn thoại 🎤';
      else if (message.type === 'call') body = 'Cuộc gọi nhỡ 📞';

      const response = await sendFcmNotification({
        token: fcmToken,
        title: senderName,
        body,
        channelId: 'gamenect_channel',
        data: { type: 'chat', matchId, peerUserId: message.senderId, peerUsername: senderName, message: body },
      });
      console.log('Message notification sent:', response);
    } catch (e) {
      console.error('sendMessageNotification error:', e);
    }
  }
);

// ─────────────────────────────────────────────
// 2. sendCallNotification
//    Trigger: calls/{matchId} — document được ghi (tạo mới hoặc cập nhật)
//    Chỉ gửi khi status chuyển sang 'active' (cuộc gọi mới bắt đầu)
// ─────────────────────────────────────────────
exports.sendCallNotification = onDocumentWritten(
  'calls/{matchId}',
  async (event) => {
    try {
      const before = event.data.before;
      const after = event.data.after;

      // Document bị xóa → bỏ qua
      if (!after.exists) return;

      const afterData = after.data();
      const beforeData = before.exists ? before.data() : null;

      // Chỉ xử lý khi status chuyển sang 'active'
      if (afterData.status !== 'active') return;
      // Nếu trước đó đã là 'active' (update thông thường) → bỏ qua
      if (beforeData && beforeData.status === 'active') return console.log('Call update — skip');

      const matchId = event.params.matchId;
      const db = admin.firestore();

      // Lấy FCM token người nhận
      const receiverDoc = await db.collection('users').doc(afterData.receiverId).get();
      if (!receiverDoc.exists) return console.log('Receiver not found');
      const fcmToken = receiverDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token for receiver');

      // Lấy tên người gọi
      const callerDoc = await db.collection('users').doc(afterData.callerId).get();
      const callerName = callerDoc.exists ? callerDoc.data()?.username || 'User' : 'User';

      const callType = afterData.type === 'voice' ? 'thoại' : 'video';

      // CALL dùng helper riêng để đảm bảo iOS nhận push ngay cả khi app bị kill
      // content-available: 1 → iOS wake app → mySilentDataHandle tạo notification với Nghe/Từ chối
      const response = await sendCallFcmNotification({
        token: fcmToken,
        title: `📞 Cuộc gọi ${callType} đến`,
        body: `${callerName} đang gọi cho bạn`,
        data: { type: 'call', matchId, callType, peerUserId: afterData.callerId, peerUsername: callerName },
      });
      console.log('Call notification sent:', response);
    } catch (e) {
      console.error('sendCallNotification error:', e);
    }
  }
);

// ─────────────────────────────────────────────
// 3. sendMomentReactionNotification
//    Trigger: moments/{momentId} — document được cập nhật
//    Detect khi reactions array có thêm phần tử mới
// ─────────────────────────────────────────────
exports.sendMomentReactionNotification = onDocumentUpdated(
  'moments/{momentId}',
  async (event) => {
    try {
      const before = event.data.before.data();
      const after = event.data.after.data();
      const momentId = event.params.momentId;

      const beforeReactions = before.reactions || [];
      const afterReactions = after.reactions || [];

      // Không có reaction mới → bỏ qua
      if (afterReactions.length <= beforeReactions.length) return;

      // Lấy reaction mới nhất (vừa được thêm vào)
      const newReaction = afterReactions[afterReactions.length - 1];
      const momentOwnerId = after.userId;

      // Bỏ qua nếu tự react vào moment của mình
      if (newReaction.userId === momentOwnerId) return console.log('Self reaction — skip');

      const db = admin.firestore();

      // Lấy FCM token chủ moment
      const ownerDoc = await db.collection('users').doc(momentOwnerId).get();
      if (!ownerDoc.exists) return console.log('Moment owner not found');
      const fcmToken = ownerDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token for owner');

      // Lấy tên người react
      const reactorDoc = await db.collection('users').doc(newReaction.userId).get();
      const reactorName = reactorDoc.exists ? reactorDoc.data()?.username || 'Someone' : 'Someone';

      const emoji = newReaction.emoji || '❤️';
      const response = await sendFcmNotification({
        token: fcmToken,
        title: `${reactorName} đã thả ${emoji}`,
        body: 'vào moment của bạn',
        channelId: 'moment_channel',
        data: {
          type: 'moment_reaction',
          momentId,
          reactorUserId: newReaction.userId,
          reactorUsername: reactorName,
          emoji,
          momentOwnerId,
        },
      });
      console.log('Moment reaction notification sent:', response);
    } catch (e) {
      console.error('sendMomentReactionNotification error:', e);
    }
  }
);

// ─────────────────────────────────────────────
// 4. sendLikeNotification
//    Trigger: swipe_history/{swipeId} — document mới
//    Gửi thông báo khi có người like mình (action = 'like')
// ─────────────────────────────────────────────
exports.sendLikeNotification = onDocumentCreated(
  'swipe_history/{swipeId}',
  async (event) => {
    try {
      const swipe = event.data?.data();
      if (!swipe) return;

      // Chỉ xử lý khi là 'like', bỏ qua 'dislike'
      if (swipe.action !== 'like') return console.log('Not a like — skip');

      const targetUserId = swipe.targetUserId;  // Người được like
      const likerUserId = swipe.userId;          // Người like

      const db = admin.firestore();

      // Lấy FCM token người được like
      const targetDoc = await db.collection('users').doc(targetUserId).get();
      if (!targetDoc.exists) return console.log('Target user not found');
      const fcmToken = targetDoc.data()?.fcmToken;
      if (!fcmToken) return console.log('No FCM token for target');

      // Lấy tên người like
      const likerDoc = await db.collection('users').doc(likerUserId).get();
      const likerName = likerDoc.exists ? likerDoc.data()?.username || 'Ai đó' : 'Ai đó';

      const response = await sendFcmNotification({
        token: fcmToken,
        title: '💖 Có người thích bạn!',
        body: `${likerName} vừa thích bạn — Ghé xem ngay nhé!`,
        channelId: 'gamenect_channel',
        data: { type: 'like', likerUserId, likerUsername: likerName },
      });
      console.log('Like notification sent:', response);
    } catch (e) {
      console.error('sendLikeNotification error:', e);
    }
  }
);

// ─────────────────────────────────────────────
// 5. sendLiveNotification
//    Trigger: livestreams/{streamId} — document mới được tạo
//    Gửi thông báo cho tất cả followers của Mentor khi họ bắt đầu live
// ─────────────────────────────────────────────
exports.sendLiveNotification = onDocumentCreated(
  'livestreams/{streamId}',
  async (event) => {
    try {
      const snap = event.data;
      if (!snap) return;

      const stream = snap.data();
      const streamId = event.params.streamId;

      // Chỉ xử lý khi status là 'live'
      if (stream.status !== 'live') return;

      const mentorId = stream.mentorId;
      const mentorUsername = stream.mentorUsername || 'Mentor';
      const title = stream.title || 'Đang livestream';

      const db = admin.firestore();

      // Lấy danh sách followers của Mentor
      const followersSnap = await db
        .collection('mentor_followers')
        .where('mentorId', '==', mentorId)
        .get();

      if (followersSnap.empty) {
        console.log(`No followers for mentor ${mentorId}`);
        return;
      }

      const followerIds = followersSnap.docs.map(d => d.data().followerId).filter(Boolean);
      console.log(`Sending live notification to ${followerIds.length} followers`);

      // Gửi FCM cho từng follower (batch max 500 theo giới hạn FCM)
      const batchSize = 100;
      for (let i = 0; i < followerIds.length; i += batchSize) {
        const batch = followerIds.slice(i, i + batchSize);

        // Lấy FCM tokens
        const userDocs = await Promise.all(
          batch.map(uid => db.collection('users').doc(uid).get())
        );

        const sendPromises = userDocs
          .filter(doc => doc.exists && doc.data()?.fcmToken)
          .map(doc => sendFcmNotification({
            token: doc.data().fcmToken,
            title: `🔴 ${mentorUsername} đang LIVE!`,
            body: title,
            channelId: 'mentor_live_channel',
            data: {
              type: 'mentor_live',
              streamId,
              mentorId,
              mentorUsername,
              streamTitle: title,
            },
          }).catch(e => console.warn(`Failed to send to ${doc.id}: ${e.message}`)));

        await Promise.allSettled(sendPromises);
      }

      console.log(`Live notification sent for stream ${streamId}`);
    } catch (e) {
      console.error('sendLiveNotification error:', e);
    }
  }
);