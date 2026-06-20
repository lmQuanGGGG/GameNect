# AGENT DOCS — GameNect (gamenect_new)

> **Mục đích:** Tài liệu này dành cho AI agent đọc trước khi code. Mô tả toàn bộ dự án, mỗi file làm gì, thư viện nào dùng ở đâu, cấu hình như thế nào.

---

## 1. TỔNG QUAN DỰ ÁN

**GameNect** là ứng dụng mobile **hẹn hò theo phong cách gaming** — kết nối game thủ dựa trên game yêu thích, vị trí địa lý, và độ tương thích. Core flow giống Tinder nhưng dành cho gamer.

### Các tính năng chính:
- Swipe like/dislike người dùng khác → tạo match khi cả hai cùng like
- Đề xuất match từ ML API bên ngoài (Railway)
- Chat realtime (text, ảnh, video, voice, emoji react)
- Video call / Voice call qua Agora RTC
- Moments (Stories ảnh/video) — chỉ hiển thị cho matched users
- Push notification (FCM + AwesomeNotifications)
- Subscription Premium qua PayOS (thanh toán nội địa VN)
- Admin panel quản lý user và cấu hình gói Premium
- Xem game trending, chi tiết game từ RAWG API

### Stack:
| Layer | Công nghệ |
|---|---|
| Mobile App | Flutter (Dart SDK ^3.8.1) |
| Database / Auth / Storage | Firebase (Firestore, Auth, Storage, Crashlytics, Analytics) |
| Push Notification | Firebase Cloud Messaging + AwesomeNotifications |
| Backend Functions | Firebase Cloud Functions (Node.js) |
| Video / Voice Call | Agora RTC Engine |
| ML Recommend API | REST API tại `https://web-production-188ce.up.railway.app/recommend` |
| Payment | PayOS API (thanh toán nội địa VN) |
| Game Data | RAWG.io API |
| State Management | Provider |

---

## 2. CẤU TRÚC THƯ MỤC

```
gamenect_new/
├── lib/
│   ├── main.dart                    # Entry point, khởi tạo app, routing, notification handlers
│   ├── firebase_options.dart        # Auto-generated Firebase config cho Android/iOS/Web
│   ├── admin/                       # Module Admin
│   │   ├── admin_app.dart           # Root widget của admin, routing admin
│   │   ├── screens/                 # Màn hình admin
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── subscription_config_screen.dart
│   │   │   └── user_management_screen.dart
│   │   └── widgets/                 # Widgets dùng riêng cho admin
│   ├── user/                        # Module User (người dùng thông thường)
│   │   ├── user_app.dart            # Root widget của user, routing user
│   │   ├── screens/                 # Màn hình user (21 files)
│   │   └── widgets/                 # Widgets camera (5 files)
│   └── core/                        # Module dùng chung
│       ├── models/                  # Data models (5 files)
│       ├── services/                # Business logic, API calls (7 files)
│       ├── providers/               # State management (9 files)
│       ├── controllers/             # Notification controller (1 file)
│       ├── utils/                   # Helpers (1 file)
│       └── widgets/                 # Shared widgets (1 file)
├── functions/                       # Firebase Cloud Functions (Node.js)
│   ├── index.js                     # Entry point: PayOS webhook + export push notification functions
│   └── index1.js                    # 3 Cloud Functions: sendMessage/sendCall/sendMomentReaction Notification
├── assets/
│   └── images/                      # Logo, google logo, background, avatar placeholder
├── android/                         # Android config, build.gradle, signing
├── ios/                             # iOS config, Info.plist
├── .env                             # Environment variables (KHÔNG commit lên git)
├── pubspec.yaml                     # Flutter dependencies
├── firebase.json                    # Firebase deployment config
└── package.json                     # Node.js deps cho Cloud Functions
```

---

## 3. FILE CẤU HÌNH

### `.env` — Biến môi trường
Được load bằng `flutter_dotenv`, bundle vào app qua `assets`.
```
FIREBASE_API_KEY=...
FIREBASE_APP_ID=...
FIREBASE_PROJECT_ID=...
RAWG_API_KEY=...           # Key RAWG.io để lấy game data
DEBUG_MODE=true
AGORA_APP_ID=...           # App ID Agora RTC cho video/voice call
FCM_SERVER_KEY=...         # FCM legacy key (dùng cho backend nếu cần)
BACKEND_URL=http://10.0.2.2:3000  # Backend dev (Android emulator)
PAYOS_CLIENT_ID=...        # PayOS client ID
PAYOS_API_KEY=...          # PayOS API key
PAYOS_CHECKSUM_KEY=...     # PayOS HMAC checksum key
```

**Cách dùng trong code:**
```dart
dotenv.env['RAWG_API_KEY']!
dotenv.env['AGORA_APP_ID']!
```

### `pubspec.yaml` — Flutter Dependencies

| Package | Version | Mục đích |
|---|---|---|
| `cloud_firestore` | ^5.4.3 | Database realtime (Firestore) |
| `firebase_auth` | ^5.6.2 | Xác thực (Google, Facebook, Phone, Email) |
| `firebase_storage` | ^12.4.9 | Upload/download ảnh, video |
| `firebase_core` | ^3.15.1 | Firebase init |
| `firebase_crashlytics` | ^4.3.9 | Báo cáo crash tự động |
| `firebase_analytics` | ^11.5.2 | Tracking hành vi user |
| `firebase_messaging` | ^15.1.3 | Push notification (FCM) |
| `cloud_functions` | ^5.1.3 | Gọi Firebase Cloud Functions |
| `google_sign_in` | ^6.2.1 | Đăng nhập Google |
| `flutter_facebook_auth` | ^7.0.1 | Đăng nhập Facebook |
| `awesome_notifications` | ^0.10.1 | Local notification (rich, action buttons) |
| `awesome_notifications_fcm` | ^0.10.1 | Bridge FCM → AwesomeNotifications |
| `awesome_notifications_core` | ^0.10.0 | Core cho awesome_notifications |
| `provider` | ^6.1.2 | State management |
| `rxdart` | ^0.28.0 | Reactive streams (kết hợp nhiều stream) |
| `http` | ^1.2.2 | HTTP requests (RAWG API, ML API, PayOS) |
| `flutter_dotenv` | ^6.0.0 | Load .env file |
| `agora_rtc_engine` | 6.5.3 | Video/Voice call Agora |
| `permission_handler` | ^12.0.1 | Xin quyền camera, mic, location |
| `camera` | ^0.11.0+6 | Camera controller |
| `camerawesome` | ^2.5.0 | Camera UI nâng cao |
| `video_player` | ^2.8.1 | Play video |
| `video_thumbnail` | ^0.5.3 | Tạo thumbnail từ video |
| `record` | ^6.1.1 | Ghi âm voice message |
| `just_audio` | ^0.9.36 | Phát audio (voice message) |
| `image_picker` | ^1.1.2 | Chọn ảnh/video từ thư viện |
| `path_provider` | ^2.0.15 | Đường dẫn thư mục tạm |
| `geolocator` | ^10.1.0 | Lấy vị trí GPS |
| `geocoding` | ^2.1.1 | Chuyển tọa độ → địa chỉ |
| `cached_network_image` | ^3.3.1 | Cache ảnh từ URL |
| `tflite_flutter` | ^0.11.0 | TensorFlow Lite (ML on-device) |
| `intl` | ^0.20.2 | Format ngày, số |
| `intl_phone_number_input` | ^0.7.3 | Input số điện thoại quốc tế |
| `url_launcher` | ^6.2.1 | Mở URL/email/phone |
| `flutter_web_browser` | ^0.17.1 | Mở link trong WebView |
| `share_plus` | ^10.1.2 | Share nội dung |
| `fl_chart` | ^0.65.0 | Biểu đồ (admin dashboard) |
| `flutter_card_swiper` | ^6.0.0 | Card swipe UI (Tinder-style) |
| `flutter_swiper_null_safety` | ^1.0.2 | Swiper/carousel |
| `multi_select_flutter` | ^4.1.3 | Multi-select dropdown |
| `dropdown_search` | ^6.0.2 | Dropdown có tìm kiếm |
| `logger` | ^2.2.0 | Logging tiện lợi |
| `logging` | ^1.3.0 | Dart logging framework |
| `crypto` | ^3.0.3 | HMAC SHA256 (PayOS signature) |
| `flutter_launcher_icons` | ^0.13.1 | Generate app icon |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

### `firebase.json` — Firebase Deployment
```json
{
  "functions": [{ "source": "functions", "codebase": "default" }]
}
```
Chứa source Cloud Functions tại thư mục `functions/`.

### `analysis_options.yaml`
Cấu hình lint rules Flutter standard.

---

## 4. lib/main.dart — ENTRY POINT

**File lớn nhất, quan trọng nhất.** Làm các việc sau:

1. `WidgetsFlutterBinding.ensureInitialized()` — init Flutter
2. `dotenv.load()` — load `.env`
3. `Firebase.initializeApp()` — init Firebase
4. `NotificationController.initializeLocalNotifications()` — init notification channels
5. `NotificationController.initializeRemoteNotifications()` — init FCM
6. `AwesomeNotifications().setListeners()` — đăng ký callback notification
7. `runApp(GameNectApp())`

### `GameNectApp` Widget
- `MultiProvider` cung cấp tất cả providers toàn app:
  - `AuthService` (plain Provider)
  - `LocationProvider` (ChangeNotifier)
  - `AuthProvider` (ChangeNotifierProxyProvider, phụ thuộc LocationProvider)
  - `ProfileProvider`, `EditProfileProvider`, `MatchProvider`, `ChatProvider`, `MomentProvider` (ChangeNotifier)
  - `FirestoreService` (plain Provider)
  - `GameProvider` (ChangeNotifier)
- `MaterialApp` với theme deepOrange, Material3
- Locale: vi_VN (primary), en_US
- `navigatorKey` toàn cục để điều hướng từ notification handler

### Routes
| Route | Widget | Ghi chú |
|---|---|---|
| `/` | `AuthWrapper` | Kiểm tra auth state |
| `/login` | `LoginScreen` | |
| `/home` | `UserApp` | |
| `/profile` | `ProfileScreen` | |
| `/phone-login` | `PhoneLoginScreen` | |
| `/email-login` | `EmailLoginScreen` | |
| `/admin-test-users` | `AdminTestUsersScreen` | |
| `/moments` | `UserApp(initialRoute: '/main')` | |
| `/chat` | `ChatScreen` | Nhận args: matchId, peerUser |
| `/video_call` | `VideoCallScreen` | Nhận args: channelName, peerUserId, ... |

### `AuthWrapper`
- `StreamBuilder<User?>` lắng nghe `authService.authStateChanges`
- Nếu có user → `FutureBuilder` kiểm tra field `isAdmin` trong Firestore:
  - `isAdmin == true` → `AdminApp()`
  - Ngược lại → `UserApp()`
- Sau login: load FCM token, update vị trí, load profile, setup listeners chat/call/moment

### Notification Handlers (top-level functions với `@pragma("vm:entry-point")`)
- `onActionReceivedMethod`: xử lý khi user nhấn notification
  - `type == 'call'` + `actionKey == 'accept'` → `_handleAcceptCall()`
  - `type == 'call'` + `actionKey == 'decline'` → `_handleDeclineCall()`
  - `type == 'chat'` → navigate đến `ChatScreen`
  - `type == 'moment_reaction'` → navigate đến `/moments`
- `onNotificationCreatedMethod`, `onNotificationDisplayedMethod`, `onDismissActionReceivedMethod`: log

---

## 5. lib/firebase_options.dart

Auto-generated bởi `flutterfire configure`. Chứa `DefaultFirebaseOptions.currentPlatform` trả về cấu hình Firebase đúng cho từng platform (Android, iOS, Web).

**Không chỉnh sửa tay file này.**

---

## 6. MODULE CORE

### 6.1. Models (`lib/core/models/`)

#### `user_model.dart` — UserModel
Model trung tâm của app. Lưu toàn bộ thông tin user.

