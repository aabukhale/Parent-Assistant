# Mamily family-app overnight build — Flutter progress

Branch: `feature/mamily-family-app` (from `origin/main` @ 63b31ce "activities",
merged with `checkpoint/desktop-uncommitted-design-system` = uncommitted
design-system work recovered from `~/Desktop/Parent-Assistant`).
Backend progress: `~/Developer/mamily/docs/PROGRESS.md`.
Feature preservation matrix: `docs/feature-matrix.md`.

## Workspace decisions (2026-10-10)

| Copy | State | Decision |
|------|-------|----------|
| `~/Developer/Parent-Assistant` (original) | `.git` had only `config` + `objects` (no HEAD/refs) — unusable | moved (not deleted) to `~/Developer/Parent-Assistant.broken-git-backup-20261010`; its tree is a strict subset of the Desktop copy |
| `~/Developer/Parent-Assistant-local` | `feature/api-integration` @ 135ec96, only pod/xcode noise dirty | untouched |
| `~/Desktop/Parent-Assistant` | 135ec96 + 22 uncommitted files (design-system foundation, Rubik font, tests) | recovered into branch `checkpoint/desktop-uncommitted-design-system` (7c463a4); original left untouched |
| remote `main` 63b31ce | newest (children screen tweak, pods) | base of the feature branch |

## Baseline (before any change)

- `flutter analyze` → No issues found
- `flutter test` → 449 passed
- `dart format --set-exit-if-changed` → 1 file unformatted (`children_screen.dart`, from the upstream "activities" commit)

## Plan

1. Foundation: static Rubik weights app-wide, parent + child themes, role-aware session (parent/child), safe navigator + authorized deep links, offline cache keyed by session.
2. Entry: "I'm a parent" / "I'm a child"; pairing by code / QR / `mamily://pair` link; password recovery.
3. Child experience: My Day, routines, tasks, rewards + wish list + saving goal, challenges, messages, mood, requests, notifications, screen-time ask.
4. Parent redesign: Today (Pulse + Needs-you + plan + recap), Inbox, Children hub with every existing per-child feature, Discover, Account (notifications, surfaces, devices).
5. Notifications: FCM (guarded when unconfigured), local notifications, channels, permission UX, tap routing.
6. OS surfaces: Android widget + optional overlay service; iOS WidgetKit + Live Activity.
7. Tests, builds, screenshots, docs.

## Phase log

- [x] Workspace + baseline
- [x] Foundation
- [x] Entry + pairing
- [x] Child experience
- [x] Parent redesign
- [x] Notifications (Dart; real push needs Firebase/APNs config)
- [x] OS surfaces (Android widget + floating card; iOS widget + Live Activity)
- [ ] Verification + docs (in progress)

## Commands & results

- `flutter analyze` → No issues found
- `flutter test` → 485 passed (2026-10-11, after b567ec3)
- `flutter build ios --simulator --debug` → ✓ (Xcode 27, arm64 simulator)
- `flutter build apk --debug` (JDK 17) → ✓; `./gradlew :app:lintDebug` → 0 errors
- Simulator walkthrough (iPhone 17 Pro, local backend + `mamily:demo-seed`):
  role entry, parent sign-in, Today, inbox approve/undo, Children, child hub,
  Account, sign-out, pairing by `mamily://pair` link, My Day, Rewards,
  Together, Me, shared-phone parent sign-in + hand-back, Arabic RTL, largest
  accessibility text, home-screen widget (small/medium), routine Live
  Activity (Dynamic Island + Lock Screen).

## Blockers / external setup

- No `google-services.json` / `GoogleService-Info.plist` / APNs key on this machine.
- No Android system image/AVD installed: Android widget and floating card are
  built and lint-clean but not run on a device.
- Xcode 27 `lipo -verify_arch` accepts one arch only, which breaks Flutter's
  universal simulator build; simulator builds exclude x86_64 (Apple Silicon).

## Fixed after running the app (2026-10-11)

iOS build (deployment target 15, arm64 simulator); `mamily://` scheme was not
registered on either platform; missing iOS camera string (QR pairing crash);
missing Android INTERNET/POST_NOTIFICATIONS; wrong password showed "session
expired"; a mistyped parent password on a child's phone signed the child out;
double RTL mirroring of arrows; white status-bar icons; nested deep links
waited for a pop; undo snackbars never dismissed; child hub showed 0m for
unmeasured screen time and overflowed; ProgressBar fill never drew; kid
'I did it' took 3 taps; text broke letter-by-letter at the largest sizes;
child screens pushed outside the shell lost the kid theme; default Flutter
app icons.

## Checkpoint (2026-10-11, usage limit reached)

Done: foundation, role entry + pairing + recovery, full child experience, parent redesign (Today/Inbox/Child hub/Children/Discover/Account), challenges, planner, recap, routines builder, meals, check-ins & praise, devices & pairing, notification + surface settings, push service (Dart), widget/overlay sync (Dart), Live Activity bridge (Dart). `flutter analyze` clean, `flutter test` 457 passed (at 6888e87).

Switched iOS to CocoaPods (SwiftPM could not resolve firebase-ios-sdk 12.19.0); Podfile platform 15.0.

BLOCKER: disk full (~2.5 GB free). iOS simulator build not yet completed. Free space before building (e.g. old Runner-* DerivedData — not deleted by me since they may belong to other projects).
Simulator panel access was not granted, so screenshots must use `xcrun simctl io booted screenshot`.

Next, in order:
1. Free disk; `flutter build ios --simulator --debug --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`; run with `php artisan serve` + `php artisan mamily:demo-seed --fresh`; screenshot & fix layout (phone/tablet, ar/en, large text).
2. Native: Android manifest (POST_NOTIFICATIONS, SYSTEM_ALERT_WINDOW, foreground service), Kotlin overlay service on channel `mamily/overlay`, FamilyPulseWidgetProvider; conditional google-services plugin. iOS: WidgetKit extension `FamilyPulseWidget` + App Group `group.com.mamily.app`, ActivityKit on channel `mamily/live_activity`, push entitlements.
3. Restyle remaining legacy feature screens (tasks, rewards store, goals, sleep, screen time, content, devices, activities, library, games, reports, forms).
4. New Flutter tests (kid repo/screens, inbox actions, pairing flow, deep-link authorization), integration test, APK + iOS builds, final report.
