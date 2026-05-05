# Gamenect — Mentor & Livestream Feature Plan

> **Dành cho AI Agent:** Đọc toàn bộ file này trước khi viết bất kỳ dòng code nào.
> Dự án dùng Flutter + Firebase + Agora. Design system: **Liquid Glass** (dark bg #101012, accent #FF6E40).
> State management: **Provider only** — không dùng setState khi có Provider, không dùng Riverpod.

---

## 1. TỔNG QUAN TÍNH NĂNG

Thêm **role Mentor** vào Gamenect — người dùng có thể đăng ký làm Mentor (chuyên gia game), Admin duyệt, và Mentor có thể phát **Livestream** hướng dẫn chơi game cho nhiều người xem.

### Nguyên tắc thiết kế:
- Mentor vẫn là User bình thường + có thêm quyền livestream
- User follow Mentor → nhận notification khi Mentor live (không nhắn tin được ngay)
- User gửi Match Request → Mentor duyệt → mới được chat 1-1
- Livestream dùng **Agora RTC** (đã có sẵn trong app, role: Broadcaster/Audience)
- Chat trong stream dùng **Firestore realtime** (đã có sẵn)
- Gift system dùng **coin ảo** (không cần payment gateway thật)

---

## 2. THAY ĐỔI FIRESTORE SCHEMA

### 2.1. Cập nhật collection `users`
Thêm các fields mới vào document `users/{userId}`:
```
isMentor: bool (default: false)
mentorStatus: 'none' | 'pending' | 'approved' | 'rejected'  (default: 'none')
coins: int (default: 0)  // coin ảo để tặng gift
totalCoinsReceived: int (default: 0)  // tổng coin Mentor nhận được
```

### 2.2. Collection mới: `mentor_profiles`
```
mentor_profiles/{userId}: {
  userId: String,
  games: List<String>,         // ['LMHT', 'Valorant', ...]
  bio: String,                 // "Tôi là Thách Đấu mùa 10..."
  achievements: String,        // clip/rank evidence mô tả
  rating: double,              // 0.0 - 5.0 (tính từ reviews)
  totalReviews: int,
  followerCount: int,
  totalStreams: int,
  totalGiftsReceived: int,
  appliedAt: Timestamp,
  approvedAt: Timestamp?,
  rejectedAt: Timestamp?,
  rejectReason: String?,
}
```

### 2.3. Collection mới: `mentor_followers`
```
mentor_followers/{mentorId}_{followerId}: {
  mentorId: String,
  followerId: String,
  followedAt: Timestamp,
}
```
> Index cần tạo: `mentorId` (để lấy tất cả followers của 1 mentor)
> Index cần tạo: `followerId` (để lấy tất cả mentor mà 1 user đang follow)

### 2.4. Collection mới: `livestreams`
```
livestreams/{streamId}: {
  mentorId: String,
  mentorUsername: String,
  mentorAvatarUrl: String,
  title: String,
  game: String,
  agoraChannel: String,     // = streamId (dùng làm Agora channel name)
  status: 'live' | 'ended',
  viewerCount: int,
  startedAt: Timestamp,
  endedAt: Timestamp?,
  thumbnailUrl: String?,    // snapshot đầu stream (optional)
}
```

### 2.5. Subcollection `livestreams/{streamId}/messages`
```
{msgId}: {
  userId: String,
  username: String,
  avatarUrl: String?,
  text: String,
  timestamp: Timestamp,
  type: 'text' | 'gift',    // gift khi tặng quà
  giftType: String?,        // 'heart' | 'star' | 'diamond' | 'crown'
  giftCoinValue: int?,
}
```

### 2.6. Collection mới: `coin_transactions`
```
coin_transactions/{txId}: {
  fromUserId: String,
  toMentorId: String,
  giftType: String,
  coinValue: int,
  streamId: String,
  timestamp: Timestamp,
}
```

### 2.7. Collection mới: `mentor_match_requests`
```
mentor_match_requests/{requestId}: {
  fromUserId: String,
  toMentorId: String,
  status: 'pending' | 'accepted' | 'rejected',
  message: String?,       // lời nhắn khi gửi request
  createdAt: Timestamp,
  respondedAt: Timestamp?,
}
```

---

## 3. MODELS CẦN TẠO

### Task 3.1 — Tạo `lib/core/models/mentor_model.dart`
```dart
class MentorModel {
  final String userId;
  final List<String> games;
  final String bio;
  final String achievements;
  final double rating;
  final int totalReviews;
  final int followerCount;
  final int totalStreams;
  final int totalGiftsReceived;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime appliedAt;
  final DateTime? approvedAt;

  // Factory fromMap, toMap, copyWith — chuẩn theo pattern UserModel
}
```

### Task 3.2 — Tạo `lib/core/models/livestream_model.dart`
```dart
class LivestreamModel {
  final String id;
  final String mentorId;
  final String mentorUsername;
  final String mentorAvatarUrl;
  final String title;
  final String game;
  final String agoraChannel;
  final String status; // 'live' | 'ended'
  final int viewerCount;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? thumbnailUrl;

  // Factory fromMap, toMap, copyWith
}
```

### Task 3.3 — Tạo `lib/core/models/mentor_match_request_model.dart`
```dart
class MentorMatchRequestModel {
  final String id;
  final String fromUserId;
  final String toMentorId;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;

  // Factory fromMap, toMap, copyWith
}
```

---

## 4. FIRESTORE SERVICE — METHODS CẦN THÊM

> **File:** `lib/core/services/firestore_service.dart`
> Thêm vào cuối file, KHÔNG sửa code hiện có.

### 4.1. Mentor Profile CRUD
```dart
// Tạo đơn đăng ký Mentor
Future<void> applyForMentor(String userId, MentorModel mentor)

// Lấy mentor profile
Future<MentorModel?> getMentorProfile(String userId)

// Stream mentor profile realtime
Stream<MentorModel?> getMentorProfileStream(String userId)

// Admin: lấy tất cả đơn pending
Stream<List<MentorModel>> getPendingMentorApplications()

// Admin: duyệt mentor
Future<void> approveMentor(String userId)

// Admin: từ chối mentor
Future<void> rejectMentor(String userId, String reason)

// Lấy danh sách mentor đã approved (cho Discover tab)
Future<List<Map<String, dynamic>>> getApprovedMentors({String? gameFilter})
```

### 4.2. Follow System
```dart
// Follow mentor
Future<void> followMentor(String mentorId, String followerId)

// Unfollow mentor
Future<void> unfollowMentor(String mentorId, String followerId)

// Kiểm tra đã follow chưa
Future<bool> isFollowingMentor(String mentorId, String followerId)

// Lấy danh sách followers của mentor (để gửi notification)
Future<List<String>> getMentorFollowerIds(String mentorId)
```

### 4.3. Livestream CRUD
```dart
// Tạo stream mới (Mentor bắt đầu live)
Future<String> createLivestream(LivestreamModel stream)

// Kết thúc stream
Future<void> endLivestream(String streamId)

// Lấy danh sách stream đang live
Stream<List<LivestreamModel>> getLivestreams({String? gameFilter})

// Update viewer count
Future<void> updateViewerCount(String streamId, int count)

// Gửi message trong stream
Future<void> sendStreamMessage(String streamId, Map<String, dynamic> message)

// Stream messages realtime
Stream<List<Map<String, dynamic>>> getStreamMessages(String streamId)
```

### 4.4. Gift & Coin System
```dart
// Tặng gift (transaction: trừ coin user, cộng coin mentor, ghi log)
Future<void> sendGift({
  required String fromUserId,
  required String toMentorId,
  required String streamId,
  required String giftType,
  required int coinValue,
})

// Lấy coin balance của user
Future<int> getUserCoins(String userId)

// Admin cấp coin cho user (test)
Future<void> grantCoins(String userId, int amount)
```

### 4.5. Mentor Match Request
```dart
// Gửi match request tới mentor
Future<void> sendMentorMatchRequest(String fromUserId, String toMentorId, String? message)

// Mentor: lấy danh sách request pending
Stream<List<MentorMatchRequestModel>> getMentorMatchRequests(String mentorId)

// Mentor: chấp nhận request → tạo match thật
Future<void> acceptMentorMatchRequest(String requestId, String fromUserId, String mentorId)

// Mentor: từ chối request
Future<void> rejectMentorMatchRequest(String requestId)

// Kiểm tra đã có request chưa
Future<String?> checkExistingMatchRequest(String fromUserId, String toMentorId)
```

---

## 5. PROVIDERS CẦN TẠO/SỬA

### Task 5.1 — Tạo `lib/core/providers/mentor_provider.dart`

**Quản lý:** Toàn bộ state liên quan đến Mentor

```dart
class MentorProvider extends ChangeNotifier {
  // State
  bool _isLoading = false;
  List<Map<String, dynamic>> _approvedMentors = [];
  MentorModel? _myMentorProfile;
  String? _error;
  String? _selectedGameFilter;

  // Getters
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get approvedMentors => List.unmodifiable(_approvedMentors);
  MentorModel? get myMentorProfile => _myMentorProfile;
  String? get error => _error;
  bool get isMentor => _myMentorProfile?.status == 'approved';
  bool get isPending => _myMentorProfile?.status == 'pending';

  // Actions
  Future<void> loadApprovedMentors({String? gameFilter})
  Future<void> loadMyMentorProfile(String userId)
  Future<void> applyForMentor(String userId, {required List<String> games, required String bio, required String achievements})
  Future<void> followMentor(String mentorId, String followerId)
  Future<void> unfollowMentor(String mentorId, String followerId)
  Future<bool> checkIsFollowing(String mentorId, String followerId)
  Future<void> sendMatchRequest(String fromUserId, String toMentorId, String? message)
}
```

### Task 5.2 — Tạo `lib/core/providers/livestream_provider.dart`

**Quản lý:** State livestream (cho cả streamer lẫn viewer)

```dart
class LivestreamProvider extends ChangeNotifier {
  // State
  bool _isLoading = false;
  List<LivestreamModel> _liveStreams = [];
  LivestreamModel? _currentStream;   // stream đang xem/phát
  List<Map<String, dynamic>> _messages = [];
  int _viewerCount = 0;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  List<LivestreamModel> get liveStreams => List.unmodifiable(_liveStreams);
  LivestreamModel? get currentStream => _currentStream;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  int get viewerCount => _viewerCount;
  bool get isStreaming => _currentStream?.status == 'live';

  // Actions — Mentor side
  Future<String> startStream({required String mentorId, required String title, required String game})
  Future<void> endStream(String streamId)

  // Actions — Viewer side
  Future<void> joinStream(String streamId)
  Future<void> leaveStream(String streamId)
  void listenToMessages(String streamId)
  Future<void> sendMessage(String streamId, String userId, String username, String text)
  Future<void> sendGift({required String streamId, required String fromUserId, required String toMentorId, required String username, required String giftType, required int coinValue})

  // General
  void listenToLiveStreams({String? gameFilter})
  void dispose()
}
```

### Task 5.3 — Sửa `main.dart`

Thêm 2 providers mới vào `MultiProvider`:
```dart
ChangeNotifierProvider(create: (_) => MentorProvider()),
ChangeNotifierProvider(create: (_) => LivestreamProvider()),
```

### Task 5.4 — Sửa `user_app.dart`

Thêm routes mới:
```dart
'/mentor-apply': (ctx) => const MentorApplyScreen(),
'/mentor-profile': (ctx) => const MentorProfileScreen(),  // args: mentorId
'/live-discover': (ctx) => const LiveDiscoverScreen(),
'/live-stream': (ctx) => const LiveStreamScreen(),         // args: streamId, isMentor
'/go-live': (ctx) => const GoLiveScreen(),
'/mentor-requests': (ctx) => const MentorRequestsScreen(),
```

---

## 6. SCREENS CẦN TẠO

> **Tất cả screens phải dùng Liquid Glass design:**
> - Background: `Color(0xFF101012)`
> - Glass container: `BackdropFilter` + `Colors.white.withValues(alpha: 0.08)`
> - Accent color: `Color(0xFFFF6E40)`
> - Border radius lớn: 24-32px

---

### Screen 6.1 — `lib/user/screens/live_discover_screen.dart`

**Mục đích:** Tab Discover — user tìm kiếm Mentor và xem Livestream đang diễn ra

**Layout:**
```
AppBar: "Discover" (Liquid Glass style như GameTrendingScreen)

TabBar (2 tabs):
  [🔴 Đang Live]  [👑 Mentor]

Tab "Đang Live":
  - Filter chip theo game (Tất cả / LMHT / Valorant / PUBG / ...)
  - Grid 2 cột: StreamCard (thumbnail + tên mentor + game + viewer count + LIVE badge)
  - StreamCard bấm vào → navigate '/live-stream' với streamId

Tab "Mentor":
  - Filter chip theo game
  - ListView: MentorCard (avatar + tên + badge ⭐Mentor + games + rating + follower count)
  - MentorCard bấm vào → navigate '/mentor-profile' với mentorId
  - Empty state nếu không có Mentor
```

**State:** dùng `LivestreamProvider` cho tab Live, `MentorProvider` cho tab Mentor

---

### Screen 6.2 — `lib/user/screens/mentor_profile_screen.dart`

**Mục đích:** Trang profile chi tiết của 1 Mentor

**Layout:**
```
Stack:
  - Background blur/gradient
  - ScrollView:
      Avatar (80px) + tên + badge ⭐Mentor
      Games list (chips)
      Rating + follower count + total streams
      Bio text
      Achievements text

  - Bottom action bar (fixed bottom):
      [Follow / Unfollow]  [Xem Live (nếu đang live)]  [Gửi Match Request]
```

**Logic:**
- Load `MentorModel` và `UserModel` của mentor từ Firestore
- Kiểm tra `isFollowingMentor()` để show đúng trạng thái nút Follow
- Kiểm tra `checkExistingMatchRequest()` để show trạng thái nút Match Request
- `sendMatchRequest` mở bottom sheet nhập lời nhắn trước khi gửi
- Nếu mentor đang live → nút "Xem Live" highlight màu đỏ

---

### Screen 6.3 — `lib/user/screens/live_stream_screen.dart`

**Mục đích:** Màn hình xem/phát Livestream

**Layout (Viewer mode):**
```
Stack (full screen):
  AgoraVideoView (background, full screen)

  Overlay top:
    - Tên mentor + avatar (trái)
    - 🔴 LIVE + viewer count (phải)
    - Nút X để thoát (phải)

  Overlay bottom:
    - Chat messages (list cuộn, semi-transparent, 40% màn hình)
    - TextField nhập chat + nút Send
    - Nút Gift (mở bottom sheet chọn gift)

  Gift animation overlay:
    - Khi có gift → hiện animation nổi lên rồi biến mất
    - "User đã tặng 👑 Kim cương!"
```

**Layout (Mentor/Broadcaster mode):**
```
Stack (full screen):
  AgoraVideoView (background)

  Overlay top:
    - Tiêu đề stream (trái)
    - 🔴 LIVE + viewer count (phải)
    - Nút Kết thúc (đỏ, phải)

  Overlay bottom:
    - Chat messages (cuộn)
    - Không có TextField (Mentor không cần chat ở đây)
    - Stats: total gifts received hôm nay
```

**Agora setup:**
```dart
// Viewer
await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
await engine.joinChannel(token: '', channelId: streamId, uid: 0, options: ChannelMediaOptions());

// Mentor/Broadcaster
await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
await engine.enableVideo();
await engine.startPreview();
await engine.joinChannel(token: '', channelId: streamId, uid: 0, options: ChannelMediaOptions());
```

**Lưu ý:** Dùng `AGORA_APP_ID` từ `.env` (đã có sẵn, cùng key với VideoCall)

**Gift Bottom Sheet:**
```
4 loại gift:
  ❤️ Tim      — 1 coin
  ⭐ Ngôi sao — 5 coin
  💎 Hồng ngọc — 20 coin
  👑 Kim cương — 50 coin

Hiển thị số coin hiện có của user
Bấm gift → deduct coins → gửi message type 'gift' vào Firestore → trigger animation
```

---

### Screen 6.4 — `lib/user/screens/go_live_screen.dart`

**Mục đích:** Màn hình Mentor chuẩn bị trước khi bắt đầu stream

**Layout:**
```
AppBar: "Bắt đầu Live"

Camera preview (Agora preview)

Form:
  - TextField: Tiêu đề stream (bắt buộc)
  - Dropdown: Chọn game
  - (Optional) thumbnail

Nút "Bắt đầu Live" (accent color, full width)
  → Tạo Livestream document trong Firestore
  → FCM notify tất cả followers (qua Cloud Function mới)
  → Navigate sang LiveStreamScreen (broadcaster mode)
```

---

### Screen 6.5 — `lib/user/screens/mentor_apply_screen.dart`

**Mục đích:** Form đăng ký trở thành Mentor

**Layout:**
```
AppBar: "Đăng ký Mentor"

ScrollView:
  Illustration / header

  Form:
    - Multi-select: Game chuyên môn (dùng multi_select_flutter — đã có sẵn)
    - TextField (multiline): Giới thiệu bản thân
    - TextField (multiline): Thành tích / kinh nghiệm

  Nút "Gửi đơn đăng ký"
    → Validation
    → FirestoreService.applyForMentor()
    → Show success dialog: "Đơn đã gửi, chờ Admin duyệt"

Trạng thái:
  - Nếu status == 'pending': Hiển thị "Đơn đang chờ duyệt" (không cho gửi lại)
  - Nếu status == 'rejected': Hiển thị lý do + cho phép gửi lại
```

---

### Screen 6.6 — `lib/user/screens/mentor_requests_screen.dart`

**Mục đích:** Mentor xem và xử lý Match Request từ users

**Layout:**
```
AppBar: "Match Requests"

ListView: danh sách requests pending
  Request card:
    - Avatar + tên user
    - Lời nhắn (nếu có)
    - Thời gian gửi
    - [Chấp nhận ✓]  [Từ chối ✗]

  Bấm "Chấp nhận":
    → acceptMentorMatchRequest()
    → Tạo match thật trong collection `matches`
    → Notify user được chấp nhận
    → Xóa request khỏi list

  Bấm "Từ chối":
    → rejectMentorMatchRequest()
    → Xóa khỏi list
```

---

## 7. CẬP NHẬT SCREENS HIỆN CÓ

### Task 7.1 — Sửa `lib/user/screens/main_screen.dart` + Feed Screen

**Bottom Nav KHÔNG thay đổi — giữ nguyên 5 tab:**
```
[Khám phá] [Feed] [Lượt thích] [Tin nhắn] [Hồ sơ]
```

**Feed Screen thêm tab Live ở giữa — thành 3 tab nội bộ:**
```
Trước: [Của tôi]  [Khám phá]
Sau:   [Của tôi]  [🔴 Live]  [Khám phá]
```

**Cách implement trong Feed Screen:**
```dart
// Feed screen dùng TabBar + TabBarView với DefaultTabController
DefaultTabController(
  length: 3,
  initialIndex: 0,
  child: Scaffold(
    appBar: AppBar(
      bottom: TabBar(
        tabs: [
          Tab(text: 'Của tôi'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text('Live'),
              ],
            ),
          ),
          Tab(text: 'Khám phá'),
        ],
      ),
    ),
    body: TabBarView(
      children: [
        MyFeedTab(),        // tab cũ "Của tôi"
        LiveDiscoverScreen(), // tab mới Live
        DiscoverFeedTab(),  // tab cũ "Khám phá"
      ],
    ),
  ),
)

// Với Mentor: FloatingActionButton "Go Live" chỉ hiện khi đang ở tab Live (index 1)
// Dùng TabController.index để kiểm tra
if (isMentor && _tabController.index == 1)
  FloatingActionButton(
    backgroundColor: Color(0xFFFF3B30),
    child: Icon(Icons.videocam),
    onPressed: () => Navigator.pushNamed(context, '/go-live'),
  )
```

**Lưu ý:** `LiveDiscoverScreen` (Task 6.1) được nhúng trực tiếp như 1 tab trong Feed,
không cần navigate riêng — user swipe qua lại tự nhiên như Instagram.

### Task 7.2 — Sửa `lib/user/screens/profile.dart`

Thêm section "Mentor" vào trang profile cá nhân:

```
Nếu chưa là Mentor và chưa apply:
  Card: "Trở thành Mentor" → navigate '/mentor-apply'

Nếu status == 'pending':
  Card: "Đơn đăng ký đang chờ duyệt" (màu amber)

Nếu isMentor == true:
  Card: "Mentor Dashboard"
    - Tổng followers
    - Tổng coin nhận được
    - Số stream đã thực hiện
    - Nút "Xem Match Requests"
```

---

## 8. CLOUD FUNCTION MỚI

### Task 8.1 — Thêm vào `functions/index1.js`

**Function: `sendLiveNotification`**
- Trigger: `onDocumentCreated('livestreams/{streamId}')`
- Logic:
  1. Lấy `mentorId` từ document mới
  2. Query `mentor_followers` where `mentorId == mentorId` → lấy tất cả `followerId`
  3. Với mỗi followerId, lấy `fcmToken` từ `users/{followerId}`
  4. Gửi FCM batch notification

```javascript
// Payload FCM
{
  notification: {
    title: `${mentorUsername} đang Live!`,
    body: `${title} — ${game}`,
  },
  data: {
    type: 'mentor_live',
    streamId: streamId,
    mentorId: mentorId,
  },
  android: { priority: 'high' },
  apns: { payload: { aps: { 'content-available': 1 } } }
}
```

### Task 8.2 — Thêm vào `functions/index.js`

Export function mới:
```javascript
const { sendLiveNotification } = require('./index1');
exports.sendLiveNotification = sendLiveNotification;
```

### Task 8.3 — Thêm handler notification trong `main.dart`

Trong `onActionReceivedMethod`, thêm case mới:
```dart
if (type == 'mentor_live') {
  final streamId = payload['streamId'];
  navigatorKey.currentState?.pushNamed('/live-stream', arguments: {
    'streamId': streamId,
    'isMentor': false,
  });
}
```

---

## 9. ADMIN SCREENS CẬP NHẬT

### Task 9.1 — Tạo `lib/admin/screens/mentor_management_screen.dart`

**Layout:**
```
AppBar: "Quản lý Mentor"

TabBar:
  [Chờ duyệt (n)]  [Đã duyệt]  [Đã từ chối]

Tab "Chờ duyệt":
  ListView applications
  ApplicationCard:
    - Avatar + username
    - Games list
    - Bio (truncated)
    - Thành tích
    - [Xem chi tiết]  [Duyệt ✓]  [Từ chối ✗]

  Bấm "Từ chối" → Dialog nhập lý do → rejectMentor()
  Bấm "Duyệt" → approveMentor() → users/{id}.isMentor = true
```

### Task 9.2 — Sửa `lib/admin/screens/dashboard_screen.dart`

Thêm metrics:
- Tổng số Mentor đang hoạt động
- Số đơn Mentor đang chờ duyệt
- Số stream hôm nay

### Task 9.3 — Sửa `lib/admin/admin_app.dart`

Thêm route mới:
```dart
'/mentor-management': (ctx) => const MentorManagementScreen(),
```

Thêm item vào Admin menu.

---

## 10. NOTIFICATION CHANNEL MỚI

### Task 10.1 — Sửa `lib/core/controllers/notification_controller.dart`

Thêm channel mới:
```dart
NotificationChannel(
  channelKey: 'mentor_live_channel',
  channelName: 'Mentor Live',
  channelDescription: 'Thông báo khi Mentor bạn follow bắt đầu live',
  defaultColor: const Color(0xFFFF6E40),
  ledColor: const Color(0xFFFF6E40),
  importance: NotificationImportance.High,
  playSound: true,
  enableVibration: true,
),
```

---

## 11. THỨ TỰ THỰC HIỆN (TASK ORDER)

Thực hiện **tuần tự** theo thứ tự sau để tránh dependency issues:

```
Phase 1 — Models & Schema (không có dependency)
  [x] Task 3.1: mentor_model.dart
  [x] Task 3.2: livestream_model.dart
  [x] Task 3.3: mentor_match_request_model.dart

Phase 2 — Service Layer
  [x] Task 4.1-4.5: Thêm methods vào firestore_service.dart

Phase 3 — Providers
  [x] Task 5.1: mentor_provider.dart
  [x] Task 5.2: livestream_provider.dart
  [x] Task 5.3: Đăng ký providers trong main.dart

Phase 4 — Routes
  [x] Task 5.4: Thêm routes vào user_app.dart
  [x] Task 9.3: Thêm routes vào admin_app.dart

Phase 5 — Screens mới
  [x] Task 6.5: mentor_apply_screen.dart  (đơn giản nhất, không cần Agora)
  [x] Task 6.2: mentor_profile_screen.dart
  [x] Task 6.1: live_discover_screen.dart
  [x] Task 6.4: go_live_screen.dart
  [x] Task 6.3: live_stream_screen.dart   (phức tạp nhất, cần Agora)
  [x] Task 6.6: mentor_requests_screen.dart

Phase 6 — Cập nhật screens hiện có
  [x] Task 7.1: main_screen.dart (thêm tab Discover + Go Live)
  [x] Task 7.2: profile.dart (thêm Mentor section)

Phase 7 — Admin
  [x] Task 9.1: mentor_management_screen.dart
  [x] Task 9.2: dashboard_screen.dart (thêm metrics)

Phase 8 — Cloud Functions & Notifications
  [x] Task 8.1: sendLiveNotification function
  [x] Task 8.2: export trong index.js
  [x] Task 8.3: handler trong main.dart
  [x] Task 10.1: notification channel mới

Phase 9 — Deploy & Test
  [x] flutter pub get
  [x] firebase deploy --only functions
  [x] Test trên Android + iOS
```

---

## 12. DESIGN TOKENS (BẮT BUỘC TUÂN THỦ)

```dart
// Colors
const Color kBackground = Color(0xFF101012);
const Color kAccent = Color(0xFFFF6E40);
const Color kAccentLight = Color(0xFFFF9E80);
const Color kGlassBg = Color(0x14FFFFFF);      // white 8%
const Color kGlassBorder = Color(0x1FFFFFFF);  // white 12%
const Color kLiveBadge = Color(0xFFFF3B30);    // đỏ Live

// Glass Container (dùng lại ở mọi screen)
Widget _buildGlassContainer({required Widget child, double radius = 24}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: child,
      ),
    ),
  );
}

// KHÔNG dùng .withOpacity() — dùng .withValues(alpha: x)
// KHÔNG hardcode màu khác ngoài list trên
```

---

## 13. CÁC LƯU Ý QUAN TRỌNG

1. **Agora channel cho livestream** = `streamId` (document ID của livestream), không phải `matchId`
2. **Mentor vẫn là user thường** — vẫn có thể swipe, chat với matches bình thường
3. **Follow ≠ Match** — follow chỉ nhận notification, phải gửi Match Request mới chat được
4. **Coin ảo** — Admin cấp coin bằng tay qua `FirestoreService.grantCoins()`, không cần payment gateway
5. **Gift transaction** phải là atomic — dùng Firestore batch write (trừ coin user + cộng coin mentor + ghi log cùng lúc)
6. **Viewer count** — cập nhật khi Agora callback `onUserJoined` / `onUserOffline`
7. **Stream thumbnail** — optional, có thể bỏ qua cho MVP
8. **Không dùng `.withOpacity()`** — đã deprecated, dùng `.withValues(alpha: x)`
9. **Mọi async phải có try/catch** theo chuẩn trong AGENT_DOCS section 13.6
10. **Sau khi xong, cập nhật AGENT_DOCS.md** section 14 (Changelog)

---

## 14. KIỂM TRA HOÀN THÀNH

Sau khi làm xong, verify:

- [ ] User có thể đăng ký Mentor, chờ Admin duyệt
- [ ] Admin duyệt/từ chối đơn Mentor
- [ ] User thấy tab Discover với danh sách Mentor và stream đang live
- [ ] User follow Mentor → nhận FCM notification khi Mentor bắt đầu live
- [ ] User vào xem stream → thấy video + chat realtime
- [ ] User tặng gift → trừ coin → animation xuất hiện trong stream
- [ ] User gửi Match Request → Mentor nhận notification → Mentor duyệt → tạo match → chat được
- [ ] Mentor bấm Go Live → điền form → phát stream → followers nhận notify
- [ ] Mentor kết thúc stream → status chuyển 'ended'
- [ ] Bottom nav có tab Discover, Mentor có nút Go Live
- [ ] Profile page có section đăng ký/quản lý Mentor
- [ ] Toàn bộ UI đúng Liquid Glass design (#101012 bg, #FF6E40 accent)
