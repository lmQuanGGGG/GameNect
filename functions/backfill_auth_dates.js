const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function backfill() {
  console.log('Bắt đầu đồng bộ ngày tạo tài khoản từ Firebase Auth sang Firestore...');
  let nextPageToken;
  let count = 0;
  let placeholderCount = 0;

  do {
    const listUsersResult = await auth.listUsers(1000, nextPageToken);
    for (const userRecord of listUsersResult.users) {
      const uid = userRecord.uid;
      const createdAtStr = userRecord.metadata.creationTime; // Ngày tạo tài khoản đăng nhập từ Auth
      const createdAtDate = new Date(createdAtStr);
      const createdAtIso = createdAtDate.toISOString();

      const userRef = db.collection('users').doc(uid);
      const doc = await userRef.get();

      if (doc.exists) {
        const data = doc.data();
        if (!data.createdAt) {
          await userRef.update({
            createdAt: createdAtIso
          });
          console.log(`[CẬP NHẬT] User: ${uid} (${userRecord.email || userRecord.phoneNumber || 'Không rõ'}) -> Đăng ký: ${createdAtIso}`);
          count++;
        }
      } else {
        // Tạo tài liệu tạm thời (placeholder) cho người đăng ký Auth nhưng chưa tạo thông tin onboarding
        const email = userRecord.email || '';
        await userRef.set({
          id: uid,
          email: userRecord.email || null,
          phoneNumber: userRecord.phoneNumber || null,
          createdAt: createdAtIso,
          isTestAccount: email.endsWith('@gamenect.com'),
          username: '',
          favoriteGames: [],
          rank: 'Gà Mờ',
          location: 'Không xác định',
          playTime: 0,
          winRate: 0,
          points: 0,
          avatarUrl: null,
          additionalPhotos: [],
          gender: 'Khác',
          age: 18,
          height: 160,
          bio: '',
          interests: [],
          lookingFor: 'Bạn chơi game',
          gameStyle: 'Casual',
          dateOfBirth: new Date(new Date().setFullYear(new Date().getFullYear() - 18)).toISOString()
        });
        console.log(`[TẠO MỚI PLACEHOLDER] User: ${uid} (${userRecord.email || userRecord.phoneNumber || 'Không rõ'}) -> Đăng ký: ${createdAtIso}`);
        placeholderCount++;
      }
    }
    nextPageToken = listUsersResult.pageToken;
  } while (nextPageToken);

  console.log('\n--- KẾT QUẢ ĐỒNG BỘ ---');
  console.log(`• Đã cập nhật ngày đăng ký cho ${count} tài khoản cũ.`);
  console.log(`• Đã tạo placeholder cho ${placeholderCount} tài khoản chưa hoàn tất onboarding.`);
  console.log('Đồng bộ hoàn tất thành công!');
}

backfill().catch(err => {
  console.error('Lỗi trong quá trình đồng bộ:', err);
});
