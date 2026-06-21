/**
 * botDailySwipe — Scheduled Cloud Function (chạy mỗi ngày lúc 9h sáng)
 *
 * Mỗi bot v5_perfect (còn trong 7 ngày đầu kể từ khi tạo):
 * - Quẹt 10 user thật ngẫu nhiên xung quanh vị trí bot
 * - 70% like, 30% dislike
 * - Nếu không đủ 10 người trong bán kính hiện tại → mở rộng dần
 * - Bỏ qua những người đã quẹt rồi
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const BOT_ACTIVE_DAYS = 7;         // Bot chỉ swipe trong 7 ngày đầu
const SWIPES_PER_DAY = 10;         // 10 swipes/ngày
// LIKE_RATIO: ngẫu nhiên per-bot (50-90%), xem bên dưới
const RADII_KM = [50, 100, 200, 500]; // Bán kính tìm kiếm, mở rộng nếu thiếu người

function latLngBoundingBox(lat, lng, radiusKm) {
  const latDelta = radiusKm / 111.0;
  const lngDelta = radiusKm / (111.0 * Math.cos((lat * Math.PI) / 180));
  return {
    minLat: lat - latDelta,
    maxLat: lat + latDelta,
    minLng: lng - lngDelta,
    maxLng: lng + lngDelta,
  };
}

exports.botDailySwipe = onSchedule(
  {
    schedule: "0 9 * * *",           // Mỗi ngày lúc 9h sáng
    timeZone: "Asia/Ho_Chi_Minh",
    region: "asia-southeast1",
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    // CHỈ CHẠY TRONG 10 NGÀY (từ 21/06/2026 đến 01/07/2026)
    const CUTOFF_DATE = new Date("2026-07-01T23:59:59+07:00").getTime();
    if (now.toMillis() > CUTOFF_DATE) {
      console.log("Đã hết thời hạn 10 ngày chạy auto swipe. Function sẽ không làm gì cả.");
      return;
    }

    const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - BOT_ACTIVE_DAYS * 24 * 60 * 60 * 1000
    );
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 60 * 24 * 60 * 60 * 1000
    );

    // 1. Lấy danh sách bot còn trong 7 ngày đầu
    const botSnap = await db.collection("users")
      .where("botVersion", "==", "v5_perfect")
      .where("createdAt", ">=", sevenDaysAgo)
      .get();

    if (botSnap.empty) {
      console.log("Không có bot nào còn trong 7 ngày đầu.");
      return;
    }

    console.log(`🤖 Có ${botSnap.size} bot đang active (≤ 7 ngày tuổi)`);

    let totalSwipes = 0;

    for (const botDoc of botSnap.docs) {
      const bot = botDoc.data();
      const botId = botDoc.id;
      const lat = bot.latitude;
      const lng = bot.longitude;

      if (!lat || !lng) {
        console.log(`⚠️ Bot ${bot.username} thiếu vị trí, bỏ qua.`);
        continue;
      }

      // Lấy danh sách user đã quẹt bởi bot này
      const alreadySwiped = new Set();
      const swipedSnap = await db.collection("swipe_latest")
        .where("userId", "==", botId)
        .get();
      swipedSnap.docs.forEach(d => alreadySwiped.add(d.data().targetUserId));

      // Tìm user thật xung quanh, mở rộng bán kính nếu không đủ
      let candidates = [];
      for (const radiusKm of RADII_KM) {
        const box = latLngBoundingBox(lat, lng, radiusKm);

        const nearbySnap = await db.collection("users")
          .where("latitude", ">=", box.minLat)
          .where("latitude", "<=", box.maxLat)
          .limit(200)
          .get();

        // Lọc: user thật, chưa quẹt, không phải chính bot
        const filtered = nearbySnap.docs.filter(d => {
          const data = d.data();
          return (
            d.id !== botId &&
            !data.botVersion &&
            !data.isAdmin &&
            data.username &&
            !alreadySwiped.has(d.id) &&
            data.longitude >= box.minLng &&
            data.longitude <= box.maxLng
          );
        });

        candidates = filtered;

        if (candidates.length >= SWIPES_PER_DAY) break;

        console.log(`   📍 Bot ${bot.username}: ${candidates.length} người trong ${radiusKm}km → mở rộng...`);
      }

      if (candidates.length === 0) {
        console.log(`   ❌ Bot ${bot.username}: không tìm được ai để quẹt.`);
        continue;
      }

      // Mỗi bot có % like riêng ngẫu nhiên (50%-90%)
      const likeRatio = 0.5 + Math.random() * 0.4;

      // Shuffle và lấy tối đa SWIPES_PER_DAY người
      const toSwipe = candidates
        .sort(() => Math.random() - 0.5)
        .slice(0, SWIPES_PER_DAY);

      const batch = db.batch();
      let likeCount = 0;
      let dislikeCount = 0;

      for (const targetDoc of toSwipe) {
        const targetId = targetDoc.id;
        const action = Math.random() < likeRatio ? "like" : "dislike";
        if (action === "like") likeCount++; else dislikeCount++;

        // swipe_latest
        batch.set(db.collection("swipe_latest").doc(`${botId}_${targetId}`), {
          userId: botId,
          targetUserId: targetId,
          action,
          timestamp: now,
        });

        // swipe_history
        batch.set(db.collection("swipe_history").doc(), {
          userId: botId,
          targetUserId: targetId,
          action,
          timestamp: now,
          expiresAt,
        });
      }

      await batch.commit();
      totalSwipes += toSwipe.length;
      console.log(`   ✅ ${bot.username}: ❤️ ${likeCount} like + 👎 ${dislikeCount} dislike`);
    }

    console.log(`\n✅ botDailySwipe hoàn thành — tổng ${totalSwipes} swipes hôm nay.`);
  }
);
