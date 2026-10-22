import Foundation

#if canImport(FamilyControls) && canImport(ManagedSettings) && canImport(DeviceActivity)
import DeviceActivity
import FamilyControls
import ManagedSettings

/// Applies a compiled Mamily policy with Apple's Screen Time APIs only
/// (Family Controls authorization, Managed Settings shields, Device Activity
/// schedules). Shared by the Runner app and the Device Activity monitor
/// extension, which re-evaluates at schedule boundaries while Mamily isn't
/// running. The policy lives in the app group so both can read it.
///
/// What iOS does *not* allow, reported honestly to the parent:
///  - usage data can't leave the device (only a DeviceActivityReport
///    extension can show it, on this iPhone) → usage_reporting unsupported
///  - app names can't be read; chosen apps are opaque tokens
///  - total daily allowance / per-category limits need category tokens from
///    Apple's picker → not offered yet (app_limits unsupported)
///  - schedule intervals must be ≥ 15 minutes (Device Activity rule)
@available(iOS 16.0, *)
enum MamilyRules {
    static let appGroup = "group.com.mamily.app"
    static let storeName = ManagedSettingsStore.Name("mamily")
    private static let policyKey = "mamily.rules.policy"
    private static let appliedKey = "mamily.rules.applied_version"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    // MARK: - storage

    static func savePolicy(_ json: Data) {
        defaults?.set(json, forKey: policyKey)
    }

    static func storedPolicy() -> [String: Any]? {
        guard let d = defaults?.data(forKey: policyKey) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }

    static var appliedVersion: Int {
        get { defaults?.integer(forKey: appliedKey) ?? -1 }
        set { defaults?.set(newValue, forKey: appliedKey) }
    }

    // MARK: - capabilities

    static func capabilities() -> [String: String] {
        let status = AuthorizationCenter.shared.authorizationStatus
        let core: String = switch status {
        case .approved: "available"
        case .denied: "permission_needed"
        case .notDetermined: "permission_needed"
        @unknown default: "unsupported"
        }
        return [
            "app_blocking": core,
            "schedules": core,
            "restrict_now": core,
            "web_filter": core,
            "app_limits": "unsupported",
            "usage_reporting": "unsupported",
            "device_lock": "unsupported",
        ]
    }

    // MARK: - tokens

