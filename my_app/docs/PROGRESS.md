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
- [x] Verification + docs

## Commands & results

- `flutter analyze` → No issues found
- `flutter test` → 486 passed (2026-10-11, after efdac90)
- `flutter test integration_test -d <iOS simulator> --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`
  → 1 passed (pair a child with a real code → "I did it!" → request appears
  in the parent inbox). Needs the local backend running with
  `php artisan mamily:demo-seed --fresh`.
- `flutter build ios --simulator --debug` → ✓ (Xcode 27, arm64 simulator)
- `flutter build apk --debug` (JDK 17) → ✓; `./gradlew :app:lintDebug` → 0 errors
- `flutter build ios --release --no-codesign` → ✓ (incl. FamilyPulseWidget extension)
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

## Still open

- Older detail screens (tasks, rewards store, goals, sleep, screen time,
  content, devices, activities, library, games, reports, forms) still use
  hard-coded `AppColors`/`TextStyle` (~500 sites) instead of
  `context.mamily`/`context.type`. They work and use the accessible palette;
  only targeted fixes were made (task icons, history link).
- Icon picker tiles announce the raw English key ("bed") to screen readers.
- Android widget/floating card never run on a device (no emulator image).
- Real push, signing, App Store/Play setup: needs Firebase files, APNs key,
  team ID, and a real bundle/application id (still `com.example.*`).
