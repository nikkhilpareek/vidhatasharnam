import UIKit
import Flutter
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  var flutterEngine: FlutterEngine?
  private let launchStartTime = Date()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("⏱️ [TIMING] AppDelegate.application start: \(Date())")
    
    // Step 1: Pre-warm Flutter engine IMMEDIATELY (non-blocking)
    let engineStartTime = Date()
    flutterEngine = FlutterEngine(name: "my_engine")
    flutterEngine?.run()
    GeneratedPluginRegistrant.register(with: flutterEngine!)
    let engineDuration = Date().timeIntervalSince(engineStartTime)
    print("⏱️ [TIMING] Flutter engine initialization: \(String(format: "%.3f", engineDuration))s")

    // Step 2: Create window and show UI IMMEDIATELY (before Firebase)
    let windowStartTime = Date()
    self.window = UIWindow(frame: UIScreen.main.bounds)
    let flutterViewController = FlutterViewController(engine: flutterEngine!, nibName: nil, bundle: nil)
    self.window?.rootViewController = flutterViewController
    self.window?.makeKeyAndVisible()
    let windowDuration = Date().timeIntervalSince(windowStartTime)
    print("⏱️ [TIMING] Window setup: \(String(format: "%.3f", windowDuration))s")
    print("🚀 Flutter UI visible IMMEDIATELY - Firebase will initialize async ✅")

    // Step 3: Initialize Firebase ASYNCHRONOUSLY on background thread (non-blocking)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let firebaseStartTime = Date()
      
      // Only configure if not already configured
      if FirebaseApp.app() == nil {
        FirebaseApp.configure()
        let firebaseDuration = Date().timeIntervalSince(firebaseStartTime)
        print("✅ Firebase configured successfully (AppDelegate) - Async: \(String(format: "%.3f", firebaseDuration))s")
      } else {
        print("✅ Firebase already configured")
      }
    }

    let totalDuration = Date().timeIntervalSince(launchStartTime)
    print("⏱️ [TIMING] Total AppDelegate.application duration (UI shown): \(String(format: "%.3f", totalDuration))s")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