**Các nhóm trường:**
| Nhóm | Trường |
|---|---|
| Cơ bản | id, username, gender, age, height, bio, avatarUrl, additionalPhotos |
| Gaming | favoriteGames, rank, playTime, winRate, points, gameStyle, gamingStats, gamingPlatforms |
| Vị trí | latitude, longitude, address, city, country, locationType, lastLocationUpdate |
| Matching | maxDistance, showDistance, minAge, maxAge, interestedInGender |
| Premium | isPremium, subscriptionTier, subscriptionEndDate, premiumPlan, premiumStartDate, premiumEndDate |
| Tính năng | boostCount, superLikesRemaining, canRewind, isVerified, incognitoMode |
| Mạng xã hội | phoneNumber, phoneVerified, emailVerified, socialLinks |
| Thống kê | profileViews, totalMatches, totalLikes, totalSuperLikes |
| Quyền | isAdmin |

**Getters quan trọng:**
- `canBoost` — có thể boost không (check boostCount và cooldown 24h)
- `canSuperLike` — có thể super like không
- `displayLocation` — chuỗi hiển thị vị trí
- `hasAccurateLocation` — có tọa độ GPS chính xác không

**Methods:**
- `toMap()` — serialize sang Map để lưu Firestore (DateTime → ISO8601 String)
- `fromMap(map, id)` — factory constructor từ Firestore data
- `copyWith(...)` — tạo bản sao với một số trường thay đổi

**Lưu ý field `location`:** Trong Firestore có thể là String hoặc Map `{city, latitude, longitude}`. `fromMap` xử lý cả hai case.

---

#### `match_model.dart` — MatchModel + MatchStatus

`MatchStatus` constants: `pending`, `partial`, `confirmed`, `cancelled`, `expired`

**MatchModel fields:**
- `id`, `userIds` (List<String> 2 user), `game`, `matchedAt`
- `isActive`, `confirmations` (Map<userId, bool>)
- `status`, `cancelReason`, `createdAt`, `updatedAt`, `confirmedAt`, `cancelledAt`, `expiresAt`

**`computeStatus()`:** Tính lại status từ confirmations — pending/partial/confirmed/expired.

---

#### `moment_model.dart` — MomentModel

| Field | Type | Mô tả |
|---|---|---|
| id | String | Document ID |
| userId | String | Chủ moment |
| mediaUrl | String | URL ảnh/video trên Firebase Storage |
| thumbnailUrl | String? | Thumbnail cho video |
| isVideo | bool | true nếu là video |
| createdAt | DateTime | Thời gian đăng |
| matchIds | List<String> | Danh sách userId được xem moment này |
| reactions | List<Map> | [{userId, emoji, reactedAt}] |
| replies | List<Map> | [{userId, text, repliedAt}] |
| caption | String? | Chú thích |

**Lưu ý:** `createdAt` trong Firestore có thể là `Timestamp`, `String` (base64 encoded ISO8601), hoặc `null`. `fromMap` xử lý cả 3 trường hợp.

---

#### `swipe_history_model.dart` — SwipeHistory

Lưu lịch sử swipe (like/dislike).

Fields: `id`, `userId`, `targetUserId`, `action` ('like'/'dislike'), `timestamp`, `expiresAt`

---

#### `game_model.dart` — GameModel + GameDetailModel

Model mapping từ RAWG API response.

`GameModel`: id, name, backgroundImage, rating, released, genres, platforms, metacritic

`GameDetailModel`: Tất cả trên + description, website, screenshots, developers, publishers, ...

---

### 6.2. Services (`lib/core/services/`)

#### `auth_service.dart` — AuthService

**Thư viện:** `firebase_auth`, `google_sign_in`, `flutter_facebook_auth`, `logging`

**Methods:**
| Method | Mô tả |
|---|---|
| `signInWithGoogle()` | Đăng nhập Google OAuth |
| `signInWithFacebook()` | Đăng nhập Facebook OAuth |
| `signOut()` | Đăng xuất (cả Google, Facebook, Firebase Auth) |
| `verifyPhoneNumber(phone)` | Gửi OTP đến số điện thoại VN, trả về verificationId |
| `verifyOTP(verificationId, otp)` | Xác thực OTP, đăng nhập |
| `signUpWithEmailPassword(email, pass)` | Đăng ký email/password |
| `signInWithEmailPassword(email, pass)` | Đăng nhập email/password |
| `authStateChanges` (getter) | Stream<User?> lắng nghe auth state |
| `currentUser` (getter) | User? hiện tại |

**OTP Rate limiting:** Max 3 lần gửi OTP, cooldown 5 phút. Map `_otpAttempts` lưu số lần và thời gian.

**Phone format:** Tự động chuẩn hóa số VN sang E.164 (`+84...`).

---

#### `firestore_service.dart` — FirestoreService (FILE LỚN NHẤT ~1300 lines)

**Thư viện:** `cloud_firestore`, `firebase_storage`, `firebase_auth`

Central service cho tất cả thao tác Firestore và Firebase Storage.

**Collections trong Firestore:**

| Collection | Mô tả |
|---|---|
| `users` | Profile người dùng |
| `matches` | Các cặp match (confirmed/pending/cancelled) |
| `chats/{matchId}/messages` | Tin nhắn trong từng match |
| `chats/{matchId}` | Document chứa typing indicator |
| `calls/{matchId}` | Thông tin cuộc gọi (callerId, receiverId, status, answered) |
| `swipe_history` | Lịch sử swipe (giữ 60 ngày, có TTL field `expiresAt`) |
| `swipe_latest` | Trạng thái swipe mới nhất của cặp user, ID = `{userId}_{targetUserId}` |
| `moments` | Moments (stories) |
| `moments/{momentId}/reactions` | Reactions của từng moment |
| `orders` | Lịch sử đơn hàng PayOS |
| `transactions` | Lịch sử giao dịch |
| `premium_plans` | Cấu hình gói premium (admin config) |

**Nhóm methods quan trọng:**

*User CRUD:*
- `addUser(user)` — set/merge user document
- `getUser(userId)` — get UserModel
- `updateUser(user)` — update toàn bộ
- `updateUserField(userId, field, value)` — update 1 field
- `updateUserFields(userId, fields)` — update nhiều fields cùng lúc
- `deleteUser(userId)`
- `getUserStream(userId)` — Stream<UserModel?> realtime

*Search & Geo:*
- `getUsersWithinRadius(lat, lon, radiusKm, ...)` — tìm user trong bán kính bằng bound query + filter longitude

*Swipe:*
- `saveSwipeHistory(userId, targetUserId, action)` — ghi vào cả `swipe_history` và `swipe_latest`
- `getSwipedUserIds(userId)` — lấy danh sách đã swipe
- `checkMutualLike(userId, targetUserId)` — kiểm tra mutual like
- `getLikedMeHistory(userId)` — lấy người đã like mình

*Match:*
- `createNewMatch(userIds, game, expiresAt)` — tạo match mới
- `getMatchBetweenUsers(u1, u2)` — kiểm tra đã match chưa
- `getMatchDocsForUser(userId)` — lấy tất cả match documents
- `getUserMatchesStream(userId)` — Stream<List<MatchModel>> realtime
- `unmatch(matchId)` — hủy match (set status = 'cancelled')

*Chat:*
- `sendMessage(matchId, text)` — gửi text, cập nhật lastMessage
- `sendMessageWithMedia(matchId, text, mediaUrl, isVideo)` — gửi kèm media
- `sendVoiceMessage(matchId, audioUrl, duration)` — gửi voice
- `reactToMessage(matchId, messageId, emoji)` — react vào tin nhắn
- `messagesStream(matchId)` — Stream<List<Map>> realtime
- `getLastMessage(matchId)` — lấy tin nhắn cuối
- `addCallMessage(matchId, senderId, duration, ...)` — lưu log cuộc gọi

*Moments:*
- `postMoment(userId, mediaUrl, isVideo, matchIds, ...)` — đăng moment
- `getMomentsForUser(userId, matchIds)` — lấy moments
- `addReactionToMoment(momentId, userId, emoji)`
- `addReplyToMoment(momentId, userId, text)`

*Media Upload:*
- `uploadImage(File, userId, path)` — upload lên Storage path `users/{userId}/{path}`, trả về download URL

---

#### `location_service.dart` — LocationService

**Thư viện:** `geolocator`, `geocoding`, `logging`

| Method | Mô tả |
|---|---|
| `checkLocationPermission()` | Kiểm tra quyền location |
| `requestLocationPermission()` | Xin quyền (mở Settings nếu denied forever) |
| `isLocationServiceEnabled()` | Kiểm tra GPS bật chưa |
| `getCurrentLocation()` | Lấy vị trí hiện tại — thử High/Medium/Low accuracy, fallback last known |
| `getAddressFromCoordinates(lat, lon)` | Geocoding → {address, city, country} |
| `calculateDistance(lat1, lon1, lat2, lon2)` | Khoảng cách km (Haversine) |
| `formatDistance(km)` | Format: "x m" / "x.x km" / "x km" |
| `isWithinMatchingRadius(...)` | Check user có trong bán kính không |
| `getLocationData()` | Full: gọi getCurrentLocation + getAddress, trả Map {latitude, longitude, address, city, country, location, lastLocationUpdate}. Fallback về Hà Nội nếu GPS fail |
| `getLocationStream()` | Stream<Position> update khi di chuyển >100m |

---

#### `notification_service.dart` — Standalone functions (không phải class)

**Thư viện:** `awesome_notifications`

Functions độc lập, được gọi từ ChatProvider và MomentProvider:

- `showMessageNotification({peerUsername, matchId, peerUserId, message})` — notification tin nhắn (channel: `gamenect_channel`, layout: Messaging)
- `showCallNotification({peerUsername, matchId, peerUserId})` — notification cuộc gọi (channel: `call_channel`, có action buttons Nghe/Từ chối, fullScreen, criticalAlert, locked)
- `showMomentReactionNotification({...})` — notification reaction moment (channel: `moment_channel`)
- `cancelNotification(id)`, `cancelAllNotifications()`

---

#### `payment_service.dart` — PaymentService

**Thư viện:** `cloud_firestore`, `firebase_auth`

**Methods:**
- `purchaseSubscription(tier, durationDays)` — cập nhật Firestore user isPremium=true, lưu vào `transactions`
- `checkSubscriptionStatus(userId)` — check subscription có hết hạn không, auto reset về free nếu expired

> **Lưu ý:** Logic tạo payment link PayOS được xử lý ở `SubscriptionProvider`, không phải PaymentService. PaymentService là helper đơn giản hơn.

---

#### `rawg_service.dart` — RawgService

**Thư viện:** `http`, `logger`, `flutter_dotenv`

Base URL: `https://api.rawg.io/api`

API Key từ: `dotenv.env['RAWG_API_KEY']`

| Method | Endpoint | Mô tả |
|---|---|---|
| `getTrendingGames()` | `/games?ordering=-added,-rating&dates=2024-...` | Trending games |
| `getNewReleases()` | `/games?ordering=-released&dates=30_days_ago-today` | Games mới |
| `getGamesByGenre(genre)` | `/games?genres=genre&ordering=-rating` | Theo thể loại |
| `searchGames(query)` | `/games?search=query` | Tìm kiếm |
| `getGameDetail(gameId)` | `/games/{id}` | Chi tiết game |
| `getGenres()` | `/genres` | Danh sách thể loại |

Tất cả có timeout 10 giây.

---

#### `notification_helper.dart`

Helper nhỏ, ít chức năng. Wrapper cho một số notification actions cơ bản.

---

### 6.3. Controllers (`lib/core/controllers/`)

#### `notification_controller.dart` — NotificationController (Singleton)

**Thư viện:** `awesome_notifications`, `awesome_notifications_fcm`, `firebase_core`, `cloud_firestore`, `firebase_auth`

**Singleton pattern:** `factory NotificationController() => _instance;`

**Notification Channels được tạo:**
| Key | Tên | Importance | Ghi chú |
|---|---|---|---|
| `gamenect_channel` | Gamenect Messages | Max | Tin nhắn chat |
| `call_channel` | Gamenect Calls | Max | Cuộc gọi (criticalAlerts: true) |
| `moment_channel` | Gamenect Moments | High | Reactions moment |
| `basic_channel` | Basic notifications | Default | Thông báo chung |

**Static methods:**
- `initializeLocalNotifications(debug)` — khởi tạo 4 channels
- `initializeRemoteNotifications(debug)` — init FCM callbacks
- `requestPermissions()` — xin quyền notification

**Instance methods:**
- `getFirebaseToken()` — lấy FCM token, lưu vào Firestore field `fcmToken`
- `clearToken()` — xóa token khi logout
- `subscribeToTopic(topic)`, `unsubscribeFromTopic(topic)`

