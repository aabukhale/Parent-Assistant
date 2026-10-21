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

### NOT done yet (next concrete actions, in order)
1. Native: Android `mamily/device_rules` channel (DeviceAdminReceiver,
   setPackagesSuspended engine, Chrome managed config, UsageStats,
   installed apps, alarms/boot) — today the channel is missing, so every
   capability honestly reports "unsupported". iOS Family Controls plugin
   + DeviceActivity extension. Manifest/Info.plist: location (+background
   during journeys), camera/mic, foreground service type location.
2. Deep links `/parent/remote/{id}`, `/parent/safety`, `/parent/family-map`
   in `lib/app/deep_links.dart`; inbox rendering of help_alert /
   safety_checkin / journey_overdue; urgent card on parent Today;
   urgent toggle + new categories in notification settings; push data
   signals `sync_rules` / `remote_session` → DeviceRulesSync / remote poll.
3. Clear native enforcement on 401 revocation (main.dart listener).
4. Regroup child hub tiles into sections (strings exist: hubSection*).
5. Tests for new widgets/repositories; integration journeys (extra time,
   restriction, remote revoke); emulator + simulator screenshots
   (RTL/large text); migrate the normal dev DB (back it up first).
6. Docs: API reference for new endpoints, external setup list (Firebase,
   APNs, TURN, Family Controls distribution entitlement, OSM tile provider).
