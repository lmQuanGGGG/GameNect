const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

// Random số lượng người đăng mỗi ngày (từ 1 đến 4 người)
const MIN_POST = 1;
const MAX_POST = 4;

// Random số tim cho bài đăng mới (8 đến 29)
const MIN_LIKES = 8;
const MAX_LIKES = 29;

exports.botDailyMentorPost = onSchedule(
  {
    schedule: "0 15 * * *", // Chạy mỗi ngày vào lúc 15:00 (giờ máy chủ)
    timeZone: "Asia/Ho_Chi_Minh",
    memory: "256MiB",
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    console.log("Bắt đầu botDailyMentorPost...");

    // 1. Lấy tất cả bot đang là mentor
    const mentorsSnap = await db.collection("users")
      .where("botVersion", "==", "v5_perfect")
      .where("mentorStatus", "==", "approved")
      .get();

    if (mentorsSnap.empty) {
      console.log("Không có bot mentor nào để đăng bài.");
      return;
    }

    let mentors = mentorsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    // Xáo trộn mảng mentor để chọn ngẫu nhiên
    mentors.sort(() => Math.random() - 0.5);

    const targetPostCount = Math.floor(Math.random() * (MAX_POST - MIN_POST + 1)) + MIN_POST;
    let postedCount = 0;

    for (const mentor of mentors) {
      if (postedCount >= targetPostCount) break;

      try {
        // Kiểm tra bài đăng gần nhất của mentor này
        const lastMediaSnap = await db.collection("mentor_media")
          .where("mentorId", "==", mentor.id)
          .orderBy("createdAt", "desc")
          .limit(1)
          .get();

        if (!lastMediaSnap.empty) {
          const lastPostDate = lastMediaSnap.docs[0].data().createdAt.toMillis();
          const daysSinceLastPost = (now.toMillis() - lastPostDate) / (1000 * 60 * 60 * 24);
          
          // Phải cách ít nhất 4 ngày mới được đăng tiếp
          if (daysSinceLastPost < 4) {
            continue; // Bỏ qua người này, tìm người khác
          }
        }

        // Kiểm tra số bài đã đăng trong tháng này (không quá 10 bài)
        const currentMonth = `${now.toDate().getFullYear()}-${String(now.toDate().getMonth() + 1).padStart(2, "0")}`;
        const thisMonthPostsSnap = await db.collection("mentor_media")
          .where("mentorId", "==", mentor.id)
          .where("month", "==", currentMonth)
          .get();

        if (thisMonthPostsSnap.size >= 10) {
          console.log(`⚠️ Bot ${mentor.username} đã đạt giới hạn 10 bài trong tháng ${currentMonth}. Bỏ qua.`);
          continue;
        }

        // Lấy kho ảnh của mentor này
        const poolDoc = await db.collection("bot_photos_pool").doc(mentor.id).get();
        const poolPhotos = poolDoc.exists ? (poolDoc.data().photos || []) : [];

        // Lọc những ảnh chưa đăng (dù đã xóa ở lần trước nhưng cẩn thận filter lại)
        const postedSnap = await db.collection("mentor_media")
          .where("mentorId", "==", mentor.id)
          .get();
        const postedUrls = new Set(postedSnap.docs.map(d => d.data().url));
        
        const availablePhotos = poolPhotos.filter(url => !postedUrls.has(url));

        if (availablePhotos.length === 0) {
          // Hết ảnh của bản thân rồi thì dừng không đăng nữa (để tự nhiên)
          continue; 
        }

        // Đủ điều kiện đăng bài: bốc 1 ảnh chưa đăng
        const photoUrl = availablePhotos[Math.floor(Math.random() * availablePhotos.length)];
        
        // Tạo lượng tim ảo ngẫu nhiên (8-29)
        const likeCount = Math.floor(Math.random() * (MAX_LIKES - MIN_LIKES + 1)) + MIN_LIKES;
        const fakeLikes = [];
        for (let i = 0; i < likeCount; i++) {
          fakeLikes.push(`fake_user_${Math.random().toString(36).substring(2, 10)}`);
        }

        const postDate = new Date(now.toMillis() - Math.floor(Math.random() * 2 * 60 * 60 * 1000)); // Lùi lại 1-2 tiếng cho tự nhiên

        await db.collection("mentor_media").add({
          mentorId: mentor.id,
          type: "image",
          url: photoUrl,
          thumbnailUrl: null,
          caption: "", // Có thể set caption nếu muốn
          duration: null,
          month: `${postDate.getFullYear()}-${String(postDate.getMonth() + 1).padStart(2, "0")}`,
          createdAt: admin.firestore.Timestamp.fromDate(postDate),
          likes: fakeLikes,
        });

        // Xóa ảnh đã dùng khỏi pool để không bị lặp
        await db.collection("bot_photos_pool").doc(mentor.id).update({
          photos: admin.firestore.FieldValue.arrayRemove(photoUrl),
        });

        console.log(`📸 Bot mentor [${mentor.username}] đã đăng 1 ảnh mới (còn ${availablePhotos.length - 1} ảnh). Tim ảo: ${likeCount}`);
        postedCount++;

      } catch (err) {
        console.error(`❌ Lỗi khi đăng bài cho mentor ${mentor.username}:`, err.message);
      }
    }

    console.log(`✅ Hoàn thành botDailyMentorPost. Đã đăng cho ${postedCount} / ${targetPostCount} mục tiêu.`);
  }
);