**FCM Callbacks (entry-point):**
- `mySilentDataHandle(silentData)` — xử lý silent push, tạo local notification theo `type` (chat/call/moment_reaction)
- `myFcmTokenHandle(token)` — lưu token mới vào Firestore
- `myNativeTokenHandle(token)` — log APNS token

**Static show notification methods:**
- `showChatNotification()`, `showCallNotification()`, `showMomentNotification()`, `createNewNotification()`

---

### 6.4. Providers (`lib/core/providers/`)

#### `auth_provider.dart` — AuthProvider

**Quản lý:** Đăng nhập/đăng xuất qua AuthService, profile création khi user mới.

**Kết hợp với:** `LocationProvider` (ChangeNotifierProxyProvider trong main.dart)

**Methods:** `signInWithGoogle()`, `signInWithFacebook()`, `signInWithPhone()`, `signOut()`, `setLocationProvider()`

---

#### `profile_provider.dart` — ProfileProvider

**Quản lý:** Profile của user hiện tại.

**Methods:** `loadUserProfile()`, `updateUserField()`

**State:** `userData` (UserModel?), `isLoading`

---

#### `edit_profile_provider.dart` — EditProfileProvider

**Quản lý:** State khi đang edit profile (tạm thời trước khi save).

**Methods:** `loadProfile()`, `saveProfile()`, `uploadAvatar()`, các setters cho từng field.

---

#### `location_provider.dart` — LocationProvider

**Thư viện:** `geolocator`, `firebase_auth`, `cloud_firestore` (gián tiếp qua FirestoreService)

**Quản lý:** Vị trí GPS của user, cài đặt location filter.

**Methods:**
- `updateUserLocation(userId)` — lấy GPS và cập nhật Firestore
- `loadSettingsFromUser(userData)` — load settings từ UserModel
- `updateLocationSettings(maxDistance, showDistance, minAge, maxAge, interestedInGender)` — cập nhật Firestore

**State:** `latitude`, `longitude`, `address`, `maxDistance`, `showDistance`, `minAge`, `maxAge`, `interestedInGender`, `isLoading`

---

#### `match_provider.dart` — MatchProvider

**Thư viện:** `rxdart`, `cloud_firestore`, `http`

**Quản lý:** Logic matching, swipe, đề xuất user.

**Methods quan trọng:**

| Method | Mô tả |
|---|---|
| `fetchRecommendations(currentUser, candidates)` | Filter candidates → gọi ML API Railway → lấy UserModel từ Firestore theo kết quả → kiểm tra lại khoảng cách |
| `saveSwipeHistory(currentUserId, targetUser, isLike)` | Lưu swipe, kiểm tra mutual like, tạo match nếu cần |
| `fetchFilteredUsers(currentUserId)` | Lấy tất cả users chưa swipe |
| `fetchLikedMeUsers(currentUserId)` | Người đã like mình (chưa match) |
| `fetchMatchedUsersWithMatchId(currentUserId)` | Danh sách matches kèm matchId và lastMessage |
| `matchedUsersStream(currentUserId)` | Stream realtime matches + last message (dùng `Rx.combineLatestList`) |
| `streamLikedMeUsers(currentUserId)` | Stream realtime người like mình (loại trừ đã match/cancelled) |
| `streamMyDislikedUsers(currentUserId)` | Stream realtime người mình dislike |
| `unmatch(matchId)` | Hủy match |
| `calculateDistance(lat1, lon1, lat2, lon2)` | Haversine formula |

**ML API Recommend:**
- URL: `https://web-production-188ce.up.railway.app/recommend`
- Payload: `{current_user: {...}, candidate_users: [...]}`
- Response: `{recommendations: [{user_id: ..., distance_km: ...}]}`
- Sau đó fetch từng user từ Firestore để lấy dữ liệu mới nhất, tính lại khoảng cách thực tế

---

#### `chat_provider.dart` — ChatProvider

**Thư viện:** `cloud_firestore`, `firebase_auth`

**Quản lý:** Tin nhắn, typing indicator, notification tin nhắn/cuộc gọi.

**Methods:**
| Method | Mô tả |
|---|---|
| `fetchMessages(matchId)` | Load tin nhắn một lần |
| `sendMessage(matchId, text)` | Gửi text |
| `sendVoiceMessage(matchId, audioUrl)` | Gửi voice + notify |
| `sendMessageWithMedia(matchId, text, mediaUrl, isVideo)` | Gửi kèm media |
| `sendMediaWithNotify(...)` | Gửi media + gửi notification |
| `reactToMessage(matchId, messageId, emoji)` | React tin nhắn |
| `messagesStream(matchId, peerUser)` | Stream + auto notify khi có tin nhắn mới từ peer |
| `listenForIncomingCalls(matchId, peerUser)` | Lắng nghe Firestore `calls/{matchId}`, show call notification |
| `answerCall(matchId)` | Đánh dấu cuộc gọi đã trả lời |
| `endCall(matchId, duration, missed, declined)` | Kết thúc cuộc gọi, log vào messages |
| `setTyping(matchId, isTyping)` | Cập nhật typing indicator lên Firestore |
| `peerTypingStream(matchId, peerUserId)` | Stream<bool> trạng thái typing của peer |

**Dedup notification:** `_lastNotifiedMessageId` map lưu messageId/timestamp đã notify để tránh notify lặp.

---

#### `moment_provider.dart` — MomentProvider

**Thư viện:** `cloud_firestore`, `logger`

**Quản lý:** Moments (Stories), realtime reactions.

**Methods:**
| Method | Mô tả |
|---|---|
| `listenMoments(userId)` | Stream Firestore moments `where matchIds arrayContains userId`, detect reaction mới và gửi notification. Bỏ qua snapshot đầu tiên để tránh notify reaction cũ |
| `fetchMoments(userId, matchIds)` | Fetch một lần |
| `postMoment(userId, mediaUrl, isVideo, matchIds, ...)` | Đăng moment mới |
| `reactToMoment(momentId, userId, emoji)` | Thêm reaction |
| `replyToMoment(momentId, userId, text)` | Trả lời moment |

**Dedup notification:** `_notifiedReactions` Map<momentId, Set<reactionKey>> lưu các reaction đã notify. `_isFirstSnapshot` flag để skip snapshot đầu tiên.

---

#### `game_provider.dart` — GameProvider

**Thư viện:** `http` (gián tiếp qua RawgService)

**Quản lý:** Dữ liệu games từ RAWG API.

**Methods:** `fetchTrendingGames()`, `fetchNewReleases()`, `searchGames(query)`, `fetchGameDetail(gameId)`

---

#### `subscription_provider.dart` — SubscriptionProvider

**Thư viện:** `crypto`, `http`, `cloud_firestore`, `firebase_auth`, `flutter_dotenv`, `logger`

**Quản lý:** Gói Premium, tích hợp PayOS.

**Methods:**
| Method | Mô tả |
|---|---|
| `fetchPlans()` | Lấy gói premium từ Firestore `premium_plans` (isActive=true) |
| `getPlanPrice(planType)` | Lấy giá (yearly/monthly) |
| `purchasePlan(planType)` | Tạo order trong Firestore + gọi PayOS API lấy checkout URL |
| `checkPaymentStatus(orderCode)` | Kiểm tra trạng thái thanh toán qua PayOS API |
| `activatePremium(userId, planType, orderCode)` | Kích hoạt premium (update Firestore user + order) |
| `restorePurchase()` | Khôi phục lại premium từ lịch sử đơn hàng |

**PayOS Flow:**
1. Tạo order trong Firestore `orders/{orderCode}` (status: pending)
2. Gọi `POST https://api-merchant.payos.vn/v2/payment-requests` với HMAC SHA256 signature
3. Nhận `checkoutUrl` → mở `url_launcher`
4. PayOS webhook (Cloud Function `payosWebhook`) gọi về → update order + activate premium hoặc cộng coin
5. App poll qua `checkPaymentStatus()` hoặc lắng nghe Firestore

---

#### `wallet_provider.dart` — WalletProvider

**Quản lý:** Chức năng Ví (Coin), Nạp tiền và Rút tiền.

**Methods:**
| Method | Mô tả |
|---|---|
| `createWithdrawRequest(userId, coins, amount, bankInfo)` | Tạo lệnh rút tiền, tạm trừ coinBalance trong Firestore, tạo request ở `withdraw_requests` |

---

#### `livestream_provider.dart` — LivestreamProvider

**Quản lý:** Trạng thái phát Livestream của người dùng, tích hợp với bảng `livestreams`.

---

### 6.5. Utils (`lib/core/utils/`)

#### `video_thumbnail_helper.dart`

Helper tạo thumbnail từ file video local hoặc URL. Dùng package `video_thumbnail`.

---

### 6.6. Widgets (`lib/core/widgets/`)

#### `profile_card.dart`

Widget hiển thị thẻ profile người dùng trong màn hình swipe. Hiển thị: avatar, tên, tuổi, vị trí, games yêu thích, khoảng cách.

---

## 7. MODULE USER (`lib/user/`)

### `user_app.dart` — UserApp

Root widget cho user thông thường. `MaterialApp` với deepOrange theme.

**Routes:**
| Route | Screen |
|---|---|
| `/main` | MainScreen (bottom nav) |
| `/home` | HomeScreen |
| `/profile` | ProfileScreen |
| `/login` | LoginScreen |
| `/phone-login` | PhoneLoginScreen |
| `/email-login` | EmailLoginScreen |
| `/admin-test-users` | AdminTestUsersScreen |
| `/location-settings` | LocationSettingsScreen |
| `/liked-me` | LikedMeScreen |
| `/moment` | MomentScreen |
| `/chat` | ChatScreen (args: matchId, peerUser) |
| `/video_call` | VideoCallScreen (args: channelName, peerUserId, ...) |

Cũng có hàm helper `showIncomingCallDialog(context, matchId, peerUserId)`.

---

### Screens (`lib/user/screens/`)

| File | Mô tả |
|---|---|
| `main_screen.dart` | Bottom navigation bar (Home, Match/Swipe, Moment, Chat, Profile) |
| `home_screen.dart` | Màn hình chính, hiển thị trending features |
| `login_screen.dart` | Màn hình login với Google, Facebook, Phone, Email |
| `phone_login_screen.dart` | Đăng nhập bằng số điện thoại + OTP |
| `email_login_screen.dart` | Đăng nhập/đăng ký bằng email + password |
| `profile.dart` | Màn hình profile cá nhân (ProfileScreen) |
| `edit_profile_screen.dart` | Chỉnh sửa profile (lớn nhất, ~63KB) |
| `match_screen.dart` | Màn hình swipe card (Tinder-style), dùng `flutter_card_swiper` |
| `match_list_screen.dart` | Danh sách matches, hiển thị last message |
| `liked_me_screen.dart` | Người đã like mình (premium feature) |
| `chat_screen.dart` | Màn hình chat (lớn nhất, ~70KB), text/voice/media/call |
| `moment_screen.dart` | Xem/đăng moments, reactions, replies (lớn nhất, ~93KB) |
| `camera_capture_screen.dart` | Camera chụp ảnh/quay video cho Moment (~54KB) |
| `media_preview_screen.dart` | Preview ảnh/video trước khi đăng |
| `voice_preview_screen.dart` | Preview and play voice message trước khi gửi |
| `video_call_screen.dart` | Video/voice call qua Agora RTC |
| `subscription_screen.dart` | Mua gói Premium, tích hợp PayOS |
| `wallet/wallet_screen.dart` | Nạp Coin và Rút tiền cho Mentor |
| `location_settings_screen.dart` | Cài đặt vị trí, filter matching |
| `game_trending_screen.dart` | Danh sách game trending từ RAWG |
| `game_detail_screen.dart` | Chi tiết game từ RAWG |
| `admin_test_users_screen.dart` | Màn hình test tạo user giả (dành cho dev admin) |
| `live_stream_screen.dart` | Phòng phát Livestream (Mentor) |
| `live_swipe_feed_screen.dart` | Trải nghiệm vuốt dọc xem Livestream phong cách TikTok |

---

### Widgets (`lib/user/widgets/`)

