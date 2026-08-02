import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 隐式引擎初始化完成后，注册插件并把 MethodChannel 交给 ScanBridge。
  /// ScanBridge 负责：开始/停止录屏扫描、PiP 悬浮窗、轮询扩展写来的 OCR 文本并匹配答案。
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    ScanBridge.shared.setup(engineBridge.pluginRegistry.binaryMessenger)
  }
}