    /// AppRef ids for iOS are base64 JSON of one `ApplicationToken`.
    static func tokens(_ list: Any?) -> Set<ApplicationToken> {
        guard let arr = list as? [[String: Any]] else { return [] }
        var out = Set<ApplicationToken>()
        for a in arr where (a["platform"] as? String) == "ios" {
            guard let id = a["id"] as? String, let data = Data(base64Encoded: id),
                  let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) else { continue }
            out.insert(token)
        }
        return out
    }

    static func encode(_ token: ApplicationToken) -> String? {
        (try? JSONEncoder().encode(token))?.base64EncodedString()
    }

    // MARK: - evaluation

    /// Recompute and apply shields for "now". Returns (status, results).
    @discardableResult
    static func evaluate(now: Date = Date()) -> (String, [[String: String]]) {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            return ("permission_needed", [["rule": "app_blocking", "state": "permission_needed"]])
        }
        guard let policy = storedPolicy() else { return ("applied", []) }
        var results: [[String: String]] = []
        let store = ManagedSettingsStore(named: storeName)

        let blocked = tokens(policy["blocked_apps"])
        let allowed = tokens(policy["allowed_apps"])
        let tz = TimeZone(identifier: policy["timezone"] as? String ?? "") ?? .current
        let restrictAll = restrictNowActive(policy, now: now) || allowOnlyScheduleActive(policy, now: now, tz: tz)

        store.shield.applications = blocked.isEmpty ? nil : blocked
        store.shield.applicationCategories = restrictAll ? .all(except: allowed) : nil

        if let web = policy["web"] as? [String: Any], let mode = web["mode"] as? String {
            switch mode {
            case "block_listed":
                let domains = Set(((web["blocked_domains"] as? [String]) ?? []).map { WebDomain(domain: $0) })
                store.webContent.blockedByFilter = .specific(domains)
            case "approved_only":
                let domains = Set(((web["allowed_domains"] as? [String]) ?? []).map { WebDomain(domain: $0) })
                store.webContent.blockedByFilter = .all(except: domains)
            default:
                store.webContent.blockedByFilter = nil
            }
        }

        if let limits = policy["app_limits"] as? [Any], !limits.isEmpty {
            results.append(["rule": "app_limits", "state": "unsupported"])
        }
        let allowance = policy["daily_allowance"] as? [String: Any]
        if allowance?.values.contains(where: { !($0 is NSNull) }) == true {
            results.append(["rule": "daily_allowance", "state": "unsupported"])
        }
        let hasAndroidOnly = (policy["blocked_apps"] as? [Any])?.isEmpty == false && blocked.isEmpty
        if hasAndroidOnly { results.append(["rule": "blocked_apps", "state": "not_on_this_phone"]) }

        appliedVersion = policy["version"] as? Int ?? 0
        return (results.isEmpty ? "applied" : "partial", results)
    }

    static func verify(version: Int) -> Bool {
        guard AuthorizationCenter.shared.authorizationStatus == .approved, appliedVersion >= version,
              let policy = storedPolicy() else { return false }
        let store = ManagedSettingsStore(named: storeName)
        let blocked = tokens(policy["blocked_apps"])
        return blocked.isEmpty || store.shield.applications == blocked
    }

    static func clear() {
        ManagedSettingsStore(named: storeName).clearAllSettings()
        DeviceActivityCenter().stopMonitoring()
        defaults?.removeObject(forKey: policyKey)
        defaults?.removeObject(forKey: appliedKey)
    }

    // MARK: - schedules

    private static func restrictNowActive(_ p: [String: Any], now: Date) -> Bool {
        guard let r = p["restrict_now"] as? [String: Any] else { return false }
        guard let until = r["until"] as? String, let end = ISO8601DateFormatter().date(from: until) else { return true }
        return end > now
    }

    private static func allowOnlyScheduleActive(_ p: [String: Any], now: Date, tz: TimeZone) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        for s in (p["schedules"] as? [[String: Any]]) ?? [] {
            guard (s["enabled"] as? Bool) ?? true, (s["restriction"] as? String) == "allow_only",
                  let days = s["days"] as? [Int], let start = s["start"] as? String, let end = s["end"] as? String else { continue }
            for back in 0...1 {
                guard let day = cal.date(byAdding: .day, value: -back, to: cal.startOfDay(for: now)) else { continue }
                // ISO weekday 1 = Monday; Calendar weekday 1 = Sunday.
                let iso = (cal.component(.weekday, from: day) + 5) % 7 + 1
                guard days.contains(iso), let from = at(day, start, cal), var to = at(day, end, cal) else { continue }
                if to <= from, let next = cal.date(byAdding: .day, value: 1, to: day), let t = at(next, end, cal) { to = t }
                if now >= from && now < to { return true }
            }
        }
        return false
    }

    private static func at(_ day: Date, _ hhmm: String, _ cal: Calendar) -> Date? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }

    /// Ask Device Activity to wake the monitor extension at every schedule
    /// boundary (and when a timed pause ends) so shields change on time
    /// without Mamily running. Max 20 activities; schedules repeat weekly.
    static func registerMonitoring(_ p: [String: Any]) -> [[String: String]] {
        let center = DeviceActivityCenter()
        center.stopMonitoring()
        var results: [[String: String]] = []
        var count = 0
        for s in (p["schedules"] as? [[String: Any]]) ?? [] where (s["enabled"] as? Bool) ?? true {
            guard let id = s["id"] as? String, let days = s["days"] as? [Int],
                  let start = s["start"] as? String, let end = s["end"] as? String else { continue }
            let sp = start.split(separator: ":").compactMap { Int($0) }
            let ep = end.split(separator: ":").compactMap { Int($0) }
            guard sp.count == 2, ep.count == 2 else { continue }
            for d in days where count < 20 {
                let weekday = d % 7 + 1 // ISO → Calendar weekday
                let schedule = DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: sp[0], minute: sp[1], weekday: weekday),
                    intervalEnd: DateComponents(hour: ep[0], minute: ep[1], weekday: (ep[0] * 60 + ep[1]) <= (sp[0] * 60 + sp[1]) ? weekday % 7 + 1 : weekday),
                    repeats: true,
                )
                do {
                    try center.startMonitoring(DeviceActivityName("mamily.\(id).\(d)"), during: schedule)
                    count += 1
                } catch {
                    results.append(["rule": "schedule:\(id)", "state": "failed"])
                }
            }
        }
        if let r = p["restrict_now"] as? [String: Any], let until = r["until"] as? String,
           let end = ISO8601DateFormatter().date(from: until), end > Date(), count < 20 {
            var cal = Calendar.current
            cal.timeZone = .current
            let startDate = Date()
            // Device Activity needs ≥ 15 min; a shorter pause still ends on
            // the next app open or schedule boundary.
            let endDate = max(end, startDate.addingTimeInterval(15 * 60))
            let schedule = DeviceActivitySchedule(
                intervalStart: cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate),
                intervalEnd: cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endDate),
                repeats: false,
            )
            do {
                try center.startMonitoring(DeviceActivityName("mamily.restrict_now"), during: schedule)
            } catch {
                results.append(["rule": "restrict_now_expiry", "state": "approximate"])
            }
        }
        return results
    }
}
#endif
