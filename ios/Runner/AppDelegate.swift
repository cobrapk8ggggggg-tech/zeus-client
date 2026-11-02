import UIKit
import Flutter
#if canImport(OpenJ9Embed)
import OpenJ9Embed
#endif

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Boot the embedded OpenJ9 JVM + Suwayomi-Server (127.0.0.1:4567) — Tachimanga architecture.
    // ZEUS_LITE builds (ZEUS_LITE=1 at pod install) compile this out; the app then acts as a
    // small client connecting to a remote Suwayomi server configured in Settings → Server URL.
    #if canImport(OpenJ9Embed)
    ZeusJVMStartServer()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
