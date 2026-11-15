# iOS push notifications — diagnosis, fixes, remaining setup

Status (2026-11-15): code and project configuration fixed on branch
`feature/push-pairing-child-language` (both repos). **Not verified by real APNs
delivery on a physical iPhone** — that needs the Apple/Firebase steps in §3,
which can't be done from this machine.

Push path: Laravel `NotificationService` → `push_deliveries` row →
queued `SendPushNotification` → `FcmPushGateway` (FCM HTTP v1) → Firebase →
APNs (iOS) / FCM transport (Android) → app (`PushService`).

## 1. Verified identifiers (from the repo and this Mac, not guessed)

| What | Value | Source |
|------|-------|--------|
| iOS bundle id (Runner) | `com.example.myApp` | `ios/Runner.xcodeproj/project.pbxproj` |
| Extensions | `com.example.myApp.FamilyPulseWidget`, `com.example.myApp.ActivityMonitor` | same |
| App Group | `group.com.mamily.app` | `Runner.entitlements`, `FamilyPulseWidget.entitlements` |
| Android package | `com.example.my_app` | `android/app/build.gradle.kts` |
| Firebase project | `mamily-68729` (sender 504806449277) | `GoogleService-Info.plist`, `google-services.json` (added by Anwar, 2da756e) |
| Firebase iOS app | `1:504806449277:ios:dfbddb5c6bde3360195114`, registered for `com.example.myApp` | `GoogleService-Info.plist` |
| Your paid team | **Moaz Razem — `9826A535WG` (Individual)** | Xcode accounts on this Mac |
| Anwar's local team | Personal Team `86DT96Y3KB`, bundle `com.anwarabukhaled.mamily.*` | `project.pbxproj.backup` (his commit) |
| Profiles for 9826A535WG on this Mac | only the wildcard `iOS Team Provisioning Profile: *` (wildcards can't carry push) | `~/Library/Developer/Xcode/UserData/Provisioning Profiles` |
| Firebase access from this Mac | the Firebase CLI login here lists `loginpage-84a2e`, `masar-912a9` — **not** `mamily-68729` | `firebase projects:list` |
| Backend FCM on this Mac | `FCM_CREDENTIALS_PATH` not set; 57 queued jobs overdue (no worker) | `php artisan mamily:push-status` |

Android works because the Gradle `google-services` plugin picks up
`google-services.json` automatically and Android needs no entitlement; the
working backend is Anwar's (this Mac's local backend has no FCM credentials).

## 2. Root causes found (and fixed in code)

1. **`GoogleService-Info.plist` was not in the app bundle.** The file was
   committed to `ios/Runner/` but never added to the Runner target, so
   `Firebase.initializeApp()` threw on iOS, `PushService` switched itself off
   (`notConfigured`) and no iOS token was ever registered. → Added to the
   Runner target's Copy Bundle Resources.
2. **`aps-environment` was removed** from `Runner.entitlements` in 2da756e
   (together with the App Group and Family Controls, presumably so a free
   Personal Team could sign). Without it iOS never issues an APNs device
   token, so FCM can't create one. → Restored (`development`; archive export
   switches it to production). App Group restored too (the widget needs it).
3. **No paid signing team.** A Personal Team can't provision Push
   Notifications. → `DEVELOPMENT_TEAM = 9826A535WG` on all targets.
4. **Token registration read a stale permission.** `registerCurrentSession()`
   used the permission value read once at launch; Anwar's iOS prompt
   (through flutter_local_notifications) granted permission without updating
   it, so the token was never sent. → Re-reads the OS permission every time.
5. **The child side never asked for notification permission**, so an iOS
   child device could never register. → Asked once right after pairing.
6. **FCM token requested before the APNs token existed** (iOS throws
   `apns-token-not-set`). → Waits for the APNs token; `onTokenRefresh` sends
   it later if APNs is slow.
7. Backend: visible pushes now carry `apns-push-type: alert`;
   `THIRD_PARTY_AUTH_ERROR` (no/invalid APNs key in Firebase) is recorded as
   a permanent, named failure instead of being retried 5× as "transient";
   `SENDER_ID_MISMATCH` drops the token.
8. Token lifecycle: one FCM token belongs to one device row
   (`devices.push_token_hash`), so on a shared phone a child can't receive a
   parent's notifications (or vice versa) after a switch; logout clears it.
9. Anwar's 15-second inbox polling (local iOS banners) stays as a fallback but
   no longer shows banners once real push reaches the phone (no duplicates).