| File | Mô tả |
|---|---|
| `glass_button.dart` | Nút glassmorphism effect (dùng trong camera UI) |
| `glass_icon_button.dart` | Icon button glassmorphism |
| `preview_button.dart` | Nút preview trong camera |
| `recording_indicator.dart` | Indicator đang ghi âm/quay |
| `zoom_preset_button.dart` | Nút chọn zoom preset (0.5x, 1x, 2x) |

---

## 8. MODULE ADMIN (`lib/admin/`)

### `admin_app.dart`

Điều hướng đến admin screens khi user có `isAdmin == true`.

### Screens (`lib/admin/screens/`)

| File | Mô tả |
|---|---|
| `dashboard_screen.dart` | Dashboard tổng quan (số user, số match, doanh thu) |
| `user_management_screen.dart` | Quản lý user (xem, block, grant premium) |
| `subscription_config_screen.dart` | Cấu hình gói Premium (tạo/sửa `premium_plans` collection) |
| `withdrawals/withdrawals_screen.dart` | Duyệt yêu cầu rút tiền của Mentor |
| `mentor/mentor_management_screen.dart` | Duyệt đơn đăng ký Mentor |

---

## 9. FIREBASE CLOUD FUNCTIONS (`functions/`)

### `index.js` — Entry Point

**Dependencies:** `firebase-functions`, `firebase-admin`, `firebase-functions/params`

**Exports:**
- `sendMessageNotification` — từ index1.js
- `sendCallNotification` — từ index1.js
- `sendMomentReactionNotification` — từ index1.js
- `payosWebhook` — handled inline

**`payosWebhook`** (HTTPS Function):
- Nhận webhook POST từ PayOS khi thanh toán thay đổi
- Verify HMAC SHA256 signature (`PAYOS_CHECKSUM_KEY` từ Firebase Secret Manager)
- Khi `code == "00"` (success): lấy order từ Firestore → update status → kích hoạt premium cho user
- Luôn trả 200 để PayOS không retry

---

### `index1.js` — Push Notification Functions

**Region:** `asia-southeast1` (Singapore), 512MiB, 30s timeout

**Triggers:** `onDocumentCreated` (Firestore)

| Function | Trigger Path | Mô tả |
|---|---|---|
| `sendMessageNotification` | `matches/{matchId}/messages/{messageId}` | Gửi FCM khi có tin nhắn mới. Lấy receiver từ match.user1Id/user2Id |
| `sendCallNotification` | `calls/{matchId}` | Gửi FCM khi có cuộc gọi đến. Priority max, fullScreen |
| `sendMomentReactionNotification` | `moments/{momentId}/reactions/{reactionId}` | Gửi FCM khi có reaction mới (skip self-reaction) |

**⚠️ Lưu ý `sendMessageNotification`:** Trigger path cũ là `matches/{matchId}/messages/{messageId}` nhưng trong Flutter code, messages được lưu tại `chats/{matchId}/messages/{messageId}`. Cần kiểm tra xem function có đang hoạt động đúng không.

**FCM Payload format:** Có cả `notification` và `data`. Data bao gồm các field cho `awesome_notifications` plugin (`content.channelKey`, `content.title`, ..., `content.payload.*`).

---

## 10. FIRESTORE DATA SCHEMA

### Collection `users`
```
users/{userId}: {
  id, username, avatarUrl, additionalPhotos,
  favoriteGames: String[],
  gender, age, height, bio, rank,
  playTime, winRate, points, gameStyle,
  interests: String[], lookingFor,
  dateOfBirth: ISO8601 String,
  latitude, longitude, address, city, country,
  locationType, lastLocationUpdate,
  maxDistance, showDistance, minAge, maxAge, interestedInGender,
  isPremium, subscriptionTier, subscriptionEndDate,
  premiumPlan, premiumStartDate, premiumEndDate,
  isAdmin, isVerified, isOnline,
  boostCount, superLikesRemaining,
  incognitoMode, blockedUserIds, reportedUserIds,
  fcmToken, fcmTokenUpdatedAt,
  profileViews, totalMatches, totalLikes, totalSuperLikes,
  socialLinks, phoneNumber, phoneVerified, emailVerified,
  gamingStats, gamingPlatforms,
  coinBalance,           // Số dư coin trong ví
  ...
}
```

### Collection `matches`
```
matches/{matchId}: {
  userIds: String[2],  // [userId1, userId2]
  user1Id, user2Id,    // Dùng cho Cloud Functions
  game, matchedAt, isActive,
  confirmations: {userId1: bool, userId2: bool},
  status: 'pending'|'partial'|'confirmed'|'cancelled'|'expired',
  cancelReason?,
  createdAt, updatedAt, confirmedAt?, cancelledAt?, expiresAt?,
  lastMessage?, lastMessageTime?, lastMessageSenderId?
}
```

### Collection `chats`
```
chats/{matchId}: {
  {userId}_typing: bool  // typing indicator
}
chats/{matchId}/messages/{msgId}: {
  senderId, text?, type: 'text'|'media'|'voice'|'react'|'call',
  timestamp: Timestamp,
  mediaUrl?, isVideo?, caption?,   // for 'media'
  audioUrl?, duration?,            // for 'voice'
  emoji?, reactionTo?,             // for 'react'
  callStatus?, duration?,          // for 'call': 'missed'|'declined'|'cancelled'|'ended'
  reactions: [{userId, emoji}]
}
```

### Collection `calls`
```
calls/{matchId}: {
  callerId, receiverId,
  status: 'active'|'accepted'|'declined'|'missed'|'ended',
  answered: bool,
  startedAt, endedAt?
}
```

### Collection `moments`
```
moments/{momentId}: {
  userId, mediaUrl, thumbnailUrl?, isVideo,
  createdAt: Timestamp,
  matchIds: String[],  // Ai được xem moment này
  reactions: [{userId, emoji, reactedAt}],
  replies: [{userId, text, repliedAt}],
  caption?
}
moments/{momentId}/reactions/{reactionId}: {
  userId, emoji, reactedAt  // Trigger Cloud Function
}
```

### Collection `swipe_history`
```
swipe_history/{auto}: {
  userId, targetUserId,
  action: 'like'|'dislike',
  timestamp: Timestamp,
  expiresAt: Timestamp (TTL 60 ngày)
}
```

### Collection `swipe_latest`
```
swipe_latest/{userId}_{targetUserId}: {
  userId, targetUserId,
  action: 'like'|'dislike',
  timestamp: Timestamp
}
```

### Collection `orders`
```
orders/{orderCode}: {
  userId, planType: 'monthly'|'yearly',
  amount, orderCode,
  status: 'pending'|'success'|'failed',
  createdAt, paymentData?
}
```

### Collection `premium_plans`
```
premium_plans/{planId}: {
  planType: 'monthly'|'yearly',
  price: int (VND),
  isActive: bool,
  features: String[],
  ...
}
```

### Collection `transactions`
```
transactions/{auto}: {
  userId, tier, duration, purchaseDate, endDate
}
```

---

## 11. FLOW QUAN TRỌNG

### Flow Đăng Nhập
```
LoginScreen → AuthService.signInWithGoogle/Facebook/Phone/Email
→ Firebase Auth user created
→ AuthWrapper detects auth state change
→ Check Firestore users/{uid} exists
  → Nếu không có: navigate EditProfileScreen để tạo profile
  → Nếu có: check isAdmin
    → admin: AdminApp
    → user: UserApp
→ After login: getFirebaseToken, updateLocation, loadProfile, setup listeners
```

### Flow Swipe & Match
```
MatchScreen loads candidates:
1. LocationProvider.updateUserLocation → lấy GPS
2. FirestoreService.getUsersWithinRadius → filter theo bounding box lat/lon
3. MatchProvider.fetchRecommendations:
   a. Filter theo age, gender, distance, chung game
   b. POST to Railway ML API → ranked recommendations
   c. Fetch từng user từ Firestore
   d. Kiểm tra lại khoảng cách thực tế
4. Hiển thị cards

User swipe:
→ MatchProvider.saveSwipeHistory
→ FirestoreService.saveSwipeHistory → ghi swipe_history + swipe_latest
→ checkMutualLike
  → Nếu mutual: createNewMatch (status: confirmed)
  → Notification match!
```

### Flow Chat
```
ChatScreen:
→ ChatProvider.messagesStream(matchId, peerUser) - Stream realtime
→ User gửi tin: sendMessage/sendVoiceMessage/sendMessageWithMedia
→ FirestoreService ghi vào chats/{matchId}/messages
→ Cloud Function sendMessageNotification trigger (nếu path đúng)
→ ChatProvider.messagesStream tự detect tin nhắn mới → local notification
→ Typing: setTyping → peerTypingStream → UI indicator
```

### Flow Video Call
```
User khởi tạo call:
→ Ghi vào Firestore calls/{matchId} {callerId, receiverId, status: 'active'}
→ Cloud Function sendCallNotification trigger
→ Peer nhận FCM → AwesomeNotifications show call notification với Nghe/Từ chối buttons
→ Tap "Nghe": onActionReceivedMethod → _handleAcceptCall → navigate VideoCallScreen

VideoCallScreen:
→ Agora RTC Engine join channel (channelName = matchId)
→ AGORA_APP_ID từ .env
→ Khi end: ChatProvider.endCall → addCallMessage → log trong messages
```

### Flow Moment
```
Capture (CameraCaptureScreen):
→ camera/camerawesome package
→ Preview → trim video if needed
→ Upload to Firebase Storage: users/{userId}/moments/{filename}
→ FirestoreService.postMoment → ghi vào moments/{id} {matchIds: [tất cả matched users]}

View (MomentScreen):
→ MomentProvider.listenMoments → Stream moments chứa matchIds arrayContains userId
→ React: addReactionToMoment → ghi vào moments/{id}.reactions
→ MomentProvider detect reaction mới (skip first snapshot) → showMomentReactionNotification
→ Cloud Function sendMomentReactionNotification (trigger từ moments/{id}/reactions subcollection)
```

### Flow Payment Premium
```
SubscriptionScreen:
→ SubscriptionProvider.fetchPlans → lấy gói từ premium_plans collection
→ User chọn gói → purchasePlan:
  1. Tạo orders/{orderCode} (pending)
  2. Gọi PayOS API lấy checkoutUrl + HMAC signature
  3. Mở flutter_web_browser với checkoutUrl

Sau thanh toán:
→ PayOS webhook → Cloud Function payosWebhook:
  1. Verify signature
  2. Update orders/{orderCode} (success)
  3. Update users/{userId}: isPremium=true, premiumPlan, premiumStartDate, premiumEndDate
→ App poll checkPaymentStatus hoặc listen Firestore thay đổi
→ SubscriptionProvider.activatePremium (backup nếu webhook fail)
```

---

## 12. QUAN TRỌNG KHI CODE

### Rules chung:
1. **State management:** Luôn dùng `Provider`. Không setState trực tiếp khi có Provider. Không dùng InheritedWidget hay Riverpod — dự án này chuẩn hóa 100% Provider.
2. **Firestore:** Dùng `merge: true` khi set để không ghi đè dữ liệu hiện có.
3. **Navigation:** Dùng `navigatorKey.currentState` cho navigation từ notification handlers (ngoài widget tree).
4. **Null safety:** Tất cả fields nullable cần xử lý `??` default value.
5. **DateTime:** Lưu vào Firestore dưới dạng ISO8601 String hoặc Timestamp. Khi đọc, cần xử lý cả hai case.

### Patterns thường dùng:
- Stream realtime: `snapshots().listen()` hoặc `StreamBuilder`
- Kết hợp stream: `Rx.combineLatestList(streams)` (rxdart)
- Switch stream: `.switchMap()` (rxdart)
- Push notification action: `@pragma("vm:entry-point")` function
- Async trong StreamBuilder: `.asyncMap()` rồi `.asBroadcastStream()`

### Vị trí files hay bị nhầm:
- Chat messages: **`chats/{matchId}/messages`** (KHÔNG phải `matches/{matchId}/messages`)
- Calls: **`calls/{matchId}`** (collection riêng, không phải subcollection của matches)
- FCM token: lưu trong **`users/{userId}.fcmToken`**
- moment matchIds: là **danh sách userId** (không phải matchId) — ai được xem moment

### Thêm tính năng mới:
1. Model → `lib/core/models/`
2. Service method → `lib/core/services/firestore_service.dart`
3. Provider → `lib/core/providers/`
4. Screen → `lib/user/screens/` (user) hoặc `lib/admin/screens/` (admin)
5. Register provider trong `main.dart` MultiProvider
6. Add route trong `main.dart` và `user_app.dart`

