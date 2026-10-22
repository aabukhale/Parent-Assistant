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

## Session 2026-10-12

- Restyled every older parent screen onto the design system: tasks (list,
  detail, form, points history, completion sheet, recurrence), rewards
  (store, redemptions, form), learning goals (list, detail, form, progress
  sheet), sleep (summary, form), screen time (summary, rules, extra time),
  content controls + catalog, devices, activities (catalog, details, child
  assignments, generator), library + article, games + details, reports
  (family overview, child summary, development report), child details/form,
  family picker, edit profile, nutrition/AI-coach placeholders. Zero
  `AppColors`/hand-written `TextStyle`/raw hex left in feature code;
  `AppColors` deleted. New shared components: AppListTile, IconBadge,
  HeroMetricCard, ChoiceChipBar, FormSectionLabel, PickerField,
  RadioOptionCard, ReadOnlyField, PermissionNotice; chip theme.
- Fixed while restyling: colour-only status pills/chips (now tone + icon +
  word, checkmarks back on filters), 18-34px touch targets (clear buttons,
  colour swatches), icon buttons without tooltips, family overview had no
  way back, overview showed 0m for unmeasured screen time, raw role enum in
  the family picker, stacked confirm sheets on double tap. Removed dead
  ProfileScreen/AppBottomNavigation/AppBackground.
- AppContentFrame now applies SafeArea(top: false) (a restyle step had
  dropped bottom/side insets on 38 screens; caught and fixed).
- Icon picker announces localized names (en/ar/he), with tests.
- Real-backend integration tests (backend on :8000; :8001 is a second
  instance of the same app/DB and is not used): task approval pays once,
  reward approval spends once, routine bonus pays once, role isolation and
  unpair → 401 → role chooser. 4/4 pass (`flutter test
  integration_test/family_flows_test.dart -d <sim> --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`).
  The older child_flow_test (seed-dependent: it expected a task as Omar's
  next step) was folded into it and removed.
  Pairing is rate-limited to 5/min, 30/h per IP; the suite pairs ~3 times.

## Still open

- Android widget/floating card never run on a device (no emulator image).
- Real push, signing, App Store/Play setup: needs Firebase files, APNs key,
  team ID, and a real bundle/application id (still `com.example.*`).

## Session 2026-10-21/22 — device rules, safety, remote help, child redesign

Capability matrix: `docs/capability-matrix.md`. Backend progress: `mamily/docs/PROGRESS.md`.

### Done (Flutter, Dart only)
- Child: Today / Rewards / Family; all emoji → labelled Material icons;
  Help page (press-and-hold SOS, call fallbacks, emergency number), quick
  check-ins, journeys, location explanation, agreements, lessons, safety
  card, celebrations toggle; remote layer (consent sheet, banner + Stop,
  Mamily-only snapshots, pointer ring); WebRTC call screen.
- Parent: Phone rules (per-device honest state, capabilities, pause now,
  presets, schedules, app pickers, limits, websites, review-before-save,
  history/undo), family map (OSM), safe places, safety screen (help alerts,
  check-ins), safety centre (contacts, pickup, emergency number, urgent
  recipients, caregiver child scope), access history, agreements, setup
  checklist, remote help/call screens. Linked from the child hub.
- `flutter analyze` → 2 infos; `flutter test` → 489 passed.

### Next actions (as of 2026-10-21; superseded by the next session below)
Native channels, deep links, push signals, revoke-clears-rules: done and
verified in the 2026-10-22/23 session.

## Session 2026-10-22/23 — native enforcement, location, calls (verified on devices)

Setup: backend `php artisan serve --port=8100` with `PHP_CLI_SERVER_WORKERS=6`
(port 8000 belongs to another local project; single-worker serve timed out
policy fetches). Parent = iPhone 17 Pro simulator
(`--dart-define=API_BASE_URL=http://127.0.0.1:8100/api/v1`), child = Android
API 35 emulator `mamily_api35` provisioned with
`adb shell dpm set-device-owner com.example.my_app/.rules.MamilyDeviceAdminReceiver`
(`API_BASE_URL=http://10.0.2.2:8100/api/v1`). No personal device was enrolled.

### Verified (observed on the devices, not just compiled)
- **Android app blocking journey**: parent picks Gmail from the child's
  reported app list → review sheet (what changes, which phones, iPhone
  limitation) → v13 saved → phone receives, `setPackagesSuspended` →
  launching Gmail shows the system "app paused" dialog with Mamily's
  support message → parent sees "Rules are on — confirmed by the phone".
  Unblock restores the app; parent waits ("Waiting for the phone") until
  the phone confirms the removal.