10. Scheme fix: `Runner.xcscheme` had `BlueprintName = "يي"` (corrupted in
    2da756e); back to `Runner`.

## 3. Remaining manual steps (need your Apple / Firebase accounts)

Do these in order. Nothing secret goes in git.

**A. Decide the final bundle id.** `com.example.myApp` matches the Firebase iOS
app today, but `com.example.*` ids are commonly already taken and App Store
Connect rejects them. If Xcode (step B) says the id "is not available", pick
an id you own (e.g. reverse domain) and then:
1. Change `PRODUCT_BUNDLE_IDENTIFIER` for Runner (3 configs),
   FamilyPulseWidget and ActivityMonitor (`<id>.FamilyPulseWidget`,
   `<id>.ActivityMonitor`) and RunnerTests in Xcode.
2. Firebase console → `mamily-68729` → Project settings → Add app → iOS →
   that bundle id → download the new `GoogleService-Info.plist` and replace
   `ios/Runner/GoogleService-Info.plist` (same file name; it is already in the
   target).

**B. Provision push with your team.** Open `ios/Runner.xcworkspace` → Runner
target → Signing & Capabilities → Team **Moaz Razem (9826A535WG)**, automatic
signing. Check that Push Notifications, Background Modes → Remote
notifications, and App Groups (`group.com.mamily.app`) are listed without
errors; repeat Team for FamilyPulseWidget and MamilyActivityMonitor. Xcode
registers the App ID with the Push capability and the App Group. Family
Controls (development) is allowed for development builds; TestFlight/App
Store needs Apple's Family Controls distribution approval.

**C. Create an APNs auth key.** developer.apple.com → Certificates,
Identifiers & Profiles → Keys → + → enable *Apple Push Notifications service
(APNs)* → download `AuthKey_<KEYID>.p8` (downloadable once). Note the Key ID.
Team ID: `9826A535WG`. One key serves sandbox and production.

**D. Upload it to Firebase.** Firebase console → `mamily-68729` → Project
settings → Cloud Messaging → Apple app configuration → the iOS app → APNs
Authentication Key → upload the `.p8`, Key ID, Team ID `9826A535WG`. Your
Firebase login on this Mac has no access to this project: either Anwar adds
your Google account to the project, or you hand him the `.p8` over a secure
channel (not plain chat/email, never git).

**E. Backend where pushes are sent (Anwar's).** `FCM_PROJECT_ID=mamily-68729`,
`FCM_CREDENTIALS_PATH=<service-account json outside the repo>`, a running
`php artisan queue:work`, then `php artisan migrate` (adds
`devices.push_token_hash`) and `php artisan mamily:push-status`.

**F. Anwar's builds.** An App Store Connect invitation doesn't give him your
signing certificates, profiles or APNs keys. With an Individual membership,
Apple doesn't share Certificates, Identifiers & Profiles with invited users
(check App Store Connect → Users and Access), so push-capable builds should
be signed on your Mac (or the membership converted to an Organization). If he
builds with his Personal Team he must drop the entitlements locally (don't
commit that), and push won't work on those builds.

**G. Verify on a physical iPhone** (your paired iPhone 16 is visible to Xcode):
1. `flutter run -d <iPhone udid> --dart-define=API_BASE_URL=<backend reachable from the phone>/api/v1`
2. Sign in as a parent → allow notifications. `mamily:push-status` should now
   show `ios: 1 of 1 active installs have a push token`.
3. Trigger a parent notification (e.g. a child marks a task done) with the
   app in the foreground, in the background, and with the phone locked; tap
   it and check the screen it opens.
4. Pair an iPhone as a child (one scan), allow notifications, approve a task
   from the parent → the child gets it in the child's language.
5. If nothing arrives, `mamily:push-status` lists recent iOS errors;
   `THIRD_PARTY_AUTH_ERROR` = step D not done or wrong team/bundle id.

## 4. What was checked here

- Unit/feature tests (server): payload (`apns-push-type`, background signals),
  error classification, token dedupe, logout cleanup, diagnostics command.
- Flutter tests: APNs-before-FCM ordering, no APNs → nothing sent, permission
  re-read, prompt-then-register, token refresh, single registration under
  concurrency, logout deletes the token, parent device registration.
- `flutter build ios --simulator` with the plist in the bundle and the
  restored entitlements; see `docs/PROGRESS.md` for the results of this
  session.
- Not done: real APNs delivery (needs §3).
