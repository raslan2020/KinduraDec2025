import UIKit
import Flutter
import WatchConnectivity
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {
  private var watchVitalsChannel: FlutterMethodChannel?
  private var latestWatchVitals: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configure audio session for LiveKit voice calls
    configureAudioSession()

    // Setup WatchConnectivity
    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
      print("WatchConnectivity activated on iPhone")
    }

    // Setup Flutter method channel for Watch vitals
    let controller = window?.rootViewController as! FlutterViewController
    watchVitalsChannel = FlutterMethodChannel(
      name: "com.kindura.ai/watch_vitals",
      binaryMessenger: controller.binaryMessenger
    )

    watchVitalsChannel?.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getLatestVitals" {
        if let vitals = self?.latestWatchVitals {
          result(vitals)
        } else {
          result(nil)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if let error = error {
      print("WCSession activation failed: \(error.localizedDescription)")
    } else {
      print("WCSession activated with state: \(activationState.rawValue)")
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {
    print("WCSession became inactive")
  }

  func sessionDidDeactivate(_ session: WCSession) {
    print("WCSession deactivated")
    // Reactivate session for multiple Watch support
    WCSession.default.activate()
  }

  // Receive messages from Watch
  func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
    print("Received message from Watch: \(message)")

    if message["type"] as? String == "watch_vitals" {
      latestWatchVitals = message

      // Notify Flutter about new vitals
      DispatchQueue.main.async {
        self.watchVitalsChannel?.invokeMethod("onWatchVitalsReceived", arguments: message)
      }

      replyHandler(["status": "received"])
    } else {
      replyHandler(["status": "unknown_type"])
    }
  }

  // Receive application context updates from Watch
  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
    print("Received application context from Watch: \(applicationContext)")

    if applicationContext["type"] as? String == "watch_vitals" {
      latestWatchVitals = applicationContext

      // Notify Flutter about new vitals
      DispatchQueue.main.async {
        self.watchVitalsChannel?.invokeMethod("onWatchVitalsReceived", arguments: applicationContext)
      }
    }
  }

  // MARK: - Audio Session Configuration for LiveKit

  private func configureAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()

      // Use playAndRecord category for voice calls with speaker output
      try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
      )

      // Activate the audio session
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

      // Force output to speaker
      try audioSession.overrideOutputAudioPort(.speaker)

      print("✅ Audio session configured for LiveKit voice calls")
      print("   - Category: playAndRecord")
      print("   - Mode: voiceChat")
      print("   - Output: Speaker")
    } catch {
      print("❌ Failed to configure audio session: \(error.localizedDescription)")
    }
  }
}
