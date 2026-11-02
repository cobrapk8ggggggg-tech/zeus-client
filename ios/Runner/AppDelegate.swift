import UIKit
import Flutter
import OpenJ9Embed

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Boot the embedded OpenJ9 JVM + Suwayomi-Server (127.0.0.1:4567) — Tachimanga architecture.
    ZeusJVMStartServer()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
