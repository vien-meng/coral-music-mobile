import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var userApiRunner: UserApiRunner?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let runner = UserApiRunner()
    userApiRunner = runner
    FlutterMethodChannel(
      name: "coral_music/user_api",
      binaryMessenger: controller.binaryMessenger
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "load":
        let arguments = call.arguments as? [String: Any]
        runner.load(arguments?["script"] as? String ?? "", result: result)
      case "clear":
        runner.clear(result: result)
      case "resolveMusicUrl":
        runner.resolveMusicUrl(arguments: call.arguments as? [String: Any], result: result)
      case "resolveLyric":
        runner.resolveLyric(arguments: call.arguments as? [String: Any], result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    userApiRunner?.dispose()
    super.applicationWillTerminate(application)
  }
}
