import Flutter
import UIKit
import firebase_messaging

enum StartupTiming {
  private static let baseline = ProcessInfo.processInfo.systemUptime

  static func log(_ milestone: String) {
#if DEBUG || PADELX_STARTUP_TIMING
    let elapsed = Int((ProcessInfo.processInfo.systemUptime - baseline) * 1000)
    print("[StartupTiming +\(elapsed)ms native] \(milestone)")
#endif
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    StartupTiming.log("application didFinishLaunching entered")
    // UIScene registers plugins after launch returns, so Messaging must claim
    // the notification-center delegate before that point.
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    StartupTiming.log("implicit Flutter engine initialized")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
