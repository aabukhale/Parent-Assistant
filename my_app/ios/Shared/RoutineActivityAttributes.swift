import ActivityKit
import Foundation

/// A routine that is under way, shown as a Live Activity on the child's
/// device. Only the routine title and step progress — no names, no points.
/// Compiled into both the app (which starts/updates it) and the widget
/// extension (which draws it).
@available(iOS 16.2, *)
struct RoutineActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var done: Int
    var total: Int
  }

  var routineId: String
  var title: String
}
