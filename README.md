# GameNect 🎮 - Ứng dụng Kết nối & Hẹn hò cho Game thủ chuyên nghiệp

[![Gamenect App](https://img.shields.io/badge/Platform-Flutter%20%7C%20Dart-blue.svg)](https://flutter.dev)
[![Database-Firebase](https://img.shields.io/badge/Backend-Firebase-orange.svg)](https://firebase.google.com)
[![Website-Netlify](https://img.shields.io/badge/Website-Netlify-green.svg)](https://incandescent-pavlova-a73522.netlify.app/)
[![License](https://img.shields.io/badge/License-ISC-red.svg)](https://opensource.org/licenses/ISC)

**GameNect** là nền tảng mạng xã hội hẹn hò và kết nối độc đáo dành riêng cho cộng đồng game thủ. Thiết kế hiện đại giúp người dùng dễ dàng tìm kiếm bạn chơi cùng, theo dõi các buổi Livestream, chia sẻ khoảnh khắc qua Moments (Stories), giao dịch nạp/rút tiền xu (Coin) và đăng ký trở thành Mentor để chia sẻ kinh nghiệm chiến đấu.

🌐 **Website chính thức:** [https://incandescent-pavlova-a73522.netlify.app](https://incandescent-pavlova-a73522.netlify.app/)

---

## 🚀 Tính năng nổi bật

### 1. Kết nối & Swipe Match (Tinder-Style)
* **Vuốt chọn bạn chơi:** Cơ chế vuốt Trái/Phải thông minh để Like hoặc Dislike dựa trên mức độ tương thích và các tựa game yêu thích.
* **Match thông minh:** Khi cả hai cùng Like, cặp đôi sẽ được ghép nối (Match) và mở khóa giao diện Chat.
* **Tích hợp thuật toán ML:** Sử dụng recommendation engine (host tại Railway) để đề xuất đối tượng phù hợp nhất dựa trên kỹ năng, vị trí địa lý và rank.

### 2. Giao tiếp Thời gian thực (Realtime Chat & Call)
* **Trò chuyện đa phương tiện:** Nhắn tin văn bản, biểu cảm emoji, chia sẻ ảnh/video và gửi tin nhắn thoại sinh động.
* **Đàm thoại chất lượng cao:** Tích hợp cuộc gọi Video và Voice call chất lượng HD độ trễ cực thấp sử dụng **Agora RTC Engine**.
* **Đèn báo trạng thái:** Hiển thị thời gian thực trạng thái đang gõ chữ (typing indicator) và trạng thái hoạt động.

### 3. Moments (Stories & Khoảnh khắc)
* **Chụp & Quay ngay trên app:** Hỗ trợ camera đa tính năng (flash, zoom, lật camera trước, exposure) để ghi lại những pha highlight đặc sắc.
* **Chia sẻ độc quyền:** Story chỉ hiển thị với những người đã ghép đôi (Matched users).
* **Tương tác cảm xúc:** Người xem có thể thả tim, phản hồi Story trực tiếp qua tin nhắn.

### 4. Livestreaming & Mentor Management
* **Livestream TikTok-Style:** Vuốt dọc để khám phá các phòng live của Mentor đang phát trực tiếp cực mượt mà.
* **Hệ thống Mentor:** Cho phép người dùng ứng tuyển làm Mentor. Hồ sơ ứng viên được quản lý và kiểm duyệt trực tiếp bởi Admin.
* **Gửi quà tặng (Gifting):** Người xem stream có thể gửi quà trực tiếp bằng Coin để ủng hộ Mentor yêu thích.

### 5. Hệ thống Ví (Wallet) & Cổng thanh toán PayOS
* **Nạp Coin siêu tốc:** Tích hợp cổng thanh toán nội địa VN **PayOS** giúp nạp Coin vào ví tiện lợi.
* **Rút tiền cho Mentor:** Mentor có thể tạo lệnh rút Coin tích lũy về tài khoản ngân hàng cá nhân, được phê duyệt thủ công bởi Admin qua hệ thống QR tự động sinh.
* **Gói Premium:** Nâng cấp tài khoản Premium để mở khóa các đặc quyền: xem ai đã thích mình, không giới hạn lượt vuốt, tăng tốc độ đề xuất (boost).

---

## 🛠️ Công nghệ sử dụng

| Layer | Công nghệ | Chi tiết |
| --- | --- | --- |
| **Mobile Client** | Flutter / Dart | Đa nền tảng (iOS & Android) |
| **Backend & Auth** | Firebase Suite | Auth, Cloud Firestore, Storage, Crashlytics, Analytics |
| **Serverless** | Cloud Functions | Node.js (Webhooks, Notification scheduler) |
| **Livestream & Calls** | Agora RTC | Agora SDK cho cuộc gọi và stream thời gian thực |
| **Payment Gateway** | PayOS | Cổng thanh toán trực tuyến nội địa Việt Nam |
| **Website & Landing** | Netlify / HTML5 | Hosting trang landing giới thiệu & Redirect thanh toán |

---

## 📋 Yêu cầu hệ thống

> [!IMPORTANT]
> Hãy chắc chắn rằng máy tính của bạn đã cài đặt đầy đủ môi trường phát triển Flutter trước khi bắt đầu.

- Flutter SDK: `^3.8.1`
- Dart SDK: `^3.8.1`
- Android SDK (API level 21+) hoặc Xcode 15+ (cho iOS)
- Thiết bị thật hoặc Simulator/Emulator có kết nối mạng ổn định
- Môi trường phát triển: macOS (Khuyến nghị để có thể build cả Android và iOS)

---

## ⚙️ Cài đặt & Chạy ứng dụng

### 1. Tải Dependencies
Mở terminal tại thư mục dự án và chạy:
```bash
flutter pub get
```

### 2. Cấu hình biến môi trường
Tạo file `.env` tại thư mục gốc của dự án với các thông số sau:
```properties
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_APP_ID=your_firebase_app_id
FIREBASE_PROJECT_ID=your_firebase_project_id
RAWG_API_KEY=your_rawg_api_key
AGORA_APP_ID=your_agora_app_id
PAYOS_CLIENT_ID=your_payos_client_id
PAYOS_API_KEY=your_payos_api_key
PAYOS_CHECKSUM_KEY=your_payos_checksum_key
```

### 3. Cài đặt Firebase Configuration
Tải file `google-services.json` (Android) từ Firebase Console và đặt vào thư mục `android/app/`. 
Đối với iOS, tải `GoogleService-Info.plist` và kéo vào Xcode project.

### 4. Khởi chạy dự án
Chạy lệnh sau để kiểm tra thiết bị và khởi động chế độ debug:
```bash
flutter run
```

---

## 📦 Cấu trúc dự án chính

```
lib/
├── main.dart               # Entry point ứng dụng, cấu hình Provider toàn cục, định tuyến chính
├── admin/                  # Module quản trị viên (Admin Panel)
│   ├── admin_app.dart      # Điểm bắt đầu của Admin app
│   └── screens/            # Màn hình quản lý người dùng, duyệt đơn Mentor, duyệt rút tiền
├── user/                   # Module dành cho người dùng thông thường
│   ├── user_app.dart       # Quản lý định tuyến và giao diện chính cho User
│   └── screens/            # Màn hình chat, match, moments, wallet, livestream, premium
└── core/                   # Module lõi dùng chung cho toàn dự án
    ├── models/             # Định nghĩa cấu trúc dữ liệu (UserModel, MatchModel, v.v.)
    ├── services/           # Kết nối Firebase, Agora, PayOS, RAWG API
    └── providers/          # Quản lý trạng thái và luồng dữ liệu (State Management)
```

---

## 🔒 Bảo mật & Quy chuẩn phát hành

* **Xử lý Proguard/R8:** Đã cấu hình keep rules cho TensorFlow Lite, Firebase, và các thư viện media trong file `android/app/proguard-rules.pro` để chống dịch ngược và tối ưu hóa dung lượng ứng dụng.
* **Chính sách bảo mật:** Ứng dụng tuân thủ nghiêm ngặt các điều khoản bảo mật thông tin cá nhân của người dùng, đặc biệt là quyền truy cập Camera, Microphone và Vị trí (GPS).

---

## 🌐 SEO & Thông tin liên hệ

* **Keywords:** GameNect, tinder cho game thủ, app hẹn hò game thủ, tìm bạn chơi game, livestream game, thuê mentor game, nạp coin cổng PayOS, hẹn hò gamer Việt Nam.
* **Website:** [https://gamenect-9bec0.web.app/](hhttps://gamenect-9bec0.web.app/)
* **Repository:** [https://github.com/lmQuanGGGG/GameNect](https://github.com/lmQuanGGGG/GameNect)

---
> [!TIP]
> Để nâng cấp lên tài khoản Premium hoặc nạp tiền xu (Coin) phục vụ tặng quà Mentor, hãy truy cập trực tiếp vào tính năng Ví trên ứng dụng di động hoặc thực hiện thanh toán qua link liên kết của PayOS.
