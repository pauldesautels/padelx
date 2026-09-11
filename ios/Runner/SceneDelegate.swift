import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    StartupTiming.log("scene willConnect entered")
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      StartupTiming.log("Flutter view controller unavailable")
      return
    }
    let installed = flutterViewController.loadDefaultSplashScreenView()
    StartupTiming.log(installed ? "native splash retained" : "native splash unavailable")
  }
}
