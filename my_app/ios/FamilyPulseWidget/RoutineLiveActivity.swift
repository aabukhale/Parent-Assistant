import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen / Dynamic Island view of a routine under way on the child's
/// device: title and "3 of 5 steps" only.
@available(iOS 16.2, *)
struct RoutineLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RoutineActivityAttributes.self) { context in
      RoutineLockScreenView(title: context.attributes.title, state: context.state, onDark: false)
        .padding()
        .activityBackgroundTint(Color(red: 0xFF / 255, green: 0xF6 / 255, blue: 0xE5 / 255))
        .widgetURL(URL(string: "mamily://open/child/routines/\(context.attributes.routineId)"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          RoutineLockScreenView(title: context.attributes.title, state: context.state, onDark: true)
        }
      } compactLeading: {
        Text("🧩")
      } compactTrailing: {
        StepsRing(state: context.state)
      } minimal: {
        StepsRing(state: context.state)
      }
      .widgetURL(URL(string: "mamily://open/child/routines/\(context.attributes.routineId)"))
    }
  }

}

/// Fits the narrow compact/minimal slots, where "1/4" got clipped.
@available(iOS 16.2, *)
private struct StepsRing: View {
  let state: RoutineActivityAttributes.ContentState

  var body: some View {
    ProgressView(value: Double(state.done), total: Double(max(state.total, 1)))
      .progressViewStyle(.circular)
      .tint(Color(red: 0x2D / 255, green: 0xD4 / 255, blue: 0xBF / 255))
      .accessibilityLabel(Text(String(localized: "routine.steps \(state.done) \(state.total)")))
  }
}

@available(iOS 16.2, *)
private struct RoutineLockScreenView: View {
  let title: String
  let state: RoutineActivityAttributes.ContentState
  /// The Dynamic Island is always black; the Lock Screen card is light.
  let onDark: Bool

  var body: some View {
    let finished = state.done >= state.total
    let ink = onDark ? Color.white : Color(red: 0x2E / 255, green: 0x3B / 255, blue: 0x63 / 255)
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(finished ? "🎉" : "🧩")
        Text(title).font(.headline).lineLimit(1).foregroundColor(ink)
        Spacer()
        Text(String(localized: "routine.steps \(state.done) \(state.total)"))
          .font(.subheadline)
          .monospacedDigit()
          .foregroundColor(ink.opacity(0.85))
      }
      ProgressView(value: Double(state.done), total: Double(max(state.total, 1)))
        .tint(Color(red: 0x0F / 255, green: 0x76 / 255, blue: 0x6E / 255))
      if finished {
        Text("routine.done").font(.caption).foregroundColor(ink)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