### Build & Deploy:
```bash
# Dev
flutter pub get
flutter run

# Release Android
flutter clean && flutter pub get
flutter build appbundle --release
# File: build/app/outputs/bundle/release/app-release.aab

# Release iOS
flutter build ios --release

# Deploy Cloud Functions
cd functions && firebase deploy --only functions
```

### Cấu hình Android cần thiết:
- `android/app/google-services.json` (từ Firebase Console)
- `android/key.properties` (signing config)
- ProGuard rules cho TensorFlow Lite, Firebase, camera

---

## 13. YÊU CẦU CODE CHUẨN (BẮT BUỘC CHO AGENT)

> **Agent phải đọc và tuân thủ section này TRƯỚC KHI viết bất kỳ dòng code nào.**

### 13.1. Tiêu chuẩn Code Clean

```
❌ SAI — Agent KHÔNG được làm:
- Đặt tên biến a, b, x, tmp, data1 không rõ ý nghĩa
- Viết hàm dài hơn 80 dòng mà không tách nhỏ
- Hardcode màu sắc hoặc giá trị magic number trực tiếp trong widget
- Nested if/else quá 3 tầng
- Copy-paste code trùng lặp không extract thành widget/method
- Bỏ qua error handling trong async methods

✅ ĐÚNG — Agent PHẢI làm:
- Tên biến/method phải tự giải thích (self-documenting)
- Mỗi hàm chỉ làm 1 việc (Single Responsibility)
- Extract widget nhỏ thành private method `_buildXxx()`
- Mọi async operation phải có try/catch
- Dùng const constructor khi widget không thay đổi
```

### 13.2. Cấu trúc File Bắt Buộc

Mọi file màn hình phải tuân theo thứ tự sau:
```dart
// 1. Imports (dart: → package: → '../' relative)
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/xxx_provider.dart';

// 2. StatefulWidget / StatelessWidget class
class XxxScreen extends StatefulWidget { ... }

// 3. State class
class _XxxScreenState extends State<XxxScreen> {

  // 3a. Khai báo state variables
  bool _isLoading = false;

  // 3b. initState
  @override
  void initState() { ... }

  // 3c. dispose
  @override
  void dispose() { ... }

  // 3d. Business logic / helper methods
  Future<void> _loadData() async { ... }
  void _handleAction() { ... }

  // 3e. Build widgets (build → _buildXxx)
  @override
  Widget build(BuildContext context) { ... }

  Widget _buildHeader() { ... }
  Widget _buildContent() { ... }
}
```

### 13.3. State Management — Provider Rules

**Quy tắc bất di bất dịch:**

```dart
// ✅ Đọc state để rebuild UI
final provider = context.watch<XxxProvider>();
// hoặc
Consumer<XxxProvider>(builder: (ctx, p, _) => ...);

// ✅ Gọi action, không cần rebuild
context.read<XxxProvider>().doSomething();

// ✅ Gọi trong initState / async callbacks
Provider.of<XxxProvider>(context, listen: false).doSomething();

// ❌ KHÔNG dùng Provider.of với listen: true trong build (dùng context.watch thay thế)
// ❌ KHÔNG setState khi dữ liệu đã được quản lý bởi Provider
// ❌ KHÔNG tạo Provider mới bên trong widget tree
```

**Khi thêm Provider mới:**
1. Tạo file trong `lib/core/providers/xxx_provider.dart`
2. Extend `ChangeNotifier`
3. Gọi `notifyListeners()` sau khi state thay đổi
4. Register trong `main.dart` MultiProvider TRƯỚC khi dùng
5. Inject dependency qua constructor hoặc `ChangeNotifierProxyProvider` (không tạo service mới bên trong provider)

**Provider pattern chuẩn:**
```dart
class XxxProvider extends ChangeNotifier {
  // State
  bool _isLoading = false;
  List<XxxModel> _items = [];
  String? _error;

  // Getters (bất biến từ ngoài)
  bool get isLoading => _isLoading;
  List<XxxModel> get items => List.unmodifiable(_items);
  String? get error => _error;

  // Actions
  Future<void> loadItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _service.getItems();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### 13.4. UI/Design Rules

Thiết kế của app đang dùng **Liquid Glass Design System**:

| Token | Giá trị |
|---|---|
| Background chính | `#101012` |
| Accent chính | `#FF6E40` (deep orange) |
| Glass background | `Colors.white.withValues(alpha: 0.05~0.20)` |
| Glass border | `Colors.white.withValues(alpha: 0.08~0.15)` |
| Blur | `ImageFilter.blur(sigmaX: 10~20, sigmaY: 10~20)` |
| Border radius lớn | `28~40px` |
| Border radius nhỏ | `12~20px` |

