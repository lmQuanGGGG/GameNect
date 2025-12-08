# Gamenect

Gamenect là ứng dụng chia sẻ “Moments” theo phong cách Stories, hỗ trợ chụp ảnh/quay video, đăng tải khoảnh khắc, tương tác bằng cảm xúc và tin nhắn. Ứng dụng được xây dựng bằng Flutter, tích hợp Firebase cho xác thực và lưu trữ.

## Tính năng chính

- Chụp ảnh/quay video Moments (giữ để quay, nhấn để chụp)
- Camera trước/sau, flash, focus, zoom, chỉnh exposure
- Preview trước khi đăng, lật ảnh đúng chiều với camera trước
- Đăng Moments lên Firebase Storage/Firestore
- Thêm chú thích, gửi cảm xúc, phản hồi bằng tin nhắn
- Chọn media từ thư viện
- Hạn mức đăng (nâng cấp Premium khi vượt)

## Yêu cầu hệ thống

- Flutter 3.8+ (Dart SDK 3.8+)
- Android SDK, Xcode (nếu build iOS)
- Tài khoản Firebase và Google Play (nếu phát hành Android)
- Mac (khuyến nghị) cho môi trường phát triển

## Cấu trúc thư mục

- lib/: mã nguồn Flutter
- android/: cấu hình và build Android
- ios/: cấu hình iOS
- assets/: hình ảnh, fonts, icons
- pubspec.yaml: cấu hình dependencies

## Cài đặt và chạy

1. Cài dependencies:
```bash
flutter pub get
```

2. Chạy app (debug):
```bash
flutter run
```

3. Khóa màn hình dọc cho màn hình Moments (khuyến nghị):
- Đã xử lý trong `CameraCaptureScreen` và có thể khóa ở `MomentScreen` nếu cần.

## Cấu hình Firebase

1. Tạo project Firebase, thêm app Android với Application ID (VD: `com.qco.gamenect`)
2. Tải `google-services.json`, đặt vào:
```
android/app/google-services.json
```
3. Thêm SHA-1/SHA-256 (nếu dùng Google Sign-In):
```bash
keytool -list -v -keystore ~/upload-keystore.jks -alias upload
```
4. Bật các dịch vụ cần thiết: Authentication, Firestore, Storage.

## Build Android Release

1. Tạo keystore:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Tạo file `android/key.properties`:
```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/Users/wang04/upload-keystore.jks
```

3. Cập nhật `android/app/build.gradle.kts`:
- `applicationId` và `namespace` khớp với Firebase
- `signingConfig` dùng keystore release
- Bật R8 + ProGuard, liên kết `proguard-rules.pro`

4. Build AAB:
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

File đầu ra:
```
build/app/outputs/bundle/release/app-release.aab
```

## Đăng lên Google Play

- Tạo tài khoản Play Console
- Tạo ứng dụng mới (Production → Create new release)
- Upload file `.aab`
- Hoàn thiện Store Listing (icon 512x512, screenshots, feature graphic 1024x500)
- Thêm Privacy Policy (bắt buộc nếu dùng camera, Firebase)

## Ghi chú kỹ thuật

- Camera trước: lật UI preview và/hoặc lật file khi upload để đúng chiều
- Sử dụng `ResolutionPreset.veryHigh` và `ImageFormatGroup.jpeg` cho ảnh đẹp
- ProGuard/R8: thêm keep rules cho TensorFlow Lite, Firebase, plugins camera/video
- Tránh tràn giao diện khi xoay ngang: khóa dọc hoặc làm responsive

## Phát triển

- Unit tests: thêm vào `test/`
- CI/CD: có thể dùng GitHub Actions để build tự động
- Theo dõi lỗi: Firebase Crashlytics (khuyến nghị)

## License

Dự án nội bộ. Không phát hành công khai nếu không có sự cho phép.
