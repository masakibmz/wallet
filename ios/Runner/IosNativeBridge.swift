import Flutter
import LocalAuthentication
import UIKit

final class IosNativeBridgePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.wallet/ios_native",
      binaryMessenger: registrar.messenger()
    )
    let instance = IosNativeBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let factory = LiquidGlassViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "com.wallet/liquid_glass")
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hapticLight":
      let generator = UIImpactFeedbackGenerator(style: .light)
      generator.prepare()
      generator.impactOccurred()
      result(nil)
    case "hapticSelection":
      let generator = UISelectionFeedbackGenerator()
      generator.prepare()
      generator.selectionChanged()
      result(nil)
    case "authenticateWithBiometrics":
      let args = call.arguments as? [String: Any]
      let reason = args?["reason"] as? String ?? "验证身份以继续"
      authenticate(reason: reason, result: result)
    case "isLiquidGlassSupported":
      result(LiquidGlassViewFactory.isLiquidGlassSupported)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authenticate(reason: String, result: @escaping FlutterResult) {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      result(false)
      return
    }
    context.evaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics,
      localizedReason: reason
    ) { success, _ in
      DispatchQueue.main.async {
        result(success)
      }
    }
  }
}

final class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  static var isLiquidGlassSupported: Bool {
    if #available(iOS 26.0, *) {
      return true
    }
    return true
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let params = args as? [String: Any]
    let styleName = params?["style"] as? String ?? "regular"
    return LiquidGlassPlatformView(frame: frame, styleName: styleName)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect, styleName: String) {
    container = UIView(frame: frame)
    super.init()
    container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.backgroundColor = .clear
    attachGlassEffect(to: container, styleName: styleName)
  }

  func view() -> UIView {
    container
  }

  private func attachGlassEffect(to view: UIView, styleName: String) {
    if #available(iOS 26.0, *) {
      let effectView = UIVisualEffectView()
      effectView.frame = view.bounds
      effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      effectView.effect = UIBlurEffect(style: blurStyle(for: styleName))
      view.addSubview(effectView)
      return
    }

    let effectView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle(for: styleName)))
    effectView.frame = view.bounds
    effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(effectView)
  }

  private func blurStyle(for styleName: String) -> UIBlurEffect.Style {
    switch styleName {
    case "thick":
      return .systemChromeMaterial
    case "thin":
      return .systemThinMaterial
    default:
      return .systemMaterial
    }
  }
}
