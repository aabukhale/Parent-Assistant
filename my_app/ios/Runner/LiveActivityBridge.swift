import ActivityKit
import Flutter
import Foundation

/// `mamily/live_activity` — see `RoutineLiveActivity` in
/// lib/features/surfaces/live_activity.dart. Every call is a quiet no-op on
/// iOS < 16.2 or when the user turned Live Activities off.
enum LiveActivityBridge {
  /// iOS keeps an ended activity on the Lock Screen this long.
  private static let finishedLinger: TimeInterval = 15 * 60
  /// A routine is short; the activity goes stale instead of lingering.
  private static let staleAfter: TimeInterval = 3 * 60 * 60

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mamily/live_activity", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.2, *) else {
        result(nil)
        return
      }
      let args = call.arguments as? [String: Any] ?? [:]
      Task {
        switch call.method {
        case "startOrUpdate": await startOrUpdate(args)
        case "end": await end(args)
        case "endAll": await endAll()
        default:
          result(FlutterMethodNotImplemented)
          return
        }
        result(nil)
      }
    }
  }

  @available(iOS 16.2, *)
  private static func activity(for routineId: String) -> Activity<RoutineActivityAttributes>? {
    Activity<RoutineActivityAttributes>.activities.first { $0.attributes.routineId == routineId }
  }

  @available(iOS 16.2, *)
  private static func state(_ args: [String: Any]) -> RoutineActivityAttributes.ContentState {
    RoutineActivityAttributes.ContentState(
      done: args["done"] as? Int ?? 0,
      total: max(args["total"] as? Int ?? 0, 1)
    )
  }

  @available(iOS 16.2, *)
  private static func startOrUpdate(_ args: [String: Any]) async {
    guard let routineId = args["routineId"] as? String else { return }
    let content = ActivityContent(
      state: state(args),
      staleDate: Date().addingTimeInterval(staleAfter)
    )
    if let existing = activity(for: routineId) {
      await existing.update(content)
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let attributes = RoutineActivityAttributes(
      routineId: routineId,
      title: args["title"] as? String ?? ""
    )
    _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
  }

  @available(iOS 16.2, *)
  private static func end(_ args: [String: Any]) async {
    guard let routineId = args["routineId"] as? String,
          let existing = activity(for: routineId) else { return }
    await existing.end(
      ActivityContent(state: state(args), staleDate: nil),
      dismissalPolicy: .after(Date().addingTimeInterval(finishedLinger))
    )
  }

  @available(iOS 16.2, *)
  private static func endAll() async {
    for activity in Activity<RoutineActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
