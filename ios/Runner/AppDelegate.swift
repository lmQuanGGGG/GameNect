import Flutter
import UIKit
import UserNotifications
import AVFoundation
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVPictureInPictureControllerDelegate {
  
  var pipController: AVPictureInPictureController?
  var flutterViewController: FlutterViewController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Đặt delegate để nhận notification khi app foreground
    UNUserNotificationCenter.current().delegate = self

    // Đăng ký APNs - bắt buộc để iOS nhận push khi app bị kill/background
    application.registerForRemoteNotifications()

    // Config AVAudioSession for Background Audio / Video Call
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
        try audioSession.setActive(true)
    } catch {
        print("Failed to set audio session category. Error: \(error)")
    }

    // Setup MethodChannel for PiP
    self.flutterViewController = window?.rootViewController as? FlutterViewController
    if let flutterViewController = self.flutterViewController {
        let pipChannel = FlutterMethodChannel(name: "com.qco.gamenect/pip",
                                              binaryMessenger: flutterViewController.binaryMessenger)
        pipChannel.setMethodCallHandler({ [weak self]
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            
            if call.method == "setIsLiveActive" {
                if let args = call.arguments as? [String: Any],
                   let isActive = args["isActive"] as? Bool {
                    self?.handleSetIsLiveActive(isActive: isActive)
                }
                result(true)
            } else if call.method == "enterPiP" {
                let success = self?.handleEnterPiP() ?? false
                result(success)
            } else {
                result(FlutterMethodNotImplemented)
            }
        })
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle Live Active state
  private func handleSetIsLiveActive(isActive: Bool) {
      if isActive {
          setupPiP()
      } else {
          // Stop PiP if active and clear
          pipController?.stopPictureInPicture()
          pipController = nil
      }
  }

  // Setup PiP Controller
  private func setupPiP() {
      if #available(iOS 15.0, *) {
          if AVPictureInPictureController.isPictureInPictureSupported() {
              if self.pipController == nil, let flutterViewController = self.flutterViewController {
                  let pipContentSource = AVPictureInPictureVideoCallViewController()
                  pipContentSource.preferredContentSize = CGSize(width: 1080, height: 1920)
                  
                  // Add a placeholder UI to the PiP window so we can see it
                  pipContentSource.view.backgroundColor = .black
                  let label = UILabel()
                  label.text = "Gamenect Live"
                  label.textColor = .white
                  label.font = UIFont.boldSystemFont(ofSize: 24)
                  label.translatesAutoresizingMaskIntoConstraints = false
                  pipContentSource.view.addSubview(label)
                  NSLayoutConstraint.activate([
                      label.centerXAnchor.constraint(equalTo: pipContentSource.view.centerXAnchor),
                      label.centerYAnchor.constraint(equalTo: pipContentSource.view.centerYAnchor)
                  ])
                  
                  let controller = AVPictureInPictureController(contentSource: AVPictureInPictureController.ContentSource(
                      activeVideoCallSourceView: flutterViewController.view,
                      contentViewController: pipContentSource))
                  
                  controller.delegate = self
                  controller.canStartPictureInPictureAutomaticallyFromInline = true
                  self.pipController = controller
              }
          }
      }
  }

  // Manual trigger (if needed)
  private func handleEnterPiP() -> Bool {
      if self.pipController != nil {
          self.pipController?.startPictureInPicture()
          return true
      }
      return false
  }

  // PiP Delegate Methods to notify Flutter
  func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
      notifyFlutterPiPModeChanged(isInPiP: true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
      notifyFlutterPiPModeChanged(isInPiP: false)
  }

  private func notifyFlutterPiPModeChanged(isInPiP: Bool) {
      if let flutterViewController = self.flutterViewController {
          let pipChannel = FlutterMethodChannel(name: "com.qco.gamenect/pip",
                                                binaryMessenger: flutterViewController.binaryMessenger)
          pipChannel.invokeMethod("onPiPModeChanged", arguments: isInPiP)
      }
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