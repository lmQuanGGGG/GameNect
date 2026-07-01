const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

exports.botAutoLikeMentorPost = onSchedule(
  {
    schedule: "0 * * * *", // Chạy mỗi giờ một lần
    timeZone: "Asia/Ho_Chi_Minh",
    memory: "256MiB",
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const oneDayAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);

    console.log("Bắt đầu botAutoLikeMentorPost...");

    try {
      // 1. Lấy tất cả các bài đăng trong 24h qua
      const recentMediaSnap = await db.collection("mentor_media")
        .where("createdAt", ">=", oneDayAgo)
        .get();

      if (recentMediaSnap.empty) {
        console.log("Không có bài đăng mới nào trong 24h qua.");
        return;
      }

      // 2. Lấy danh sách ID của bot v5_perfect để làm "liker"
      const v5Snap = await db.collection("users")
        .where("botVersion", "==", "v5_perfect")
        .get();
      
      const botIds = v5Snap.docs.map(doc => doc.id);
      if (botIds.length === 0) {
         console.log("Không có bot v5_perfect nào để like.");
         return;
      }

      let updatedCount = 0;
      const batch = db.batch();

      // 3. Duyệt qua từng bài đăng mới
      recentMediaSnap.forEach(doc => {
        const data = doc.data();
        const createdAtMillis = data.createdAt.toMillis();
        // Tính số giờ đã trôi qua kể từ khi đăng (từ 1 đến 24 giờ)
        const hoursPassed = Math.min(24, Math.max(1, (now.toMillis() - createdAtMillis) / (1000 * 60 * 60)));

        // Tính mục tiêu thả tim dựa trên hash của doc.id (để random nhưng cố định cho mỗi bài đăng)
        const hash = doc.id.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
        const targetLikes = 7 + (hash % 31); // Trả về số từ 7 đến 37

        // Số tim kỳ vọng tại thời điểm hiện tại (tăng dần tuyến tính theo thời gian)
        const expectedLikesAtThisHour = Math.floor((hoursPassed / 24) * targetLikes);
        
        let currentLikes = data.likes || [];
        
        // (Tùy chọn) Xóa bớt tim ảo cũ nếu đang có
        currentLikes = currentLikes.filter(id => !id.startsWith("fake_user_"));

        // Kiểm tra xem số tim hiện tại đã đạt kỳ vọng của giờ này chưa
        if (currentLikes.length < expectedLikesAtThisHour) {
          const likesToAddCount = expectedLikesAtThisHour - currentLikes.length;
          let added = 0;
          let attempts = 0;
          
          while (added < likesToAddCount && attempts < 50) {
            const randomBotId = botIds[Math.floor(Math.random() * botIds.length)];
            // Đảm bảo bot không tự like chính mình và chưa like bài này
            if (randomBotId !== data.mentorId && !currentLikes.includes(randomBotId)) {
              currentLikes.push(randomBotId);
              added++;
            }
            attempts++;
          }

          if (added > 0) {
            batch.update(doc.ref, { likes: currentLikes });
            updatedCount++;
          }
        }
      });

      if (updatedCount > 0) {
        await batch.commit();
        console.log(`Đã bơm thêm tim thành công cho ${updatedCount} bài đăng.`);
      } else {
        console.log("Không có bài đăng nào cần bơm thêm tim trong giờ này (tiến độ đã đạt yêu cầu).");
      }

    } catch (e) {
      console.error("Lỗi botAutoLikeMentorPost:", e);
    }
  }
);
