# Hướng dẫn cấu hình iOS Broadcast Upload Extension cho Screen Sharing (Agora)

Do hệ điều hành iOS quản lý bảo mật rất chặt chẽ, việc quay màn hình hệ thống (Screen Sharing) ngoài phạm vi ứng dụng bắt buộc phải chạy qua một tiến trình con riêng biệt gọi là **Broadcast Upload Extension**. Dưới đây là các bước để bạn tự cấu hình trong Xcode.

---

## Bước 1: Tạo Target Broadcast Upload Extension trong Xcode

1. Mở dự án iOS của bạn bằng Xcode: 
   - Nhấp đúp vào file `ios/Runner.xcworkspace`.
2. Trên thanh menu trên cùng của Xcode, chọn **File > New > Target...**
3. Trong ô tìm kiếm, nhập **"Broadcast Upload Extension"**, chọn nó và nhấn **Next**.
4. Điền các thông tin cấu hình như sau:
   - **Product Name**: `GamenectScreenShare`
   - **Language**: `Swift`
   - **Include UI Extension**: **BỎ TÍCH** (Không chọn tùy chọn này).
5. Nhấn **Finish**. 
   - Xcode sẽ hỏi bạn có muốn kích hoạt (Activate) target mới này không, chọn **Activate**.

---

## Bước 2: Cấu hình App Groups (Quan trọng)

Để ứng dụng chính (`Runner`) và extension con (`GamenectScreenShare`) có thể giao tiếp, trao đổi dữ liệu với nhau, cả hai phải chung một **App Group**.

1. Chọn biểu tượng dự án **Runner** (ở cột thư mục bên trái ngoài cùng).
2. Chọn target **Runner** -> Vào thẻ **Signing & Capabilities**.
3. Nhấp chọn nút **+ Capability** (nút cộng ở góc trên bên trái). Tìm kiếm **App Groups** và nhấn đúp để thêm.
4. Ở mục App Groups mới xuất hiện, nhấp biểu tượng **+** và thêm tên nhóm:
   - `group.com.qco.gamenect`
5. Tiếp tục chọn target **GamenectScreenShare** -> Vào thẻ **Signing & Capabilities**.
6. Làm tương tự: Nhấp **+ Capability** -> Thêm **App Groups**.
7. Tích chọn nhóm `group.com.qco.gamenect` (đảm bảo tích hoạt màu xanh ở cả 2 targets).

---

## Bước 3: Cấu hình Bundle ID và iOS Version

1. Chọn target **GamenectScreenShare**.
2. Thẻ **General**:
   - Xác nhận **Bundle Identifier** là: `com.qco.gamenect.GamenectScreenShare`.
   - Tại mục **Minimum Deployments**, đặt phiên bản iOS tối thiểu là **iOS 12.0** trở lên (trùng với ứng dụng chính Runner).

---

## Bước 4: Viết mã nguồn cho `SampleHandler.swift`

Khi bạn tạo Extension, Xcode tự động sinh ra thư mục `GamenectScreenShare` ở cột bên trái chứa file `SampleHandler.swift`. Hãy mở file này ra và thay thế toàn bộ nội dung bằng đoạn code bên dưới:

```swift
import ReplayKit
import AgoraReplayKitExtension

class SampleHandler: RPBroadcastSampleHandler, AgoraReplayKitExtDelegate {

    // Khởi tạo handler với App Group ID
    private let agoraReplayKitExt = AgoraReplayKitExt.shareInstance()

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // Gắn delegate và bắt đầu broadcast
        agoraReplayKitExt.initDelegate(self)
    }

    override func broadcastPaused() {
        agoraReplayKitExt.pause()
    }

    override func broadcastResumed() {
        agoraReplayKitExt.resume()
    }

    override func broadcastFinished() {
        agoraReplayKitExt.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        // Chuyển tiếp luồng buffer (video, audio) sang Agora SDK
        agoraReplayKitExt.push(sampleBuffer, with: sampleBufferType)
    }

    // MARK: - AgoraReplayKitExtDelegate
    func agoraReplayKitExtDidStop() {
        let error = NSError(
            domain: "com.qco.gamenect.GamenectScreenShare",
            code: 0,
            userInfo: [NSLocalizedFailureReasonErrorKey: "Agora ReplayKit Extension stopped"]
        )
        finishBroadcastWithError(error)
    }
}
```

---

## Bước 5: Cấu hình Podfile để liên kết Thư viện Agora

Bạn cần hướng dẫn CocoaPods liên kết thư viện ReplayKit của Agora vào target con này.

1. Mở file [Podfile](file:///Users/wang04/Downloads/GAMENECT/gamenect_new/ios/Podfile) trong dự án của bạn.
2. Thêm đoạn cấu hình sau vào **cuối** file Podfile:

```ruby
target 'GamenectScreenShare' do
  use_frameworks!
  pod 'AgoraRtcEngine_iOS/AgoraReplayKitExtension', '6.5.3'
end
```

3. Mở Terminal tại thư mục `ios/` của dự án và chạy lệnh để cài đặt pod mới:
   ```bash
   cd ios
   pod install --repo-update
   cd ..
   ```

---

## Bước 6: Khởi chạy và Trải nghiệm

1. Kết nối iPhone thật của bạn vào máy Mac.
2. Chạy ứng dụng bằng lệnh:
   ```bash
   flutter run -d <ID_THIET_BI_THAT>
   ```
3. Khi vào chế độ Livestream (với quyền Mentor/Broadcaster):
   - Nhấn nút **Chia sẻ MH** trên màn hình.
   - Hệ thống sẽ hiện thông báo nhắc bạn.
   - Bạn chỉ cần vuốt **Control Center** của iOS xuống -> Nhấn giữ nút **Ghi màn hình (Screen Recording)**.
   - Chọn **GamenectScreenShare** từ danh sách -> Nhấp **Bắt đầu phát (Start Broadcast)**.
   - Giao diện app sẽ hiển thị màn hình hoạt động chia sẻ và truyền tải trực tiếp luồng hình ảnh thiết bị của bạn tới người xem!
