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
3. Nhận `checkoutUrl` → mở `flutter_web_browser`
4. PayOS webhook (Cloud Function `payosWebhook`) gọi về → update order + activate premium
5. App poll qua `checkPaymentStatus()` hoặc lắng nghe Firestore

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
| `location_settings_screen.dart` | Cài đặt vị trí, filter matching |
| `game_trending_screen.dart` | Danh sách game trending từ RAWG |
| `game_detail_screen.dart` | Chi tiết game từ RAWG |
| `admin_test_users_screen.dart` | Màn hình test tạo user giả (dành cho dev admin) |

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

---

*Tài liệu này được tạo tự động bởi AI agent. Cập nhật: 2026-05-03.*
