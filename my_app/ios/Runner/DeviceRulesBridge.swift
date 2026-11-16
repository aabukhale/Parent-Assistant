import Flutter
import Foundation
import SwiftUI
import UIKit

#if canImport(FamilyControls)
import FamilyControls
#endif

/// `mamily/device_rules` on iOS — see
/// lib/features/device_rules/application/native_enforcement.dart.
/// Requires iOS 16 and the Family Controls entitlement; otherwise every
/// capability is reported as unsupported and nothing is applied.
enum DeviceRulesBridge {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mamily/device_rules", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.0, *) else {
        result(unsupportedAnswer(call.method))
        return
      }
      #if canImport(FamilyControls)
      handle(call, result)
      #else
      result(unsupportedAnswer(call.method))
      #endif
    }
  }

  private static func unsupportedAnswer(_ method: String) -> Any? {
    switch method {
    case "capabilities":
      return ["app_blocking", "app_limits", "schedules", "web_filter", "restrict_now", "usage_reporting", "device_lock"]
        .reduce(into: [String: String]()) { $0[$1] = "unsupported" }
    case "apply": return ["status": "unsupported", "results": []]
    case "verify", "enforcementActive", "openSetup": return false
    case "installedApps", "usageSince": return []
    default: return nil
    }
  }

  #if canImport(FamilyControls)
  @available(iOS 16.0, *)
  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      result(MamilyRules.capabilities())
    case "apply":
      guard let args = call.arguments, let data = try? JSONSerialization.data(withJSONObject: args) else {
        result(["status": "failed", "results": [], "error": "bad_policy"])
        return
      }
      let incoming = (args as? [String: Any])?["version"] as? Int ?? 0
      if let stored = MamilyRules.storedPolicy()?["version"] as? Int, stored > incoming {
        let (status, results) = MamilyRules.evaluate()
        result(["status": status, "results": results])
        return
      }
      MamilyRules.savePolicy(data)
      let (status, results) = MamilyRules.evaluate()
      var all = results
      if AuthorizationCenter.shared.authorizationStatus == .approved, let p = MamilyRules.storedPolicy() {
        all += MamilyRules.registerMonitoring(p)
      }
      result(["status": status, "results": all])
    case "verify":
      let v = (call.arguments as? [String: Any])?["version"] as? Int ?? 0
      result(MamilyRules.verify(version: v))
    case "enforcementActive":
      result(AuthorizationCenter.shared.authorizationStatus == .approved && MamilyRules.storedPolicy() != nil)
    case "clear":
      MamilyRules.clear()
      result(nil)
    case "installedApps", "usageSince":
      // iOS never exposes the app list or usage outside Apple's own views.
      result([])
    case "openSetup":
      // Family Controls: a parent approves on the child's iPhone with their
      // Apple ID (Family Sharing). Shows Apple's own consent sheet.
      Task {
        do {
          try await AuthorizationCenter.shared.requestAuthorization(for: .child)
          result(true)
        } catch {
          result(false)
        }
      }
    case "pickApps":
      presentPicker(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Apple's FamilyActivityPicker on this iPhone. Returns one opaque token
  /// per chosen app; apps can't read names, so they're numbered.
  @available(iOS 16.0, *)
  private static func presentPicker(_ result: @escaping FlutterResult) {
    guard AuthorizationCenter.shared.authorizationStatus == .approved,
          let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
      result(nil)
      return
    }
    var host: UIViewController?
    let view = PickerView { selection in
      host?.dismiss(animated: true)
      guard let selection else {
        result(nil)
        return
      }
      var out: [[String: String]] = []
      for (i, token) in selection.applicationTokens.enumerated() {
        if let id = MamilyRules.encode(token) {
          out.append(["id": id, "name": "iPhone app \(i + 1)"])
        }
      }
      result(out)
    }
    let vc = UIHostingController(rootView: view)
    host = vc
    root.present(vc, animated: true)
  }
  #endif
}

#if canImport(FamilyControls)
@available(iOS 16.0, *)
private struct PickerView: View {
  let done: (FamilyActivitySelection?) -> Void
  @State private var selection = FamilyActivitySelection()

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(NSLocalizedString("Cancel", comment: "")) { done(nil) }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(NSLocalizedString("Done", comment: "")) { done(selection) }
          }
        }
    }
  }
}
#endif
