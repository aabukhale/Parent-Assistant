import DeviceActivity
import Foundation

/// Woken by iOS at Mamily schedule boundaries (school, homework, bedtime,
/// end of a timed pause) — even when Mamily isn't running — and re-applies
/// the shields for "now" from the policy cached in the app group.
class ActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        MamilyRules.evaluate()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        MamilyRules.evaluate()
    }
}
