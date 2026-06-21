/**
 * Auto-like system — 2 functions:
 * 
 * 1. scheduleNewUserLikes (onDocumentCreated):
 *    - Trigger ngay khi có user mới đăng ký
 *    - Tạo 5-7 "hẹn giờ like" trong collection like_queue
 *    - Mỗi hẹn giờ có thời điểm ngẫu nhiên trong 70 phút tới
 * 
 * 2. processLikeQueue (cron mỗi phút):
 *    - Xử lý các hẹn giờ đã đến hạn
 *    - Ghi vào swipe_latest + swipe_history
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

const LIKES_MIN = 5;
const LIKES_MAX = 7;
const WINDOW_MINUTES = 70;

// ─── FUNCTION 1: Khi user mới đăng ký → lên lịch like ngẫu nhiên ─────────────
exports.scheduleNewUserLikes = onDocumentCreated(
  {
    document: "users/{userId}",
    region: "asia-southeast1",
  },
  async (event) => {
    const db = admin.firestore();
    const userData = event.data.data();

    // Bỏ qua bot và admin
    if (userData.botVersion || userData.isAdmin || !userData.username) return;

    console.log(`👤 User mới: ${userData.username || event.params.userId}`);

    // Lấy pool bot
    const botSnap = await db.collection("users")
      .where("botVersion", "==", "v5_perfect")
      .limit(200)
      .get();

    const botIds = botSnap.docs.map(d => d.id);
    if (botIds.length === 0) return;

    // Chọn 5-7 bot ngẫu nhiên
    const count = Math.floor(Math.random() * (LIKES_MAX - LIKES_MIN + 1)) + LIKES_MIN;
    const shuffled = [...botIds].sort(() => Math.random() - 0.5);
    const pickedBots = shuffled.slice(0, count);

    const now = Date.now();
    const batch = db.batch();

    for (let i = 0; i < pickedBots.length; i++) {
      const botId = pickedBots[i];
      // Like đầu tiên: đúng 5 phút sau khi đăng ký
      // Các like còn lại: ngẫu nhiên trong 70 phút (nhưng sau 5 phút đầu)
      const delayMs = i === 0
        ? 5 * 60 * 1000
        : 5 * 60 * 1000 + Math.floor(Math.random() * (WINDOW_MINUTES - 5) * 60 * 1000);
      const scheduledAt = admin.firestore.Timestamp.fromMillis(now + delayMs);

      const ref = db.collection("like_queue").doc();
      batch.set(ref, {
        targetUserId: event.params.userId,
        botId: botId,
        scheduledAt: scheduledAt,
        done: false,
        createdAt: admin.firestore.Timestamp.fromMillis(now),
      });
    }

    await batch.commit();
    console.log(`✅ Đã lên lịch ${count} bot likes ngẫu nhiên trong ${WINDOW_MINUTES} phút tới cho ${userData.username || event.params.userId}`);
  }
);

// ─── FUNCTION 2: Xử lý queue mỗi phút ────────────────────────────────────────
exports.processLikeQueue = onSchedule(
  {
    schedule: "* * * * *",           // Mỗi phút
    timeZone: "Asia/Ho_Chi_Minh",
    region: "asia-southeast1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 60 * 24 * 60 * 60 * 1000 // TTL 60 ngày
    );

    // Lấy các hẹn giờ đã đến hạn
    const dueSnap = await db.collection("like_queue")
      .where("scheduledAt", "<=", now)
      .where("done", "==", false)
      .limit(50)
      .get();

    if (dueSnap.empty) return;

    console.log(`⏰ Xử lý ${dueSnap.size} like hẹn giờ...`);

    for (const doc of dueSnap.docs) {
      const { targetUserId, botId } = doc.data();

      try {
        // Kiểm tra chưa like
        const existing = await db.collection("swipe_latest")
          .doc(`${botId}_${targetUserId}`)
          .get();

        if (!existing.exists) {
          const writeBatch = db.batch();

          writeBatch.set(
            db.collection("swipe_latest").doc(`${botId}_${targetUserId}`),
            { userId: botId, targetUserId, action: "like", timestamp: now }
          );

          writeBatch.set(db.collection("swipe_history").doc(), {
            userId: botId,
            targetUserId,
            action: "like",
            timestamp: now,
            expiresAt,
          });

          // Đánh dấu done
          writeBatch.update(doc.ref, { done: true });
          await writeBatch.commit();

          console.log(`❤️ Bot ${botId} → liked ${targetUserId}`);
        } else {
          // Đã like rồi, chỉ đánh dấu done
          await doc.ref.update({ done: true });
        }
      } catch (err) {
        console.error(`❌ Lỗi xử lý like: ${err.message}`);
      }
    }

    // Dọn queue cũ (done=true quá 7 ngày)
    const oldDoneSnap = await db.collection("like_queue")
      .where("done", "==", true)
      .where("createdAt", "<=", admin.firestore.Timestamp.fromMillis(now.toMillis() - 7 * 24 * 60 * 60 * 1000))
      .limit(100)
      .get();

    if (!oldDoneSnap.empty) {
      const cleanBatch = db.batch();
      oldDoneSnap.docs.forEach(d => cleanBatch.delete(d.ref));
      await cleanBatch.commit();
      console.log(`🗑️ Dọn ${oldDoneSnap.size} queue entries cũ`);
    }
  }
);
