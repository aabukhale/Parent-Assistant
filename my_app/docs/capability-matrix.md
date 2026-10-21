# Mamily — native capability matrix (Android / iOS)

Written 2026-10-21 from the official platform documentation (Android
Developers: DevicePolicyManager, UsageStatsManager, MediaProjection, Location;
Apple: FamilyControls, ManagedSettings, DeviceActivity, ReplayKit, Core
Location; Google Play policy centre for AccessibilityService) plus the existing
Mamily native code. The "Verified" column is updated as things are actually
run; "docs" means only the documentation was checked.

**Ground rules (product decisions):**

- No hidden APIs, root/jailbreak, deceptive overlays, or AccessibilityService
  used as a restriction workaround. The existing Android floating card is an
  opt-in *parent* surface, never a blocking layer.
- The backend never says "active" for a rule. A rule is reported in four
  separate layers: *stored on server* → *received by device* → *applied by the
  native mechanism* → *observed state* (see `mamily/docs/device-rules.md`).
- Three capabilities are always named separately in the UI:
  **App blocking (system)**, **Whole-device lock (system)**, and
  **Mamily-only lock (inside this app)**. The in-app lock is never shown as
  a device lock.

## Device rules

| Capability | Android — ordinary install (Play) | Android — Mamily set as device owner | iOS — Family Controls |
|---|---|---|---|
| Min OS | 7.0 (API 24) for usage; Mamily minSdk applies | API 24 (`setPackagesSuspended`), API 28+ recommended | iOS 16 (`.child` / `.individual` authorization); Mamily deployment target 15 → feature gated to 16+ |
| Setup | "Usage access" special permission (Settings) | Fresh/factory-reset device provisioned with Mamily as device-owner DPC (QR at setup wizard, or `adb shell dpm set-device-owner` for test devices). Cannot be done on a phone that already has accounts without a reset. | Child device: Family Sharing child account; parent approves `AuthorizationCenter.requestAuthorization(for: .child)` on the child's phone (Apple ID parent auth). Or `.individual` for the child's own Apple ID (self-managed, can be revoked by the child — shown as weaker). |
| Entitlement / store | None for usage stats; Play "parental control" declaration + usage-access disclosure | Not distributable via ordinary Play install flow as DPC without managed provisioning; test via adb | `com.apple.developer.family-controls` on the app **and every extension**. Development entitlement works for dev-signed builds; **App Store / TestFlight needs Apple's Family Controls (Distribution) approval** (request form, ~weeks). |
| Block selected apps | **Not available** (no public API for an ordinary app to stop another app) → "Unsupported on this device setup" | `setPackagesSuspended` (system dialog "app paused") | `ManagedSettingsStore.shield.applications` with opaque `ApplicationToken`s chosen in `FamilyActivityPicker` **on the child's device** |
| Allow only selected apps | Not available | Suspend every launchable non-essential package except allow-list (essential dialer/SMS/settings never suspended; `setPackagesSuspended` returns packages it refused) | `shield.applicationCategories = .all(except: allowed)` |
| Daily limit per app/category | Measure only (UsageStats). Enforcement not available. | Measure via UsageStats + suspend when limit reached (re-evaluated by alarm ≈1 min granularity; not instant) | `DeviceActivityCenter.startMonitoring` with `DeviceActivityEvent(threshold:)`; monitor extension applies shields at threshold |
| Total daily allowance | Measure only | Same as above, across all non-essential apps | DeviceActivity event over all categories |
| Weekday/weekend schedules, School/Homework/Bedtime/custom modes | Schedule evaluated on device but no enforcement → shown as "measuring only" | Applied on device from cached rule set by AlarmManager, offline | `DeviceActivitySchedule` (local, survives offline/reboot); min interval 15 min |
| Browser / site restrictions | Not available without VPN/DNS filter (not built) | Chrome managed configuration (`setApplicationRestrictions` → `URLBlocklist`/`URLAllowlist`); applies to Chrome only — other browsers can be suspended | `shield.webDomains`, `webContent.blockedByFilter(.auto / .specific)` — Safari & WebKit |
| Approved-websites-only | Not available | Chrome `URLBlocklist=["*"]` + `URLAllowlist` (Chrome only; other browsers suspended) | `webContent.blockedByFilter = .all(except: domains)` |
| Restrict now (duration / until released) | Not available | Suspend all non-essential packages; expiry cached on device | Shield all categories except essentials; expiry via DeviceActivity schedule |
| Whole-device lock | Not available | `lockNow()` only locks the screen (user unlocks with PIN) — **not** offered as a restriction. Lock-task mode is kiosk-style; not used. | Not available to third-party apps |
| Mamily-only lock (in-app) | Available (child mode inside Mamily) | Available | Available |
| Essential communication exceptions | n/a | Default dialer, SMS, emergency, Mamily, Settings are never suspended | Phone/emergency always available; allow-list tokens for messaging apps |
| Extra-time requests | Request/approve flow works; on-device effect only where enforcement exists | Extends limit locally once received | Re-registers threshold event with new limit |
| Usage data for parent review | UsageStats per-app foreground time **can be uploaded** (with disclosure) | Same | **Usage data cannot leave the device**: only `DeviceActivityReport` extension can render it, on that device. Remote parent review of iOS usage = unavailable; shown as "Usage stays on the child's iPhone". |
| Offline | Rules cached; enforcement keeps running | Cached rule set + alarms, survives reboot (BOOT_COMPLETED) | Schedules & shields persist in the OS |
| Verified | docs | emulator (see PROGRESS) | docs + simulator build only (Family Controls needs a real device and signing) |