**Khi tạo container glass:**
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(24),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: ...,
    ),
  ),
)
```

**Màu sắc:**
- KHÔNG dùng `.withOpacity()` (deprecated) — dùng `.withValues(alpha: x)` thay thế
- KHÔNG hardcode màu hex ngẫu nhiên — stick with color tokens trên
- Accent gradient: `[Color(0xFFFF6E40), Color(0xFFFF9E80)]`

### 13.5. Naming Conventions

| Loại | Convention | Ví dụ |
|---|---|---|
| Class | PascalCase | `GameTrendingScreen` |
| Method/Variable | camelCase | `_loadTrendingGames()` |
| Private | bắt đầu `_` | `_isLoading`, `_buildHeader()` |
| Constant | camelCase hoặc SCREAMING_SNAKE nếu static const | `kCardRadius`, `_defaultBlur` |
| File | snake_case | `game_trending_screen.dart` |
| Route | kebab-case | `/game-trending` |

### 13.6. Error Handling

```dart
// ✅ Mọi async call phải có try/catch
Future<void> _loadData() async {
  try {
    final data = await service.getData();
    setState(() => _data = data);
  } catch (e, stackTrace) {
    // Log error
    debugPrint('Error loading data: $e\n$stackTrace');
    // Show user-friendly error (KHÔNG throw lên UI raw exception)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải dữ liệu. Thử lại sau.'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

// ✅ Kiểm tra mounted trước khi dùng context sau async
if (mounted) {
  setState(() { ... });
}
```

### 13.7. Hiệu năng

- Dùng `const` constructor khi widget không phụ thuộc vào state
- `CachedNetworkImage` cho TẤT CẢ ảnh từ URL (không dùng `NetworkImage` trực tiếp)
- Dùng `ListView.builder` thay `ListView` với children khi list dài
- `dispose()` tất cả controller, stream subscription, animation controller
- KHÔNG gọi Provider trong `build()` method của StatelessWidget nếu chỉ cần một lần

### 13.8. Comments và Documentation

```dart
// ✅ Comment TẠI SAO, không comment CÁI GÌ
// Bỏ qua snapshot đầu tiên để tránh notify reaction cũ khi mở app
_isFirstSnapshot = true;

// ❌ Comment thừa (code đã tự nói lên)
// Set isLoading to true
_isLoading = true;

/// Tài liệu public API dùng ///, private dùng // bình thường
/// [userId] — UID của user hiện tại
/// Returns danh sách moments được sắp xếp theo thời gian giảm dần
Future<List<MomentModel>> getMomentsForUser(String userId) async { ... }
```

### 13.9. Cập nhật Tài Liệu AGENT_DOCS

> **QUAN TRỌNG:** Agent phải tự động cập nhật file `AGENT_DOCS.md` mỗi khi có thay đổi về:
> - Tính năng mới được thêm vào hoặc sửa đổi.
> - Cấu trúc file, thư mục bị thay đổi.
> - Thêm package hoặc dependency mới.
> - Thay đổi liên quan đến cấu hình Firebase, logic quan trọng, v.v.
> Hãy thêm tóm tắt vào phần "THAY ĐỔI ĐÃ THỰC HIỆN (CHANGELOG)" (Section 14) để giữ tài liệu luôn mới nhất, giúp các agent sau nắm bắt context dễ dàng.

---

## 14. THAY ĐỔI ĐÃ THỰC HIỆN (CHANGELOG)

### [2026-04-01] — Khởi tạo dự án
- Cấu trúc cơ bản: Auth, Matching, Chat, Moments, Games, Premium

### [2026-05] — UI/UX Modernization: Liquid Glass

#### Moment Screen (moment_card.dart)
- **Reaction bar dọc kiểu TikTok** — bên phải màn hình, hiển thị sẵn ❤️😂🔥😍 + nút `+` để chọn thêm
- **Gộp reactions theo user** — thay vì mỗi emoji là 1 ô, giờ 1 người = 1 chip duy nhất chứa avatar + tất cả emoji họ đã thả
- **Bottom action bar gọn** — chỉ còn Camera reply + Gửi tin nhắn, emoji picker chuyển lên sidebar
- **Bottom sheet reactions** — gộp hiển thị người react theo user, không lặp ô

#### Game Trending Screen (game_trending_screen.dart)
- **Header "Discover"** — icon Liquid Glass (ClipOval + BackdropFilter + viền cam), chữ 32px bold
- **Search bar Frosted Glass** — BackdropFilter blur, viền mờ, nền trong suốt
- **Tab bar glass** — indicator là khối kính bán trong suốt thay vì underline

#### Game Detail Screen (game_detail_screen.dart)
- Giao diện Liquid Glass toàn bộ, gradient overlay, frosted glass cards
- Tính năng **Share game** — gửi game qua chat cho matched users
- Message type `game` trong chat (hiển thị dạng card trong bubble)

#### Chat Provider (chat_provider.dart)
- Thêm `sendGameMessage()` — gửi tin nhắn loại `game` với GameModel data

#### Message Bubble (message_bubble.dart)
- `_buildGameMessageBubble()` — hiển thị game được share dưới dạng card có ảnh và info

#### Pull-to-Refresh — Tất cả màn hình chính
| Màn hình | Reload gì |
|---|---|
| `match_screen.dart` | `MatchProvider.fetchRecommendations()` |
| `liked_me_screen.dart` (tab Thích bạn) | `_initializeData()` |
| `liked_me_screen.dart` (tab Bỏ lỡ) | `_initializeData()` |
| `profile_screen.dart` | `ProfileProvider.loadUserProfile()` |
| `moment_feed_tab.dart` | `MomentProvider.listenMoments()` |
| `game_trending_screen.dart` | `GameProvider.fetchTrendingGames/fetchNewReleases()` |

**Kiểu dáng RefreshIndicator chuẩn:**
```dart
RefreshIndicator(
  color: const Color(0xFFFF6E40),
  backgroundColor: const Color(0xFF1A1A1E),
  displacement: 20,
  onRefresh: () async { ... },
  child: ...,
)
```

### [2026-05-05] — Sửa lỗi luồng thanh toán PayOS
- **Vấn đề:** Nút "Đăng ký ngay" không mở được trang thanh toán PayOS (lỗi plugin `flutter_web_browser` không hoạt động ổn định trên các máy đời mới hoặc không deep-link được vào app ngân hàng).
- **Giải pháp:** Xóa package `flutter_web_browser` trong code và thay thế bằng `url_launcher` với mode `LaunchMode.externalApplication` để tự động mở trình duyệt ngoài, giúp việc thanh toán qua app ngân hàng trơn tru hơn.
- **File ảnh hưởng:** `lib/user/screens/premium/subscription_screen.dart`

### [2026-05-05] — Đồng bộ giao diện xem profile cá nhân
- **Vấn đề:** Khi vào tab Hồ sơ (ProfileScreen) và bấm vào avatar chính mình để xem card chi tiết, HOẶC khi bấm "Lưu hồ sơ" ở màn hình chỉnh sửa, giao diện hiển thị là màu trắng (cũ) không đồng nhất với giao diện "Liquid Glass Dark Premium" khi xem profile người khác.
- **Giải pháp:** Xóa đoạn code dùng `Scaffold` inline màu trắng ở cả 2 màn hình, thay thế bằng widget chuẩn `PeerProfileScreen(peerUser: provider.userData!)` dùng chung cho toàn app.
- **File ảnh hưởng:** 
  - `lib/user/screens/profile/profile_screen.dart`
  - `lib/user/screens/profile/edit_profile_screen.dart`

### [2026-05-26] — Bật Web Push Notifications (FCM)
- **Thêm service worker:** `web/firebase-messaging-sw.js` để nhận push khi tab đóng.
- **Đăng ký SW:** `web/index.html` tự động register service worker khi load.
- **FCM token Web:** `NotificationController.getFirebaseToken()` hỗ trợ Web bằng VAPID key và lưu token vào Firestore.
- **VAPID key:** ưu tiên nhận từ `--dart-define=FCM_VAPID_KEY=...` để không cần lưu vào repo.
- **Foreground Web:** hiển thị notification ngay khi tab đang mở qua `WebNotificationService`.
- **Web routing:** click notification mở URL kèm query params, app tự điều hướng theo `type`.

---

*Tài liệu này được tạo tự động bởi AI agent. Cập nhật: 2026-05-26.*

### [2026-05-27] — Tích hợp Unified Search & Ẩn nút "Thích" thông minh
- **Vấn đề:** Thay vì tạo một trang search riêng rườm rà, cần tận dụng ô tìm kiếm hiện có trong màn hình MatchList để tìm kiếm trên toàn hệ thống (Global) và tự động giấu nút "Thích" nếu đã match với người đó để tránh trùng lặp.
- **Giải pháp:**
  - Viết lại hàm `_onSearchChanged` tại `MatchListScreen` sử dụng cơ chế `Timer` debounce (1 giây) chống spam query Firebase.
  - Sau khi gõ, ứng dụng sẽ gọi `FirestoreService().searchUsersByUsername` và loại trừ bản thân khỏi danh sách hiển thị.
  - Global Search results hiển thị chung trong cuộn ListView cùng với matches cũ.
  - Kiểm tra điều kiện `isMatched` (user hiện tại có trong mảng `matchedData` không). Nếu có, truyền cờ `showActions: false` qua cho `PeerProfileScreen`.
- **File ảnh hưởng:**
  - `lib/user/screens/matching/match_list_screen.dart`
  - `lib/user/screens/shared/peer_profile_screen.dart`
  - (Xóa file: `lib/user/screens/matching/user_search_screen.dart`)

### [2026-05-27] — Tối ưu hóa Web Notification Routing
- **Vấn đề:** Khi click vào push notification trên Web (như Like, Chat, Moment), app đọc query parameters và gọi `_handleFcmTap` để đẩy màn hình chi tiết mới vào stack (ví dụ gọi Firestore get user info để mở `ChatScreen`). Việc này gây tốn phí đọc (reads), chậm và không cần thiết trên nền tảng Web vì các tab chính đã có danh sách tương ứng.
- **Giải pháp:**
  - Cập nhật `MainScreen` (thêm `initialIndex`) và `UserApp` để có thể nhận tab index đầu vào khi khởi tạo.
  - Khi Web nhận click push (kiểm tra bằng `kIsWeb` trong `_handleFcmTap`), app chỉ đơn giản thay thế Route hiện tại bằng `UserApp(initialRoute: '/main', initialIndex: targetIndex)` và trỏ đến Tab tương ứng (vd: Tab Lượt thích, Tab Feed, Tab Tin nhắn).
  - Kết quả: Redirect siêu tốc độ (0s), giảm 100% chi phí đọc document không cần thiết khi click thông báo trên Web.
- **File ảnh hưởng:**
  - `lib/main.dart`
  - `lib/user/user_app.dart`
  - `lib/user/screens/main/main_screen.dart`

### [2026-06-03] — Tích hợp & Sửa lỗi Màn hình Livestream & Mentor
- **Vấn đề:**
  - Chức năng Livestream & Mentor đã được tạo nhưng entry point (màn hình khám phá livestream `LiveDiscoverScreen`) chưa được tích hợp vào thanh Tab chính của ứng dụng (`MomentScreen`).
  - Hộp thoại nộp đơn đăng ký Mentor thành công gây ra lỗi unmounted context (`State no longer has a context`) và đơ màn hình đen.
  - Danh sách đơn đăng ký Mentor chờ duyệt ở màn hình Admin và danh sách phòng Live bị biến mất sau 1 giây do lỗi thiếu Firestore Composite Index khi kết hợp `.where()` và `.orderBy()`.
  - Game chuyên môn trong trang đăng ký Mentor bị hardcode tĩnh thay vì lấy từ RAWG API như trang hồ sơ cá nhân.
- **Giải pháp:**
  - Nâng cấp `MomentScreen` lên 3 tab: `Khám phá` | `🔴 Live` | `Của tôi` và tích hợp `LiveDiscoverScreen(embedMode: true)`.
  - Sửa logic pop dialog trong `MentorApplyScreen` bằng cách đóng dialog qua `dialogContext` và kiểm tra `if (mounted)` trước khi đóng màn hình để tránh lỗi Navigator bị đơ.
  - Khắc phục lỗi Firestore index bằng cách loại bỏ điều kiện truy vấn `.orderBy()` và thực hiện sắp xếp cục bộ trong bộ nhớ bằng code Dart (áp dụng cho danh sách đơn duyệt của admin, luồng lấy danh sách streams đang live, và match requests).
  - Tích hợp `DropdownSearch` vào màn hình đăng ký Mentor, kết nối với RAWG API đề xuất 10 game hot mặc định và cho phép tìm kiếm chọn game tùy ý.
- **File ảnh hưởng:**
  - `lib/user/screens/moments/moment_screen.dart`
  - `lib/user/screens/live_discover_screen.dart`
  - `lib/user/screens/mentor_apply_screen.dart`
  - `lib/admin/screens/mentor/mentor_management_screen.dart`
  - `lib/core/services/firestore/mentor_service.dart`

### [2026-06-03] — Nâng cấp Livestream TikTok-Style, Nạp/Rút Coin & Gửi Quà
- **Tính năng:**
  - Hoàn thiện luồng xem **Livestream vuốt dọc** (LiveSwipeFeedScreen) giống hệt TikTok, người dùng xem có thể thả tim, chat, gửi quà tặng.
  - Tích hợp tính năng thanh toán **Nạp Coin** thông qua PayOS (orderType: coin) sử dụng chung webhook với Premium.
  - Tích hợp hệ thống **Rút Tiền** (thủ công) dành cho Mentor: Mentor yêu cầu rút tiền trong WalletScreen, admin duyệt trong tab WithdrawalsScreen. Tiền Coin sẽ bị trừ tạm thời khi gửi yêu cầu và hoàn lại tự động nếu admin từ chối.
  - Xử lý Crop camera dọc cho Livestream để sửa lỗi tỉ lệ khung hình khi chia sẻ màn hình.
  - Thêm chức năng hiển thị **Push Notification** khi có Mentor (mà user follow) đang livestream.
- **File ảnh hưởng:**
  - `lib/core/models/user_model.dart` (thêm `coinBalance`)
  - `lib/core/providers/wallet_provider.dart`
  - `lib/user/screens/wallet/wallet_screen.dart`
  - `lib/admin/screens/withdrawals/withdrawals_screen.dart`
  - `lib/user/screens/live_swipe_feed_screen.dart`
  - `lib/user/screens/profile/profile_screen.dart`
  - `functions/index.js` (Webhooks & Notifications)

### [2026-06-07] — Tích hợp & Xử lý lỗi iOS Screen Sharing (Broadcast Extension)
- **Vấn đề:** 
  - Tính năng chia sẻ màn hình iOS (Livestream) yêu cầu cấu hình Broadcast Upload Extension với AgoraReplayKitExt.
  - Lỗi xung đột phiên bản giữa Xcode 16/CocoaPods và `AgoraRtcEngine_iOS` (4.5.2) khi build.
- **Giải pháp:**
  - Khởi tạo target `GamenectScreenShare` trong dự án Xcode.
  - Hạ `objectVersion` của `project.pbxproj` xuống 54 (từ 70) để khắc phục lỗi không nhận diện được targets của CocoaPods.
  - Cấu hình lại `ios/Podfile` để link chính xác dependency `AgoraRtcEngine_iOS` vào extension target.
  - Khởi tạo file hướng dẫn chi tiết `IOS_SCREEN_SHARE_SETUP.md` giúp setup môi trường cho App Groups và Extension.
  - *Lưu ý:* `SampleHandler.swift` vẫn đang cần được update API (thay thế `initDelegate`) cho tương thích với version mới của SDK Agora.
- **File ảnh hưởng:**
  - `ios/Podfile`
  - `ios/Runner.xcodeproj/project.pbxproj`
  - `ios/GamenectScreenShare/SampleHandler.swift`
  - `IOS_SCREEN_SHARE_SETUP.md` (mới)

### [2026-06-08] — Cập nhật màu sắc Admin Panel, Điều hướng & Icon
- **Thay đổi:**
  - Đổi màu sắc giao diện Admin (AdminApp & Profile Card) từ màu tím nguyên bản sang tông **cam đậm/đồng ấm (Deep Orange)** để đồng nhất với brand.
  - Đổi màu thanh **Top Bar (AppBar)** thành màu tối sang trọng (`#121217`), thêm viền dưới mỏng, và loại bỏ nút đăng xuất (Logout) ở AppBar.
  - Tab Mentor trong Bottom Navigation được đổi icon từ `Icons.school_rounded` sang `Icons.sports_esports_rounded` cho phù hợp hơn với game mentor (sau đó người dùng đổi lại mũ cử nhân theo sở thích).
  - Cho phép admin xem nhanh profile chi tiết của Mentor (chuyển sang màn hình `MentorProfileScreen`) khi click vào **Ảnh đại diện** hoặc **Tên** của họ trên cả danh sách đơn đăng ký lẫn Dialog xem chi tiết.
  - Sửa lỗi cuộc gọi đến tự phát thông báo cho chính mình (do closure của `listenForIncomingCalls` lưu stale `currentUserId` trước khi logout/login). Đã thay đổi để đọc dynamic `FirebaseAuth.instance.currentUser?.uid` ngay lúc nhận event.
  - Sửa lỗi spam thông báo cuộc gọi cũ khi mở lại app bằng cách hỗ trợ parse `startedAt` dạng `Timestamp` & `String`, đồng thời bỏ qua các cuộc gọi không có timestamp hợp lệ.
  - Tự động hủy/dọn dẹp toàn bộ StreamSubscription cuộc gọi khi người dùng đăng xuất trong `AuthWrapper` (`chatProvider.clearAllSubscriptions()`).
- **File ảnh hưởng:**
  - `lib/admin/admin_app.dart`
  - `lib/user/screens/profile/profile_screen.dart`
  - `lib/admin/screens/mentor/mentor_management_screen.dart`
  - `lib/core/providers/chat_provider.dart`
  - `lib/main.dart`

### [2026-06-10] — Nâng cấp Giao diện Khám phá Mentor Posts & Grid View Responsive
- **Thay đổi:**
  - Tạo mới tính năng xem bài viết (posts) của Mentor trong tab Moments (Khám phá Mentor Posts). Dữ liệu được fetch từ tất cả mentors và cache vào `MentorMediaFeedScreen.mentorCache`.
  - Hỗ trợ 2 chế độ hiển thị linh hoạt trong `MentorMediaFeedScreen`:
    1. **Chế độ vuốt toàn màn hình (Page View / TikTok-style)**: Chỉnh sửa lại `BoxFit` của hình ảnh từ `cover` thành `contain`, và căn giữa (`Center`) VideoPlayer để tôn trọng tỷ lệ gốc của media, không bị cắt xén (crop), viền thừa sẽ tự động đổ nền đen.
    2. **Chế độ lưới (Grid View)**: Tạo mới component `MentorGridItem` hiển thị dạng ô vuông, có đầy đủ avatar, tên và caption overlay bên trên ảnh/video thumb.
  - Thêm một thanh tìm kiếm Glassmorphism nổi (floating) ở đáy màn hình lưới `MentorMediaFeedScreen` để tìm kiếm bài viết theo nội dung caption hoặc tên mentor. Thanh tìm kiếm trượt mượt mà theo bàn phím (nhờ `resizeToAvoidBottomInset: false` và `viewInsets.bottom`) và sẽ tự động ẩn đi khi chuyển sang chế độ lướt (Feed).
  - Khắc phục tình trạng "ảnh bự chà bá" trên nền tảng Web/Desktop đối với các màn hình Grid View (Của tôi, Khám phá, Mentor Posts) bằng cách chuyển từ `SliverGridDelegateWithFixedCrossAxisCount` (ép cứng 2 cột) sang `SliverGridDelegateWithMaxCrossAxisExtent` (`maxCrossAxisExtent: 250`). Điều này giúp lưới tự động thêm số cột tuỳ theo độ rộng thiết bị (2 cột trên mobile, 3-8 cột trên Web).
- **File ảnh hưởng:**
  - `lib/user/screens/mentor/mentor_media_feed_screen.dart`
  - `lib/user/screens/mentor/all_mentor_media_screen.dart`
  - `lib/user/screens/moments/moment_feed_tab.dart`
  - `lib/user/screens/moments/my_moments_tab.dart`
  - `lib/user/screens/moments/discover_mentor_posts_page.dart`

### [2026-06-12] — Tối ưu hóa Camera Locket Cam, Wallet UI, Discover Hub & Dynamic Status Bar
- **Thay đổi:**
  - **Tối ưu hóa Camera & Bộ lọc Locket Cam**:
    * Chuyển đổi luồng chụp ảnh sang xem trước thành **tức thời (0ms delay)**, bỏ hộp thoại đè "Đang tối ưu ảnh" sau khi shutter click.
    * Đưa luồng nén ảnh EXIF và áp bộ lọc màu CPU Isolate xuống bước tải lên (`_uploadAndPost`), lồng dưới vòng xoay tiến trình chính để không làm gián đoạn trải nghiệm chụp.
    * Tích hợp bộ lọc màu **Locket Cam** mới (`R * 1.06 + 15, G * 1.02 + 8, B * 1.18 + 28`) giúp da trắng hồng hào rực rỡ, khử sạch hoàn toàn các sắc vàng ấm cũ.
    * Đồng bộ hóa ma trận màu này trực tiếp lên widget `ColorFiltered` của màn hình xem trước (Preview) thông qua phần cứng (GPU).
    * Loại bỏ hoàn toàn bộ lọc làm mờ da (Orton blur/Gaussian) để ảnh giữ nguyên độ sắc nét cao ("sáng trong") tự nhiên như Locket.
    * Khắc phục triệt để lỗi lật ngang ảnh (mirror) bị ngược chiều trên camera trước bằng cách loại bỏ các thao tác lật ảnh thủ công trùng lặp.
    * Dọn dẹp sạch toàn bộ cảnh báo tĩnh (static warnings/unused imports) trong các file camera.
  - **Giao diện Ví & Lịch sử Nạp Coin**:
    * Đồng bộ hóa thiết kế 4 thẻ gói Coin (100, 500, 1000, 5000) về chung một quy chuẩn giao diện B&W Neo-Brutalism.
    * Tích hợp stream Firestore `getMyCoinOrders()` trong `WalletProvider` hiển thị lịch sử nạp coin realtime tại tab Nạp tiền.
  - **Thiết kế Hub Khám phá (Discover Hub) & Sửa lỗi cuộn**:
    * Nhập hai cột "Trending Games" và "Mentor Posts" hiển thị chung trên một màn hình `DiscoverHubPage` duy nhất.
    * Khóa cử chỉ cuộn nội bộ bằng `NeverScrollableScrollPhysics` để tránh xung đột gesture, cho phép vuốt dọc bubbled thẳng lên PageView cha nhằm xem Moments kế tiếp tức thì.
    * Hỗ trợ đổi nền sáng/tối tự động và áp dụng các nút viền lệch Neo-Brutalism B&W cho các nút hành động trên thẻ.
  - **Giao diện bài viết Mentor (Mentor Media Feed)**:
    * Thiết lập màu nền đệm chứa ảnh/video sang màu đen tuyền (`Colors.black`) thay vì xám để tôn ảnh đúng tỷ lệ contain.
    * Nâng cấp các viền lệch và bóng đổ của avatar/tên/nút tim sang màu đen/trắng động theo độ sáng màn hình.
  - **Nút bấm Neo-Brutalism Trang cá nhân (Profile)**:
    * Nâng cấp toàn bộ các nút bấm tại card Mentor Dashboard, Location và nút **Quản lý** của ví Coin sang phong cách viền dày kèm bóng lệch (`Offset(3, 3)`) đen trắng động.
  - **Thanh trạng thái hệ thống động (System Status Bar)**:
    * Cấu hình `systemOverlayStyle` trong `AppBarTheme` của cả hai giao diện sáng/tối trong `app_theme.dart`.
    * Bọc MaterialApp của `user_app.dart` bằng `AnnotatedRegion<SystemUiOverlayStyle>` động để ép hệ thống đổi đồng hồ/wifi/pin điện thoại sang màu đen khi nền sáng, và màu trắng khi nền tối một cách mượt mà và tự động trên mọi màn hình.
- **File ảnh hưởng:**
  - `lib/user/screens/camera/camera_capture_screen.dart`
  - `lib/user/screens/camera/camera_preview_view.dart`
  - `lib/user/screens/wallet/wallet_screen.dart`
  - `lib/core/providers/wallet_provider.dart`
  - `lib/user/screens/moments/discover_hub_page.dart`
  - `lib/user/screens/moments/moment_feed_tab.dart`
  - `lib/user/screens/mentor/mentor_media_feed_screen.dart`
  - `lib/user/screens/profile/profile_screen.dart`
  - `lib/core/theme/app_theme.dart`
  - `lib/user/user_app.dart`

### [2026-06-12 — Phiên 2] — Tối ưu UI Livestream Neo-Brutalism, Gift Animation & Sửa Màu Chữ Nút Admin

- **Thay đổi:**
  - **Refactor UI Livestream Neo-Brutalism & Sửa Lỗi Gift Animation**:
    * Cập nhật giao diện phòng livestream (`live_stream_screen.dart`) và màn hình vuốt livestream TikTok-style (`live_swipe_feed_screen.dart`) sang phong cách Neo-Brutalism: viền đen dày, bóng đổ lệch đen/trắng, các nút tròn/badges có màu sắc tương phản cao (màu vàng hổ phách, xanh dương).
    * Thiết kế lại Bottom Sheet tặng quà với tiêu đề in đậm thô ("TẶNG QUÀ"), tăng khoảng cách và tỷ lệ hiển thị lưới các ô quà để tránh lỗi tràn màn hình (overflow), hỗ trợ các hiệu ứng đổ bóng Neo.
    * Tích hợp ShaderMask tạo dải màu (gradient) độc đáo cho từng loại icon quà tặng (Tim - đỏ hồng, Sao - hổ phách, Kim cương - xanh lục bảo, Vương miện - vàng kim).
    * Sửa lỗi hiệu ứng tặng quà "bự chà bá" trên màn hình của mentor/host bằng cách liên kết state hiển thị animation quà tặng thông qua stream tin nhắn realtime từ Firestore. Giờ đây cả người xem và mentor đều thấy hiệu ứng hoạt ảnh quà tặng xuất hiện đồng bộ trên màn hình.
    * Sửa lỗi tự động reload lại toàn bộ danh sách khi nhấn nút follow mentor trên màn hình khám phá livestream (`live_discover_screen.dart`).
  - **Sửa Màu Chữ Nút Quản Trị Hệ Thống**:
    * Khắc phục lỗi nút "Mở" của khu vực Admin Panel trên trang cá nhân (`profile_screen.dart`) bị ẩn chữ khi chuyển sang giao diện sáng (do màu nền đổi thành trắng nhưng màu chữ vẫn bị khoá cứng là `Colors.white`).
    * Chuyển đổi màu chữ của nút sang `context.textColor` động để tự động chuyển sang màu đen thô (`#1C1C1E`) ở giao diện sáng và giữ màu trắng (`Colors.white`) ở giao diện tối.
  - **Khóa vuốt dọc (Up/Down) của CardSwiper**:
    * Khóa cử chỉ vuốt dọc (trên/dưới) trên màn hình tìm bạn (`match_screen.dart`) bằng cách cấu hình `allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true, up: false, down: false)`. Điều này giúp người dùng khi vuốt dọc xem thông tin chi tiết của profile sẽ không bị hệ thống hiểu nhầm thành cử chỉ quẹt thẻ (tránh bị nhảy sang người khác), chỉ giữ lại hai hướng quẹt trái/phải hợp lệ.
  - **Tối ưu hóa Hiệu năng Web & Stream Caching**:
    * **Khắc phục lỗi giật lag phòng chat (`chat_screen.dart`)**: Chuyển luồng lấy tin nhắn realtime và kiểm tra typing trạng thái của đối phương từ việc gọi trực tiếp `chatProvider.messagesStream` / `chatProvider.peerTypingStream` trong phương thức `build` sang lưu trữ tĩnh dưới dạng biến trạng thái (`_messagesStream`, `_peerTypingStream`) khởi tạo duy nhất một lần tại `initState`. Điều này loại bỏ hoàn toàn việc tạo mới kết nối/lắng nghe lặp đi lặp lại hàng nghìn lần trên mỗi frame/khi gõ chữ, tăng tốc độ phản hồi đáng kể.
    * **Loại bỏ scroll giật cục**: Loại bỏ callback `WidgetsBinding.instance.addPostFrameCallback` tự động scroll cưỡng bức `animateTo(0.0)` mỗi khi stream có cập nhật mới trong builder, giúp người dùng cuộn xem lịch sử tin nhắn mượt mà, không bị giật lùi màn hình.
    * **Tối ưu hóa tải ảnh và bộ nhớ đệm (Web Cache)**: Tạo widget dùng chung mới `GamenectNetworkImage` (`network_image.dart`) tự động phân biệt nền tảng: trên Web sử dụng `Image.network` tận dụng tối đa cơ chế lưu trữ đệm (disk cache) phần cứng của trình duyệt (không bị mất cache khi reset app) và tối ưu hóa giải nén; trên Mobile tiếp tục dùng `CachedNetworkImage` của `flutter_cache_manager` cho luồng offline. Tích hợp widget này vào danh sách tương hợp (`match_list_screen.dart`) để tối ưu hóa đáng kể tốc độ load ảnh đại diện của Web.
- **File ảnh hưởng:**
  - `lib/user/screens/profile/profile_screen.dart`
  - `lib/user/screens/live/live_stream_screen.dart`
  - `lib/user/screens/live/live_swipe_feed_screen.dart`
  - `lib/user/screens/live/live_discover_screen.dart`
  - `lib/user/screens/matching/match_screen.dart`
  - `lib/user/screens/chat/chat_screen.dart`
  - `lib/core/widgets/network_image.dart`
  - `lib/user/screens/matching/match_list_screen.dart`

### [2026-06-12 — Phiên 3] — Tối ưu hóa Hiệu năng Web & Đồng bộ Stream Caching Toàn bộ Ứng dụng

- **Thay đổi:**
  - **Tải ảnh Web Cache & Mượt mà UI**:
    * Mở rộng việc sử dụng `GamenectNetworkImage` cho tất cả các màn hình còn lại sử dụng ảnh mạng, đảm bảo ảnh được lưu đệm (disk cache) tự nhiên bởi trình duyệt Web và mượt mà hơn khi tải.
    * Thay thế `CachedNetworkImage` bằng `GamenectNetworkImage` tại các màn hình:
      * Trang danh sách thích tôi (`liked_me_screen.dart`)
      * Danh sách game hot (`game_trending_screen.dart`) và Chi tiết game (`game_detail_screen.dart`)
      * Feed bài viết Mentor (`mentor_media_feed_screen.dart`)
      * Chọn ảnh đại diện trong Cài đặt cá nhân (`avatar_picker_section.dart`)
      * Bong bóng tin nhắn chat (`message_bubble.dart`)
      * Trình xem media toàn màn hình (`full_screen_media_viewer.dart`)
      * Vật phẩm bài viết moments (`moment_grid_item.dart` và `moment_card.dart`).
    * Chuyển đổi `MomentGridItem` và `MomentCard` sang lưu trữ Future thông tin người dùng (`_userInfoFuture`) trong State để tránh query liên tục khi danh sách cuộn dọc.
  - **Khắc phục Rebuild Storms & Firestore Connection Leak**:
    * Chuyển đổi các màn hình từ `StatelessWidget` sang `StatefulWidget` và lưu cache các Stream/Future của Firestore trong `initState` thay vì khởi tạo trực tiếp trong hàm `build`:
      * `all_mentor_media_screen.dart`: Chuyển sang `StatefulWidget` và cache Stream danh sách bài viết Mentor.
      * `mentor_media_screen.dart`: Cache Stream media của Mentor.
      * `mentor_requests_screen.dart`: Chuyển sang `StatefulWidget` và cache Stream danh sách đơn đăng ký Mentor.
      * `wallet_screen.dart`: Cache Stream lịch sử đơn nạp tiền trong `_TopupTabState` và Stream đơn rút tiền trong `_WithdrawTabState`.
      * `mentor_profile_screen.dart`: Cache ratings và media Stream trong profile Mentor. Đồng thời chuyển đổi `_MentorFollowerSheet` thành `StatefulWidget` và tích hợp `Map<String, Future<DocumentSnapshot>>` để lưu đệm thông tin của followers, tránh query Firestore khi cuộn danh sách người theo dõi.
      * `video_call_screen.dart`: Cache Stream trạng thái cuộc gọi để tránh việc timer đếm giây (1s/tick) trigger build làm tạo mới kết nối Firestore liên tục gây nghẽn mạng trên Web.
- **File ảnh hưởng:**
  - `lib/user/screens/matching/liked_me_screen.dart`
  - `lib/user/screens/games/game_trending_screen.dart`
  - `lib/user/screens/games/game_detail_screen.dart`
  - `lib/user/screens/mentor/mentor_media_feed_screen.dart`
  - `lib/user/screens/profile/avatar_picker_section.dart`
  - `lib/user/screens/chat/message_bubble.dart`
  - `lib/user/screens/chat/full_screen_media_viewer.dart`
  - `lib/user/screens/moments/moment_grid_item.dart`
  - `lib/user/screens/moments/moment_card.dart`
  - `lib/user/screens/mentor/all_mentor_media_screen.dart`
  - `lib/user/screens/mentor/mentor_media_screen.dart`
  - `lib/user/screens/mentor/mentor_requests_screen.dart`
  - `lib/user/screens/wallet/wallet_screen.dart`
  - `lib/user/screens/mentor/mentor_profile_screen.dart`
  - `lib/user/screens/call/video_call_screen.dart`

### [2026-06-12 — Phiên 4] — Sửa lỗi Camera Preview Web, Thêm Nút Lật Ảnh & Nâng Cao Chất Lượng Ảnh Đăng Moment

- **Thay đổi:**
  - **Sửa lỗi Preview trống trên Web**:
    * Chuyển đổi `CameraPreviewView` để phát hiện nền tảng Web (`kIsWeb`), load ảnh bằng `Image.network` thay vì `Image.file` (gây lỗi crash trên Web do `dart:io` không hỗ trợ).
  - **Thêm tính năng Lật ảnh (Mirror Toggle) & Tự động bật mặc định**:
    * Thêm nút **LẬT ẢNH** thiết kế Neo-Brutalism ở góc trên bên phải khung preview ảnh moment.
    * Khi chọn/chụp ảnh trên Web, hệ thống tự động tải bytes thông qua `_webImageBytes` và mặc định bật lật ảnh gương (`_isMirrored = true`) để tiện lợi nhất khi chụp selfie. Người dùng vẫn có thể click nút để tắt đi nếu chụp bằng camera sau.
    * Khi người dùng nhấn đăng ảnh, nếu trạng thái lật ảnh được kích hoạt, hệ thống sẽ chạy tác vụ isolate `_applyMirrorIsolate` để lật pixel hình ảnh thực tế trước khi tải lên.
  - **Nâng cao chất lượng ảnh (HD & 90% Quality)**:
    * Cấu hình nâng cao chất lượng chọn ảnh từ gallery và camera trên Web từ chất lượng 80% lên **90%** (`imageQuality: 90`).
    * Tăng kích thước ảnh tối đa từ 800px lên **1080px** (`maxWidth: 1080`) để ảnh đạt độ sắc nét chuẩn Full HD.
- **File ảnh hưởng:**
  - `lib/user/screens/camera/camera_preview_view.dart`
  - `lib/user/screens/camera/camera_capture_screen.dart`
  - `lib/user/screens/main/main_screen.dart`


---

## 11. UI/UX & AESTHETIC GUIDELINES (NEO-BRUTALISM + GLASSMORPHISM)

**GameNect** áp dụng phong cách thiết kế kết hợp độc đáo giữa **Neo-Brutalism** (Thô mộc hiện đại) và **Glassmorphism** (Hiệu ứng kính mờ). Đây là phong cách chủ đạo bắt buộc phải tuân thủ khi xây dựng giao diện mới hoặc chỉnh sửa các thành phần hiện tại.

### 11.1. Nguyên tắc thiết kế chung (Core Aesthetics)
- **Border:** Các thành phần UI có thể tương tác (nút, thẻ, input) đều PHẢI có viền đen/trắng nét dày, rõ ràng (e.g., `border: Border.all(color: Colors.black, width: 3)`).
- **Shadow (Bóng đổ):** Không dùng bóng đổ mờ (blur). PHẢI dùng bóng đổ đặc (solid drop shadow) chệch về góc dưới bên phải (e.g., `boxShadow: [BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0)]`).
- **Hình dáng (Shapes):** Ưu tiên các góc bo tròn lớn (`borderRadius: BorderRadius.circular(16)` hoặc `50` cho các thành phần dạng pill).
- **Glassmorphism:** Sử dụng `BackdropFilter` với `sigmaX: 10, sigmaY: 10` cho các thành phần trôi nổi (floating) như thanh điều hướng (Bottom Bar), popup, overlay thông báo.
- **Màu sắc (Colors):**
  - **Màu Accent (Chủ đạo):** Cam Neon rực rỡ (`Color(0xFFFF6E40)`).
  - **Màu Alert/Badge:** Đỏ Neon (`Color(0xFFFF2D55)`).
  - **Màu Cảnh báo/Khác:** Vàng Neon (`Color(0xFFFFD54F)`).
  - **Màu nền (Background):** Trắng/Trắng ngà (`#F4F4F0`) cho chế độ Sáng, Đen tuyền/Xám đen (`#121214`) cho chế độ Tối.
- **Typography:** Text trên các nút bấm hoặc tiêu đề phải in đậm (Bold/Black), font không chân (Sans-serif) với `fontWeight: FontWeight.w900`.

### 11.2. Hướng dẫn thiết kế theo Từng Màn Hình & Thành Phần
Dựa trên kiến trúc hiện tại, UI của các màn hình được quy định như sau:

#### A. Thanh Điều Hướng (Bottom Navigation Bar)
- **Hình dáng:** Dạng viên thuốc nổi (Floating Pill) cách mép màn hình một khoảng.
- **Background:** Hiệu ứng kính mờ (Glassmorphism) với nền xám/trắng bán trong suốt.
- **Border & Shadow:** Viền đen dày (3px) và bóng đổ đặc (solid shadow) màu đen.
- **Trạng thái Active (Đang chọn):** Icon và Text được bọc trong một khối pill màu Cam (`_kAccent`), có viền đen và bóng đổ đặc biệt nhấn mạnh. Text in đậm (`w900`).
- **Trạng thái Inactive (Chưa chọn):** Icon nét mỏng hoặc solid màu xám/đen. Text mỏng hơn.
- **Badges (Chấm đỏ thông báo):** Đặt ở góc trên bên phải icon. Dạng hình tròn màu Đỏ (`_kLiveRed`), text trắng, viền ngoài màu đen (2px).

#### B. Màn hình Discover / Swipe Screen
- **Card Swipe:** Các thẻ người dùng giống Tinder nhưng tuân thủ Neo-Brutalism (Viền đen 3px, bo góc 24px, bóng đổ đặc dưới thẻ).
- **Typography:** Tên user, Tuổi in cực lớn và đậm trên ảnh nền.
- **Buttons (Like/Pass):** Các nút hình tròn to, màu nổi (Đỏ/Xanh/Vàng) với viền đen và solid shadow. Khi ấn vào, shadow thu nhỏ lại tạo cảm giác nút bị lún xuống vật lý.

#### C. Màn hình Moment / Feed Screen
- **Hình ảnh:** Trải toàn màn hình (Edge-to-edge) hoặc bo góc vuông vắn.
- **Controls/Overlays:** Các nút tim, bình luận hiển thị lơ lửng trên nền ảnh bằng hiệu ứng Glassmorphism (Kính mờ) để không bị chìm vào nền ảnh nhiều chi tiết.
- **Caption:** Bọc trong một vùng Glassmorphism dưới đáy màn hình.

#### D. Màn hình Chat (Chat Screen)
- **Chat Bubbles (Bong bóng chat):** 
  - Tin nhắn của mình: Nền màu Cam (`_kAccent`), viền đen, bo góc tròn, đuôi bong bóng nhọn.
  - Tin nhắn đối phương: Nền xám/trắng, viền đen.
- **Input Bar:** Nằm dưới cùng, bo góc `24px`, viền đen, có bóng đổ đặc. Nút Send (Gửi) hình tròn, viền đen.

#### E. Màn hình Mentor / Public Media Screen
- **Grid Layout:** Lưới ảnh/video có khoảng cách (gutter) rộng, mỗi ảnh có viền đen mỏng để tách biệt.
- **CTA Buttons:** Các nút như "Ủng hộ", "Theo dõi", "Đăng ký Premium" là nút Neo-Brutalism kích thước lớn, chiều ngang full chiều rộng, padding lớn (`vertical: 14`), chữ IN HOA đậm.

#### F. Các Thành Phần Cơ Bản (Widgets)
- **Buttons (Nút bấm):** Phải có `Container` viền đen, bóng đổ `Offset(4,4)`. Dùng `GestureDetector` đổi màu shadow khi tap (nhấn xuống).
- **Text Inputs (Khung nhập liệu):** Nền trắng/xám sáng, viền đen 2-3px. Khi Focus (đang nhập) viền đổi sang màu Cam.
- **Avatar (Ảnh đại diện):** Bo tròn, viền ngoài màu đen (thêm viền Cam nếu đang có Story/Moment chưa xem).
- **Cards (Khối nội dung):** Background sáng màu, viền đen 3px, bóng đổ đặc 4px.

*Tất cả AI Agent khi code layout mới hoặc refactor UI phải sử dụng đúng mã màu và cấu trúc Shadow, Border như mô tả trên để giữ sự nhất quán 100% cho GameNect.*

### [2026-06-16 — Phiên 5] — Tối ưu hóa Database Reads và Storage Bandwidth

- **Thay đổi:**
  - **Tối ưu hóa Firestore Reads (Giảm chi phí cực lớn):**
    * Thêm `.limit(50)` vào `getApprovedMentors` trong `MentorService`, đồng thời gỡ bỏ truy vấn N+1 (truy vấn lồng nhau) tìm kiếm livestream đang hoạt động. Livestream giờ sẽ được tìm qua một bảng riêng hoặc snapshot trực tiếp để không bị lặp.
    * Thêm `.orderBy('timestamp', descending: true).limit(50)` vào `messagesStream` trong `ChatService`. Sau đó đảo ngược mảng (reversed) trên Client để UI chat hiển thị đúng (tin nhắn mới nhất ở dưới). Chặn đứng tình trạng load hàng ngàn tin nhắn cũ mỗi khi mở đoạn chat.
  - **Tối ưu hóa Firebase Storage Bandwidth (Tránh cạn kiệt Egress):**
    * Gỡ bỏ điều kiện chỉ nén cho Camera Trước trong `camera_capture_screen.dart`. Bắt buộc 100% Ảnh chụp từ App (bằng CameraAwesome) phải được đưa qua Isolate để nén trước khi tải lên Firebase. Giảm `quality` từ 95 xuống 80 (giảm dung lượng xuống mức 200KB - 400KB).
    * Giới hạn chất lượng Video khi quay trực tiếp từ App: Chuyển cấu hình `VideoOptions` của CameraAwesome sang `VideoRecordingQuality.sd` thay vì mặc định phân giải gốc. Dung lượng video từ 50MB giảm xuống còn vài MB.
    * Giới hạn thời gian Video tối đa: Giảm từ 15 giây xuống **5 giây** trong tất cả các giao diện quay/chụp và Gallery Upload (`camera_capture_screen.dart`, `mentor_media_screen.dart`). Cực kỳ tiết kiệm chi phí băng thông khi người dùng lướt feed có cơ chế Pre-load (Tải trước).
- **File ảnh hưởng:**
  - `lib/core/services/firestore/mentor_service.dart`
  - `lib/core/services/firestore/chat_service.dart`
  - `lib/user/screens/camera/camera_capture_screen.dart`
  - `lib/user/screens/mentor/mentor_media_screen.dart`