- **Expiry offline**: 5-min pause ended with the emulator offline; exact
  alarm re-evaluated within 1 s (inexact alarms were ~2.5 min late →
  `SCHEDULE_EXACT_ALARM` setup step, `timing=approximate` reported otherwise).
- **Reboot**: indefinite pause survived reboot (BOOT_COMPLETED re-evaluates).
- **Offline/reconnect**: release made while the phone was offline was
  applied on reconnect; the app opens offline from a cached child session.
- **Unpair**: parent unpairs → phone's device-status check returns
  `revoked` → all suspensions lifted, device owner released (`dpm list-owners`
  → none). A 401 alone never clears rules (could be a server glitch).
- **Limits**: 1-min daily allowance paused non-essential apps (dialer, SMS,
  settings, launcher stayed usable); usage counts raw UsageStats events
  including the open session, excluding essentials; next check is scheduled
  at the run-out time. Extra-time request → parent approves a different
  amount (5 min) → apps unpause → re-pause on expiry while the child is
  still in the app.
- **Location**: explanation sheet → OS prompt → 5 m fix with battery on the
  parent map; safe-place arrive/leave notifications; journey with
  auto-arrival (announced once); revoked permission → parent sees
  "permission missing".
- **SOS**: press-and-hold → sent to Dana; with no push configured the child
  is told the notification couldn't be sent and offered Call Dana /
  emergency number; parent acknowledges → child sees "Dana saw your
  message"; pick-me-up appears first on the parent Today as a red card.
- **Remote help**: consent sheet → banner with Stop on every child screen →
  parent sees Mamily-only snapshots and points; Stop (child) and End (parent)
  both end at once; signals deleted; access log entries.
- **Calls (WebRTC)**: voice and video between the iOS simulator (parent,
  offerer) and the Android emulator (child). ICE checking → connected in
  ~0.4 s (host candidates; STUN only, no TURN). Child mic/camera start only
  after Answer + OS permission and are released on End from either side
  (`dumpsys audio` rec start/stop, `dumpsys media.camera` no clients). The
  parent saw the emulator's virtual camera; the simulator has no camera so
  the child saw black (expected). Unanswered call → "No answer" after the
  request timeout.
  Bugs found and fixed while verifying: Laravel TrimStrings stripped the
  SDP's trailing CRLF (every offer rejected: "SessionDescription is NULL");
  overlapping 800 ms polls handled the same offer twice; a child reading the
  camera prompt for >45 s hit the idle timeout (engine now heartbeats from
  the start and only hands signals to a fully set-up peer connection);
  white video made the call overlays unreadable (scrims).

### Not verified / blocked (exact reasons)
- **iOS Family Controls enforcement**: code, entitlement and the
  `MamilyActivityMonitor` extension build and install on the simulator, but
  `AuthorizationCenter` needs a real child device signed into a Family
  Sharing child account, a development team, and (for TestFlight/App Store)
  Apple's Family Controls distribution approval. Not run.
- **Real push** (FCM/APNs): no `google-services.json`, `GoogleService-Info.plist`
  or APNs key. Data-only `sync_rules`/`remote_session` handling is wired in
  the foreground; background delivery to the native rules channel is not
  possible from Firebase's background isolate as built (the channel lives on
  the main engine) — the phone catches up on next open/alarm instead.
- **Chrome blocked page**: managed config is written, but checking it needs
  accepting Chrome's first-run terms on the emulator, which I did not do on
  your behalf.
- **Calls across real networks**: only verified on one host (emulator +
  simulator). Without TURN (`TURN_URLS`, `TURN_SHARED_SECRET`) calls behind
  symmetric NAT/CGNAT will fail; the UI says so while connecting.
- **iOS simulator CoreAudio crash**: after several calls in a row the
  simulator aborted in `AURemoteIO::Initialize` (RPC timeout inside WebRTC's
  audio unit setup, not Mamily code). The server ended the orphaned session
  as `idle`. Re-check on a real iPhone.
- **Debug-build ANR** on the emulator under heavy CPU (merged platform/UI
  thread); re-check with a release build.

### Demo data changed on the normal dev DB (restore before real use)
Omar: 1-min daily screen-time rule (was none), device rules v13+ (YouTube /
Gmail / example.com history), location sharing on, "School" safe place,
Dana's contact phone, family emergency number 100.

### Still to do
1. Widget tests for the new parent/child screens and repositories;
   real-backend integration journeys (extra time, restriction, remote revoke).
2. Regroup child hub tiles into sections (`hubSection*` strings exist);
   remaining older parent-screen redesign gaps.
3. Release builds (Android APK/AAB, iOS) and visual checks: tablet,
   ar/he RTL, largest text, TalkBack/VoiceOver, empty/error/offline states;
   screenshots.
4. Docs: API reference for the new endpoints; Info.plist string localization.
