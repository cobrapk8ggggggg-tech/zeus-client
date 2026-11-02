#
# openj9_embed.podspec — Zeus Manhwa embedded server runtime
#
# Bundles:
#   * OpenJ9 Java 21 runtime for iOS (interpreter mode) — XCFrameworks from
#     the prebuilt SDK zip (stardewjames/openj9-ios v21.0.13, "headless" variant
#     which includes Java2D/fonts/images needed by Suwayomi's AndroidCompat).
#     CI extracts the SDK zip to `OpenJ9/` (SwiftPM package layout preserved).
#   * OpenJ9Kit — the official Objective-C launcher (compiles inside this pod).
#   * ZeusJVMLauncher — Zeus-specific bootstrap that starts the bundled
#     Suwayomi-Server jar on 127.0.0.1:4567 before/alongside the Flutter engine.
#   * Resources/zeus-server.jar — Suwayomi-Server v2.4.2366 fat jar (CI-placed).
#
# The big binaries are NOT committed to git; CI downloads them from the
# `embedded-deps` release of this repository.
#
Pod::Spec.new do |s|
  s.name             = 'OpenJ9Embed'
  s.version          = '21.0.13.0'
  s.summary          = 'Embedded OpenJ9 JVM + Suwayomi-Server for Zeus Manhwa'
  s.description      = 'Embeds an interpreter-mode OpenJ9 Java 21 runtime and launches the bundled Suwayomi-Server on 127.0.0.1:4567 at app start — the same architecture as Tachimanga.'
  s.homepage         = 'https://github.com/cobrapk8ggggggg-tech/zeus-client'
  s.license          = { :type => 'MPL-2.0' }
  s.authors          = { 'Zeus Builder' => 'zeus@zeusmanhwa.app' }
  s.source           = { :path => '.' }

  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'

  # Zeus bootstrap (self-contained; VM loaded via dlopen at runtime)
  s.source_files     = 'Sources/*.{h,m}'
  s.public_header_files = 'Sources/ZeusJVMLauncher.h'

  # All runtime XCFrameworks (jvm, j9*, freetype, mlib_image, ...) — embedded
  # into the app bundle; loaded with dlopen, NOT linked (CocoaPods cannot link
  # vendored xcframeworks from pod targets reliably).
  s.vendored_frameworks = 'OpenJ9/Artifacts/XCFrameworks/*.xcframework'

  # Suwayomi-Server fat jar → lands at the app bundle root
  s.resources        = 'Resources/zeus-server.jar'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/OpenJ9/Sources/OpenJ9Kit/include"'
  }
end
