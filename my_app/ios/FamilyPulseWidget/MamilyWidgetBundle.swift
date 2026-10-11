import SwiftUI
import WidgetKit

@main
struct MamilyWidgetBundle: WidgetBundle {
  var body: some Widget {
    FamilyPulseWidget()
    if #available(iOS 16.2, *) {
      RoutineLiveActivityWidget()
    }
  }
}