## Location & safety

| Capability | Android | iOS |
|---|---|---|
| Last known location | Fused location, `ACCESS_FINE_LOCATION`; background needs `ACCESS_BACKGROUND_LOCATION` (separate prompt, Play background-location declaration + review) | Core Location; "When in use" first, "Always" for background; `NSLocationAlwaysAndWhenInUseUsageDescription` |
| Battery-conscious updates | Balanced-power interval updates while journey active; otherwise on app open / periodic WorkManager (≥15 min) | Significant-location-change service; standard updates only during journey |
| Safe-place arrive/leave | Geofencing API (≤100 per app), needs background location; delivery can be delayed minutes | Region monitoring (≤20 regions), needs Always; delivery can be delayed |
| Battery level | `BatteryManager` | `UIDevice.batteryLevel` |
| SOS / help | In-app action → backend → push to selected caregivers; local fallback: dial parent / emergency number | Same |
| Guarantee | None — OS can delay/kill background work; UI says "last seen" with timestamp, never "live" | Same |
| Verified | docs | docs |

## Remote help & calls

| Capability | Android | iOS |
|---|---|---|
| View Mamily screen (in-app) | Flutter `RepaintBoundary` frames streamed over the session channel (Mamily only) | Same |
| Share whole device screen | `MediaProjection` with per-session system consent; Android 14+ needs foreground service type `mediaProjection` | ReplayKit Broadcast Upload Extension started by the child from the system picker — **not built yet** (extension + App Group) |
| Control actions inside Mamily | Yes — parent "points" at a control; child's app highlights it and the child taps (guided assistance). No input injection. | Same |
| Control other apps / system settings | **Not available** (only via AccessibilityService, excluded by policy) | Not available on iOS |
| Video/voice call | WebRTC (`flutter_webrtc`), camera/mic runtime permission, visible in-call UI | Same; `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` |
| Infrastructure | STUN works on simple NATs; reliable calls need a **TURN server with time-limited credentials** (`TURN_URLS`, `TURN_SHARED_SECRET`) — not configured | Same |

## Push

| | Android | iOS |
|---|---|---|
| Delivery | FCM HTTP v1 — needs `google-services.json` + service account | APNs via FCM — needs APNs key + `GoogleService-Info.plist` |
| Through Do Not Disturb | Notification channel importance HIGH; DND bypass only if the user allows it for the channel | Critical Alerts need Apple's critical-alert entitlement (not requested) → urgent alerts use time-sensitive interruption level only |
| Verified | fake gateway only | fake gateway only |
