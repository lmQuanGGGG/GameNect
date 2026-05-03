import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Đặt delegate để nhận notification khi app foreground
    UNUserNotificationCenter.current().delegate = self

    // Đăng ký APNs - bắt buộc để iOS nhận push khi app bị kill/background
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Plugin registration cho implicit engine (Flutter scene-based lifecycle)
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Callback khi APNs đăng ký thành công
  // awesome_notifications_fcm sử dụng native token này để nhận silent push
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Callback khi APNs đăng ký thất bại
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[APNs] Failed to register: \(error.localizedDescription)")
  }

  // Xử lý silent push (content-available: 1) khi app ở background hoặc bị kill
  // Super call sẽ forward tới awesome_notifications_fcm để kích hoạt mySilentDataHandle
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }
}