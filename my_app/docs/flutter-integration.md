# Mamily Flutter ↔ Laravel API integration

Living document. It tracks how the Flutter app (`my_app/`) connects to the
Mamily Laravel backend (`../mamily`, **read-only reference** — never modified).

Backend contract of record: `mamily/docs/backend-implementation.md`.

## Status by phase

| Phase | Area | Status |
|-------|------|--------|
| 1 | Foundation (Dio, secure storage, errors, Riverpod, locale, auth gate) | ✅ done |
| 2 | Auth + profile (welcome / login / register / session restore / profile / logout) | ✅ done |
| 3 | Families, children, interests, selected-child context | ✅ done |
| 4 | Structured learning goals (list / detail / form / progress) | ✅ done |
| 5 | Sleep tracking (logs + summary, cross-midnight) | ✅ done |
| 6A | Tasks, completion review (approve/reject/reverse), points balance + ledger | ✅ done |
| 6B | Rewards catalog + redemptions (request / approve / reject / cancel), point deduction + refund, screen-time override side effect | ✅ done |
| 7 | Mother dashboard (`/dashboard`), per-child summary, weekly/monthly development reports | ✅ done |
| 8 | Activity catalog, family activities, assignment + completion workflow, AI generation (honest 503) | ✅ done |
| 9 | Parent library — categories, articles (slug detail), age/interest recommendations | ✅ done |
| 10 | Content catalog + per-child content policy (age filter, allow/block rules) | ✅ done |
| 11 | Devices (register/revoke), screen-time rules + summary + policy, manual extra-time overrides; usage ingest ready (no native collector) | ✅ done |
| 12 | Game catalog (parent preview), game details, per-child progress; sessions ready (no game engine) | ✅ done |
| 13 | AI coach + nutrition → honest unavailable (no backend); biometric disabled; allergies dropped in Phase 3 | ✅ done |

**All 13 phases are connected.** Every navigable screen is either backend-connected
or shows an honest "unavailable" state where the backend/native support is
missing (AI coach, nutrition, AI activity generation, in-app gameplay, device
enforcement, usage collection). The full per-screen breakdown is §14.

## 1. Architecture overview

Feature-first, three layers per feature:

```
lib/
  core/
    api/        dio client, interceptors, envelope + pagination parsing
    config/     compile-time config (API base URL), device label
    errors/     ApiException + ApiErrorKind
    localization/  locale controller, l10n helpers, supported locales
    storage/    SecureTokenStorage (flutter_secure_storage wrapper)
    theme/      colours + ThemeData (unchanged design)
    widgets/    shared state views (loading / empty / error+retry / coming-soon)
    providers.dart   app-wide providers (config, storage, dio, apiClient)
  features/<feature>/
    data/          DTO models + repository (all HTTP lives here)
    application/   Riverpod controllers / state
    presentation/  screens & widgets (no HTTP)
  l10n/          *.arb source; app_localizations*.dart generated (gitignored)
```

- **HTTP** — a single `Dio` (`dioProvider`) with interceptors:
  `AuthInterceptor` (Bearer + `Accept: application/json`, 401 → session wipe
  signal), `LocaleInterceptor` (`Accept-Language`), `SafeLoggingInterceptor`
  (debug only, redacts tokens/passwords/push tokens). `ApiClient` wraps Dio,
  returns a parsed `ApiEnvelope`, and converts **every** failure into a typed
  `ApiException`.
- **State** — `flutter_riverpod`. Controllers are `Notifier`/`AsyncNotifier`.
  Screens read providers; they never call repositories' transport directly.
- **Secure storage** — the Sanctum bearer token and the active-family id live
  only in `flutter_secure_storage`. Passwords are never persisted. The UI
  locale preference is also stored there so it applies before first frame.

## 2. API base URL setup

Supplied at compile time — no machine address is baked in:

```bash
# iOS simulator / desktop (this is also the built-in default)
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

# Android emulator (host loopback is 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Physical device — reachable LAN IP or a tunnel (never commit the URL)
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api/v1
flutter run --dart-define=API_BASE_URL=https://<id>.ngrok-free.app/api/v1
```

A trailing slash is tolerated. Start the backend with `php artisan serve` in
`../mamily` (SQLite by default). Do **not** run `migrate:fresh` against a dev DB.

## 3. Authentication & session lifecycle

`AuthController` (`features/auth/application/auth_controller.dart`) owns it:

1. **Launch** → `AuthGate` shows a splash while `AuthController._restore()`:
   - no stored token → `unauthenticated` (Welcome screen)
   - token present → `GET /auth/me`
     - 200 → `authenticated`, session hydrated, active family resolved
     - 401 → token wiped → `unauthenticated`
     - offline / 5xx → `restoreFailed` (retry screen, **token kept**)
2. **Login / Register** → `POST /auth/login|register`, store token, then
   `GET /auth/me` to hydrate memberships. `family_name` is a real field on the
   registration form (backend requires it).
3. **Mid-session 401** → `AuthInterceptor` wipes the token and bumps
   `unauthorizedSignalProvider`; `AuthController` drops to `unauthenticated`.
4. **Logout** → `POST /auth/logout` (revoke), then always clear local state —
   even if the network call fails.
5. **Profile edit** → `PATCH /me`, result merged into the live session so every
   screen reading `currentUserProvider` refreshes.

Biometric ("fast") sign-in is **disabled** on the Welcome screen — shown but not
faked.

## 4. Family & child context

- `activeMembershipProvider` / `activeFamilyIdProvider` expose the active
  `family_members` row and its family id.
- One membership → auto-selected. Multiple → `FamilySelectionScreen` (plain
  list, no redesign); the choice is persisted and restored next launch.
- No family (edge case) → `NoFamilyScreen`.

### Caregiver effective permissions (Phase 4.5)

The central permission API — screens never inspect role names directly.

- `familyMembersProvider` — `FutureProvider<List<FamilyMember>>`, **watches
  `activeFamilyIdProvider`** → `GET /families/{family}/members`. Pages through all
  members (cap 20 pages). Cached until the family changes or it is invalidated
  (`refreshPermissions(ref)`); null family → empty, no request.
- `permissionsProvider` — `Provider<Permissions>`. Finds the authenticated
  user's row (match `FamilyMember.id == activeMembership.id`, else
  `userId == currentUser.id`) and exposes:
  - `hasPermission(FamilyPermission p)` — **ready** → the row's
    `effective_permissions` verbatim (owner/parent carry all 13, caregivers carry
    exactly what was granted); **loading / error** → role invariant
    (owner/parent `true`, everyone else `false` → management actions
    **default to denied**, req. 11).
  - `canManageChildren` — role-gated (owner/parent), **independent** of the
    members fetch (Sprint 1 invariant, req. 7). Survives a members-fetch failure.
  - `effectivePermissions` — the ready set, or the full set for owner/parent,
    else empty.
  - `shouldSurfacePermissionError` — members fetch failed **and** the user is a
    caregiver (owner/parent are unaffected) → screens show a retry banner.
- Family switch: `familyMembersProvider` rebuilds (goes to `loading`, not
  `data`), so `permissionsProvider` returns `loading` for the **new** family's
  role — the old family's `effective_permissions` are never reused (req. 10).
- `FamilyPermission` enum mirrors `App\Enums\FamilyPermission` (13 values,
  verified against the enum): `manage_tasks`, `approve_task_completions`,
  `manage_rewards`, `approve_redemptions`, `reverse_points`,
  `manage_screen_time`, `grant_extra_time`, `manage_content_policy`,
  `manage_sleep`, `manage_learning_goals`, `manage_activities`,
  `manage_devices`, `view_reports`. Child-*profile* management is deliberately
  **not** a permission key — role-gated only.

### Child context (Phase 3)

- `childrenControllerProvider` — `AsyncNotifier<ChildrenListState>` that
  **watches `activeFamilyIdProvider`**, so a family switch tears the list down
  and reloads (no stale rows). Paginated (`page` / `per_page` / `status`),
  with `refresh()`, `loadMore()` (appends), `setStatusFilter()`,
  `createChild()`, `updateChild()`, `deleteChild()`.
- `selectedChildIdProvider` — `Notifier<String?>` holding the real child UUID.
  Resets when the family changes; auto-selects the first child once the list
  loads; drops a selection that no longer exists (after delete / filter).
  In-memory only (re-selects first child on cold start).
- `selectedChildProvider` — the resolved `Child?`.
- `childScopeProvider` → `({familyId, childId})` — **every child-scoped provider
  in Phases 4–12 must `ref.watch` this (or key a `.family` provider by
  `childId`)** so it rebuilds on a family/child switch. `childDetailProvider`
  is the reference implementation (`FutureProvider.autoDispose.family<Child,String>`,
  watches `activeFamilyIdProvider`).
- Contract mapping applied: write `birth_date` (date picker) / read computed
  `age`; interests submit UUIDs (`interest_ids`), labels are localized;
  `avatar_color` only (no upload); no `school_grade` / `allergies` /
  `learning_goals` on the child. Edit/delete UI is owner/parent-only via
  `permissionsProvider.canManageChildren` (role-gated, Sprint 1 invariant);
  backend also returns 403.

## 5. Endpoint → screen map (implemented so far)

| Screen | Method / path |
|--------|---------------|
| Register | `POST /auth/register` → `GET /auth/me` |
| Login | `POST /auth/login` → `GET /auth/me` |
| Auth gate / restore | `GET /auth/me` |
| Profile tab | session (`GET /auth/me`) |
| Edit profile | `PATCH /me` |
| Language switch | `PATCH /me` (`preferred_language`, best-effort) |
| Logout | `POST /auth/logout` |
| Interests catalog (child form chips) | `GET /interests` |
| Children tab (list, pagination, status filter, pull-refresh) | `GET /families/{family}/children?page&per_page&status` |
| Add child | `POST /families/{family}/children` |
| Child details | `GET /families/{family}/children/{child}` |
| Edit child | `PATCH /families/{family}/children/{child}` |
| Delete (archive) child | `DELETE /families/{family}/children/{child}` |
| Learning goals list (child details → "أهداف التعلم") | `GET …/children/{child}/learning-goals?page&per_page&status` |
| Goal detail | `GET …/learning-goals/{goal}` |
| Create goal | `POST …/learning-goals` |
| Edit goal | `PATCH …/learning-goals/{goal}` |
| Archive goal | `POST …/learning-goals/{goal}/archive` |
| Progress history | `GET …/learning-goals/{goal}/progress?page&per_page` |
| Record progress | `POST …/learning-goals/{goal}/progress` → `{progress, goal}` |
| Caregiver effective permissions (loaded on auth / active-family change) | `GET /families/{family}/members` |
| Sleep log list (child details → "النوم") | `GET …/children/{child}/sleep-logs?page&per_page` |
| Sleep summary (weekly / monthly toggle) | `GET …/children/{child}/sleep-logs/summary?period=` |
| Sleep detail (edit form re-fetch) | `GET …/sleep-logs/{sleepLog}` |
| Add sleep record | `POST …/sleep-logs` |
| Edit sleep record | `PATCH …/sleep-logs/{sleepLog}` |
| Delete sleep record | `DELETE …/sleep-logs/{sleepLog}` |
| Task list (child details → "المهام والنقاط") | `GET …/children/{child}/tasks?page&per_page&status` |
| Task detail (+ completions) | `GET …/children/{child}/tasks/{task}` |
| Create task | `POST …/children/{child}/tasks` |
| Edit task | `PATCH …/children/{child}/tasks/{task}` |
| Archive task | `DELETE …/children/{child}/tasks/{task}` → archived task |
| Completion history | `GET …/tasks/{task}/completions?page&per_page` |
| Log a completion (parent-managed) | `POST …/tasks/{task}/completions` |
| Approve completion | `POST …/tasks/{task}/completions/{completion}/approve` |
| Reject completion | `POST …/tasks/{task}/completions/{completion}/reject` |
| Reverse approved completion | `POST …/tasks/{task}/completions/{completion}/reverse` |
| Points balance | `GET …/children/{child}/points-balance` → `{child_id, balance}` |
| Points ledger | `GET …/children/{child}/point-transactions?page&per_page` |
| Reward catalog (store → "الكتالوج" tab) | `GET /families/{family}/rewards?page&per_page&include_inactive` |
| Create family reward | `POST /families/{family}/rewards` |
| Edit family reward | `PATCH /families/{family}/rewards/{reward}` |
| Delete family reward | `DELETE /families/{family}/rewards/{reward}` |
| Redemption history (store → "السجل" tab) | `GET …/children/{child}/reward-redemptions?per_page` |
| Request redemption (parent-managed, on-behalf-of-child) | `POST …/children/{child}/reward-redemptions` `{reward_id}` |
| Approve redemption | `POST …/reward-redemptions/{redemption}/approve` |
| Reject redemption | `POST …/reward-redemptions/{redemption}/reject` |
| Cancel approved redemption | `POST …/reward-redemptions/{redemption}/cancel` |
| Mother dashboard (Home tab) | `GET /families/{family}/dashboard` |
| Per-child summary (child details) | `GET /families/{family}/children/{child}/summary` |
| Weekly development report | `GET /families/{family}/children/{child}/reports/weekly?date=YYYY-MM-DD` |
| Monthly development report | `GET /families/{family}/children/{child}/reports/monthly?date=YYYY-MM-DD` |
| Activity catalog (Activities tab) | `GET /activities?family_id&source&age&interest&page&per_page` |
| Activity details | `GET /activities/{activity}` |
| AI activity generation (honest 503) | `POST /families/{family}/children/{child}/activities/generate` |
| Assigned activities (child details) | `GET …/children/{child}/activity-assignments?page&per_page` |
| Assign an activity | `POST …/children/{child}/activity-assignments` `{activity_id, points_reward?, due_date?}` |
| Complete an assignment (parent-managed) | `POST …/activity-assignments/{a}/complete` |
| Approve / reject activity completion | `POST …/activity-assignments/{a}/completions/{c}/{approve\|reject}` |
| Reverse activity completion | `POST …/activity-assignments/{a}/completions/{c}/reverse` |
| Library categories (chips) | `GET /library/categories` |
| Library article list | `GET /library/articles?category&page&per_page` |
| Library article detail (by **slug**) | `GET /library/articles/{slug}` |
| Library recommendations (selected child) | `GET /library/recommendations?child_id=` |
| Content catalog (browse) | `GET /content?age&category&page&per_page` |
| Content item detail | `GET /content/{item}` |
| Effective content policy | `GET …/children/{child}/content-policy` |
| Toggle age filter | `PUT …/children/{child}/content-policy` `{age_filter_enabled}` |
| Content rules list | `GET …/children/{child}/content-rules?page&per_page` |
| Save content rule (idempotent, 200/201) | `POST …/children/{child}/content-rules` |
| Delete content rule | `DELETE …/children/{child}/content-rules/{rule}` |
| Devices list | `GET /families/{family}/devices?page&per_page` |
| Register this device | `POST /families/{family}/devices` (`device_identifier_hash` from the install id) |
| Update / revoke device | `PATCH /families/{family}/devices/{device}` |
| Remove device | `DELETE /families/{family}/devices/{device}` |
| Screen-time rules | `GET …/children/{child}/screen-time-rules` |
| Update screen-time rules | `PUT …/children/{child}/screen-time-rules` (`{default, overrides[]}`) |
| Screen-time summary (today, per-app) | `GET …/children/{child}/screen-time/summary?date` |
| Screen-time policy evaluation | `GET …/children/{child}/screen-time/policy?device_id` |
| Extra-time overrides list | `GET …/children/{child}/screen-time-overrides?active_only` |
| Grant extra time | `POST …/children/{child}/screen-time-overrides` |
| Revoke extra time | `DELETE …/children/{child}/screen-time-overrides/{override}` |
| Usage ingest (native bridge only — never fabricated data) | `POST …/children/{child}/usage/ingest` |
| Game catalog (parent preview) | `GET /games?age&page&per_page` |
| Game details | `GET /games/{game}` |
| Per-child game progress | `GET …/children/{child}/game-progress` |
| Start game session (native runtime only — idempotent) | `POST …/children/{child}/game-sessions` |
| Submit game session | `POST …/children/{child}/game-sessions/{session}/submit` |
| Save content rule (idempotent) | `POST …/children/{child}/content-rules` |

## 6. Error-handling rules

`ApiException.kind` (`ApiErrorKind`): `network`, `timeout`, `unauthorized`,
`forbidden`, `notFound`, `conflict`, `validation`, `rateLimited`, `unavailable`
(503), `server`, `unknown`. Mapped from HTTP status in `ApiClient`.

- Screens map `kind` → localized copy via `ApiException.localizedMessage(l10n)`.
  Raw server/exception text is **never** shown to users.
- 422 → `fieldErrors` (`{field: [messages]}`), rendered under the matching input;
  the backend's own messages are used (already localized via `Accept-Language`).
- Entered form values are preserved on failure; submit buttons disable while a
  request is in flight.
- Shared UI: `LoadingView`, `EmptyView`, `ErrorRetryView`, `ComingSoonView`,
  `AsyncDataView<T>` in `core/widgets/state_views.dart`.

## 7. Localization

- `gen_l10n` via `l10n.yaml`; source `lib/l10n/app_{ar,he,en}.arb`
  (**Arabic is the template/default**). Generated `app_localizations*.dart` is
  gitignored and rebuilt by `flutter pub get` / `flutter gen-l10n`.
- `MaterialApp.locale` is driven by `localeControllerProvider`; RTL/LTR is
  automatic from the locale (ar/he = RTL). The locale is also sent as
  `Accept-Language` on every request.
- **Inventory:** screens integrated in Phases 1–3 are localized (ar/he/en) —
  auth, profile, family selection, children list / form / details. Two known
  gaps in Phase 3 screens: the `ChildDetailsScreen` feature-navigation tile
  titles are still hardcoded Arabic (they route into legacy screens that are
  localized in their own phase), and the delete-confirm reuses the shared keys.
  Every legacy screen for a not-yet-integrated phase still contains hardcoded
  Arabic strings. The app is **not** 100% localized yet.

## 8. Mock-data removal inventory

Removed / replaced in Phases 1–2:

| Was | Now |
|-----|-----|
| `main.dart` `LoginDemoScreen` / `RegisterDemoScreen` with `Navigator.pushReplacement` to a fake dashboard | Real `LoginScreen` / `RegisterScreen` calling `POST /auth/login`/`register` |
| `main.dart` `DashboardDemoScreen` hardcoded `Child(name: 'ليان', …)` + inline stat cards ("2س 15د", "250" points) | Removed. Home tab shows the real user greeting + family name; stats deferred to Phase 7 (no fabricated numbers) |
| `profile_screen.dart` `'Anwar Abu Khaled'` / `'ولي أمر'` | Real `currentUserProvider` name + role from `activeMembershipProvider` |
| `edit_profile_screen.dart` `TextEditingController(text: 'Anwar Abu Khaled')` / `'parent@example.com'` | Seeded from the real session user; persists via `PATCH /me` |
| `main.dart` empty-callback biometric `TextButton` | Disabled, honest "not available yet" label |
| Broken `test/widget_test.dart` (referenced non-existent `MyApp`) | Real smoke test + API/auth test suites |

Removed in Phase 3:

| Was | Now |
|-----|-----|
| `lib/models/child.dart` — `age` (int), `schoolGrade`, `allergies`, `learningGoals` as `List<String>` | `features/children/data/models/child.dart` — `birthDate` + computed `age`, `interests` as `Interest` rows; no school grade / allergies / goals on the child |
| `ChildrenScreen` hardcoded `[Child(name:'ليان',age:8,…), Child(name:'محمد',…)]` + `setState(children.add(...))` | `GET /families/{family}/children`, paginated, pull-to-refresh, status filter |
| `AddChildScreen` — `id: DateTime.now().millisecondsSinceEpoch.toString()`, Arabic-digit age parsing, hardcoded interest name list `['الرسم','القراءة',…]`, `Navigator.pop(context, child)` (local only) | `child_form_screen.dart` — date-picker `birth_date`, catalog chips submitting UUIDs, real `POST` / `PATCH` |
| `ChildDetailsScreen` fake stat cards ("2س 15د", "250" نقطة, "8س 10د") | Real header (name / computed age / interests). The stats area was a "pending dashboard" note through Phase 6B; **Phase 7** replaced it with the real `ChildSummarySection`. Feature-navigation tiles preserved. |
| `widgets/child_card.dart` (unused, wrong contract) | deleted |

Removed / confirmed-absent in Phase 4:

| Item | Status |
|------|--------|
| `Child.learningGoals` as `List<String>` | Already removed in Phase 3; the Phase 4 `LearningGoal` model is a structured resource with its own providers. Nothing stores goals as strings. |
| `DevelopmentScreen` "التقدم هذا الأسبوع" cards (78% / 65% …) | Left as legacy through Phase 6B (it is the weekly *report* mock, not learning goals). **Deleted in Phase 7** and replaced by the real `DevelopmentReportScreen`. |
| Learning-goal UI | Did not exist before Phase 4 — built fresh, fully wired, no mock/local-only path. `current_value` and `progress_percentage` are read from the backend and never recomputed. |

Removed in Phase 5 (`SleepScreen` / `AddSleepScreen` rebuilt in place):

| Was | Now |
|-----|-----|
| `SleepScreen` `sleepRecords` list of `{'date':'الأربعاء','sleep':'9:30 م','wake':'7:15 ص','duration':'9س 45د'}` maps | Real `SleepLog` list from `GET …/sleep-logs`, paginated, tap-to-edit |
| Hardcoded average `"9س 17د"`, "وقت النوم 9:30 م", "وقت الاستيقاظ 7:00 ص" | Real `average_sleep_minutes` from the summary endpoint (period toggle); the two stat cards now show real `nights_logged` + `total_sleep_minutes` |
| `AddSleepScreen` returning `{'duration':'9س 30د'}` (fixed string) + `setState(sleepRecords.insert(0, result))` (local-only) | Real `POST …/sleep-logs` with UTC timestamps; duration comes from the backend's `duration_minutes`; list/summary refresh after save |
| `AddSleepScreen` `TimeOfDay`-only (same-night assumption) | Full date + time pickers for both ends; defaults to 21:00 → +10h (crosses midnight); a "Next day" badge shows when the two ends fall on different local days |
| `lib/models/sleep.dart` (empty) | deleted |

Removed in Phase 6A (`RewardsScreen` / `AddTaskScreen` rebuilt as `lib/features/tasks/`):

| Was | Now |
|-----|-----|
| `RewardsScreen` `int points = 240` mutated locally on task tap (`points += tasks[i]['points']`) | Real `GET …/points-balance`; **never** computed or mutated client-side |
| Hardcoded `tasks` list of `{'title':'ترتيب الغرفة','points':20,'done':true}` maps, `done` toggled with `setState` | Real `GET …/tasks` (paginated, status filter); completion state comes from `GET …/tasks/{task}` + `…/completions` |
| Small stats "المهام المكتملة" / "هذا الأسبوع +85" | Removed. Balance card taps through to the real ledger (`point-transactions`). |
| `AddTaskScreen` returning a fake map, appended locally | Real `TaskFormScreen` → `POST …/tasks` with the exact recurrence contract |
| `lib/models/reward.dart` (empty) | deleted |
| Rewards *store* button | kept visible (navigates to the legacy `RewardsStoreScreen`) — **not connected**; reward endpoints are Phase 6B |

Removed in Phase 6B (`lib/features/rewards/rewards_store_screen.dart` — Anwar's
flat hardcoded catalog — deleted; rebuilt under `lib/features/rewards/{data,application,presentation}/`):

| Was | Now |
|-----|-----|
| `RewardsStoreScreen` hardcoded `rewards` list (`{'title':'وقت شاشة إضافي','cost':50,'icon':…}`) | Real `GET /families/{family}/rewards`, paginated, ordered by `points_cost`, global-template + family rows split into labelled sections |
| Local `int _balance = 250` decremented on "استبدال" tap | Real `pointsBalanceProvider` (shared with Phase 6A). The request **never** deducts locally; the balance only moves after the backend approves and the ledger is re-fetched |
| "استبدال" instantly "buys" the reward client-side | `POST …/reward-redemptions` creates a **pending** request; parent then approves/rejects; approval is what deducts (backend `PointTransactionType::Redemption`), cancel refunds via a compensating entry |
| No redemption history | "السجل" tab → real `reward-redemptions` list with `pending`/`approved`/`rejected`/`cancelled` state, review notes, deduction/refund txn ids |
| No screen-time effect | Approved `screen_time` reward → the embedded `screen_time_override` (minutes / expiry / revoked) is rendered from the approve/cancel/list response — **no extra request**, and it is labelled backend policy data, not a device restriction |

Removed in Phase 7 (`lib/features/dashboard/home_screen.dart` old placeholder,
`lib/features/development/development_screen.dart` mock, and the empty stubs
`lib/features/dashboard/dashboard_screen.dart` / `lib/features/development/weekly_report_screen.dart` /
`lib/models/development.dart` — all deleted):

| Was | Now |
|-----|-----|
| `HomeScreen` "ملخص اليوم" placeholder card ("stats will appear once the dashboard is connected") | Real `GET /families/{family}/dashboard` — a per-child card (points, screen-time used vs limit, last-sleep duration, pending approvals). Empty / loading / error / retry states; **no number shown while loading** |
| `ChildDetailsScreen` `l.childDetailsStatsPending` note (key deleted) | `ChildSummarySection` → `GET …/children/{child}/summary`: points, screen-time-today, last sleep, active tasks, pending approvals, active/achieved goals. Tiles link to the connected feature screens |
| `DevelopmentScreen` `_ProgressHeader` "+12%", `_ProgressCard` percentages (78% reading / 65% learning / 82% activity / 70% habits), "+12% better than last week" message | Deleted — fabricated. `DevelopmentReportScreen` → `GET …/reports/{weekly\|monthly}` shows the six **real** backend sections (screen-time / sleep / activities / games / tasks / points) as aggregate cards |
| `DevelopmentScreen` `_SummaryCard` fixed values ("6.5" learning hours, "12" activities, "4" books, "8" games) | Removed. Report metrics are real period aggregates; a section with `has_data:false` shows "no data for this period", not a zero |
| Composite "development score" / weekly-vs-last-week trend | **Not provided by the backend** — no score is invented. The screen shows only what `DevelopmentReportService` returns (see "Unsupported cards / metrics") |

Removed in Phase 8 (`lib/features/activities/*.dart` flat mock screens + `lib/models/activity.dart`
deleted; rebuilt under `lib/features/activities/{data,application,presentation}/`):

| Was | Now |
|-----|-----|
| `ActivitiesScreen` hardcoded `activities` list (`{'title':'اصنع قصة مصورة','category':'إبداع','duration':'30 دقيقة',…}`) | `GET /activities?family_id=` — global + AI + family activities, paginated, real `source` / duration / age range |
| `GenerateActivityScreen` static `_Dropdown`s + `AlertDialog` showing a canned "اصنع قصة مصورة!" suggestion | Honest unavailable screen; the "Check again" button really calls `POST …/activities/generate` and shows the backend's own **503** (`UnavailableActivityGenerator`). Nothing generated locally |
| `ActivityDetailsScreen` displaying passed-in mock strings | `GET /activities/{activity}` — real title/description (API-localized), materials, steps; "assign to child" flow persisting via `POST …/activity-assignments` |
| No assignment / completion workflow | `ChildActivitiesScreen` (child details tile) — real assignments, parent-managed on-behalf-of-child `complete`, and permission-gated approve/reject/reverse; points move only after a backend-confirmed approval |
| `lib/models/activity.dart` (empty) | deleted |

Removed in Phases 9–13 (see per-phase sections below):

| Phase | Deleted / replaced | Now |
|-------|--------------------|-----|
| 9 | `library_screen.dart` hardcoded article list + fake "5 دقائق" reading time; `article_details_screen.dart` (mock strings) | `GET /library/{categories,articles,articles/{slug},recommendations}` — real articles, API-localized, category chips, child recommendations |
| 10 | `content_control_screen.dart` local-only toggles (educational/entertainment/games/social) + fake "save" button; `channel_management_screen.dart` (dead mock) | `GET/PUT …/content-policy` (age filter), `…/content-rules` (idempotent allow/block), `GET /content` catalog; enforcement disclaimer |
| 11 | `screen_time_screen.dart` local slider + fake "2س 15د" + hardcoded app list; `extra_time_screen.dart` fake grant | `…/screen-time-rules` editor, server `…/screen-time/summary`, `…/screen-time-overrides` grant/revoke, devices CRUD; usage-ingest repo ready (no native collector) |
| 12 | `games_screen.dart` hardcoded games grid; `game_play_screen.dart` decorative gameplay; `game_details_screen.dart` mock | `GET /games`, `/games/{id}`, `…/game-progress` — real catalog + progress; honest "not playable in the app" state |
| 13 | `ai_parenting_screen.dart` locally-faked assistant replies; `nutrition_screen.dart` + `meal_result_screen.dart` fabricated "smart" results | `ComingSoonView` honest unavailable state — no chat input, no fabricated advice, no local persistence offered |
| 14 | `lib/models/` (all empty stubs: `parent.dart`, `nutrition.dart`, `content_control.dart`, `activity.dart`, …); `lib/widgets/stat_card.dart` (unused) | deleted; `lib/widgets/bottom_navigation.dart` + the two family edge screens localized |

**No mock, hardcoded, generated, or locally-calculated business data remains in
any connected screen.** Remaining legacy mock lives only in the untouched
onboarding-adjacent files (`lib/features/auth/login_screen.dart` /
`register_screen.dart` old copies, `lib/features/profile/settings_screen.dart`,
`lib/features/splash/splash_screen.dart`) — none are navigable in the live app
(the shell uses `features/auth/presentation/*` and `features/shell/app_shell.dart`).

### Activities (Phase 8)

- Backend (`ActivityController`, `ActivityAssignmentController`,
  `CompleteActivityAssignmentAction`, `UnavailableActivityGenerator` — inspected):
  - `GET /activities` — any authenticated user; `family_id` (optional) must be a
    family you actively belong to (else 404). Returns global (`family_id=null`) +
    that family's own activities. Filters: `source`, `age`, `interest`. Paginated.
  - `GET /activities/{activity}` — 404 for inactive or an inaccessible family
    activity (never 403).
  - `POST /families/{family}/activities` / `DELETE …/{activity}` —
    `manage_activities`; a family activity is only deletable by its own family.
  - `POST …/children/{child}/activities/generate` — `manage_activities`.
    **Always 503** (`ServiceUnavailableException`) until `AI_ACTIVITY_PROVIDER`
    is configured — never fabricates or persists.
  - `GET …/children/{child}/activity-assignments` — any active member. Paginated,
    embeds `activity` + `completions`.
  - `POST …/activity-assignments` — `manage_activities`. `points_reward > 0` →
    `requires_approval: true`.
  - `POST …/activity-assignments/{a}/complete` — **any active member**
    (parent-managed / on-behalf-of-child). Auto-approves when `points_reward == 0`;
    otherwise lands `pending`. 409 if already completed / cancelled.
  - `.../completions/{c}/approve` + `/reject` — `approve_task_completions`;
    `/reverse` — `reverse_points`. 409 on invalid transitions.
- **Enums** (verified): `ActivitySource {global, ai, family}` (unknown → global),
  `AssignmentStatus {assigned, completed, cancelled}` (unknown → assigned),
  completion status reuses Phase 6A's `CompletionStatus {pending, approved,
  rejected}` — a reversed completion keeps `approved` + non-null `reversed_at`.
- **Fields used verbatim** — `materials` / `steps` default to `[]` server-side and
  are modelled as always-lists; `duration_minutes` / `min_age` / `max_age` stay
  nullable ("not set", not 0). `title` / `description` are API-localized — never
  re-translated. Nothing invented (no difficulty, benefits, images, points).
- **Providers**: `activitiesCatalogControllerProvider` (`AsyncNotifier`,
  family-scoped via `activeFamilyIdProvider`, paginated), `activityDetailProvider`
  (`autoDispose.family` by id), `activityAssignmentsControllerProvider`
  (`AsyncNotifier`, child-scoped via `childScopeProvider`, paginated + mutations).
  `assign` / completion actions `await refresh()` then invalidate points balance +
  ledger and `bumpDashboardRefresh` — points are never computed locally.
- **Screens**: Activities tab → `ActivitiesScreen` (catalog); `ActivityDetailsScreen`
  (details + assign sheet, needs a selected child + `manage_activities`);
  `GenerateActivityScreen` (honest 503); child details "الأنشطة المُسندة" tile →
  `ChildActivitiesScreen` (assignments + workflow, per-row busy guard, 409 →
  localized conflict + server refresh).
- **Child Mode**: `complete` uses the adult token from the parent screen with an
  explicit on-behalf-of-child note. See `docs/child-mode-security.md`.

### Parent library (Phase 9)

- Backend (`LibraryController`, `ArticleResource`, `ArticleCategoryResource` —
  inspected): `GET /library/categories` (plain array), `GET /library/articles?category`
  (paginated, **`body: null`**, 200-char `excerpt`), `GET /library/articles/{slug}`
  (route key is the **slug**; 404 unpublished; **full `body`**),
  `GET /library/recommendations?child_id|age` (≤10 rows, 422 if neither given).
  Any authenticated user; no family/child tenancy on the catalog.
- Model: `Article{slug, title, excerpt?, body? (null in list ⇒ "open the article",
  not "empty"), author:{name?, type ('mamily_staff'|'specialist'|null|unknown)},
  min_age?, max_age?, published_at?, categories[]}`. `title`/`excerpt`/`body` are
  API-localized — never re-translated.
- Providers: `libraryCategoriesProvider` (cached), `articlesControllerProvider`
  (`AsyncNotifier`, re-fetches on `libraryCategoryFilterProvider` change),
  `articleDetailProvider(slug)`, `libraryRecommendationsProvider` (selected child →
  `child_id`; null child → skipped, no 422).
- **No engagement backend** — no bookmarks, likes, views, or reading-progress
  endpoints exist, so none are built or faked. Reached from the child-details
  "مكتبة الأهل" tile.

### Content controls (Phase 10)

- Backend (`ContentPolicyController`, `ContentCatalogController`,
  `ContentRuleResource`, `StoreContentRuleRequest` — inspected):
  - `GET …/content-policy` → **effective** policy (server-computed):
    `{child_age, content_age, age_filter_enabled, category_decisions:{id→'allow'|'block'},
      item_decisions:{…}, external_channels:[{provider_key, external_ref, label, decision}]}`.
  - `PUT …/content-policy` `{age_filter_enabled}` — `manage_content_policy`. The
    **only** mutable *setting*.
  - `GET …/content-rules` (paginated) / `POST …/content-rules` /
    `DELETE …/content-rules/{rule}` — `manage_content_policy`. `POST` is
    **`updateOrCreate` by a derived target key** → idempotent (201 create / 200
    update); a repeated identical rule updates instead of duplicating.
  - `GET /content?age&category` — public catalog.
- Rule types (verified): `category` (needs `content_category_id`), `content_item`
  (needs `content_item_id`), `external_channel` (needs `provider_key` +
  `external_ref`); decision `allow` / `block`. Enums parse unknowns to `unknown`.
- Providers: `contentPolicyProvider` (child-scoped, server-authoritative),
  `contentRulesControllerProvider` (child-scoped; every mutation `refresh()`s the
  list **and** `ref.invalidate`s `contentPolicyProvider` — the effective policy is
  derived, never patched locally), `contentCatalogControllerProvider` (age from
  the selected child).
- **Enforcement**: `ContentControlScreen` carries a standing disclaimer — *"stored
  parental preferences on the backend; the app cannot itself block apps or media
  on the device — enforcement needs native support that isn't built yet."* An
  age-filter toggle failure keeps the real server value (no optimistic flip).

### Devices & screen time (Phase 11)

- Backend (`DeviceController`, `ScreenTimeController`, `ScreenTimeOverrideController`,
  `IngestUsageAction` — inspected):
  - Devices: `GET/POST /families/{family}/devices`, `PATCH/DELETE …/{device}`.
    `device_identifier_hash` is **required** so a repeated registration
    de-duplicates. `DeviceResource` exposes `has_push_token` only (never the
    token). `child_dedicated` / `family_shared` modes are *recorded intent* — the
    API never locks a device.
  - Rules: `GET/PUT …/screen-time-rules`. `PUT` **replaces** the whole set —
    `{default:{daily_limit_minutes 0–1440, …}, overrides:[{day_of_week 1–7, …}]}`
    (max 7). A disabled default (`is_enabled:false`) is what removes the limit;
    `0` means "no screen time".
  - Summary: `GET …/screen-time/summary?date` — server-computed
    `{used_minutes, base_limit_minutes?, bonus_minutes, effective_limit_minutes?,
      remaining_minutes?, rule_source, has_sufficient_data, per_app[]}`. Null limits
    ⇒ "no rule configured", **not** 0.
  - Policy: `GET …/screen-time/policy?device_id` → `{should_lock, lock_reason?,
    enforcement_scope, note}` — a **policy evaluation**, not an action.
  - Overrides: `GET/POST/DELETE …/screen-time-overrides` — `grant_extra_time`.
    Grant/revoke `ref.invalidate`s the summary + bumps the dashboard.
  - Usage: `POST …/usage/ingest` `{batch_id, device_id?, events:[{…,
    client_event_id}]}` — `batch_id` = batch idempotency key, `client_event_id` =
    per-event key; a replayed batch returns `replayed:true` (200) instead of
    double-counting.
- **`device_identifier_hash`** is derived from `SecureTokenStorage.readOrCreateInstallId`
  — an **app-generated per-install random id** (not a hardware/advertising id),
  kept across logout, wiped only with app data.
- **No native usage collector** in this app — `ingestUsage` / `UsageIngestBatch`
  / `UsageEvent` exist with correct idempotency handling for a future native
  bridge and are never called with fabricated data. No UI manufactures usage.
- The screen-time screen carries the enforcement disclaimer; no fake lock screen.
  `docs/child-mode-security.md` §"Phase 11" records the exact limitation and the
  remaining native Android/iOS work.

### Games (Phase 12)

- Backend (`GameController`, `GameResource`, `GameSessionResource`,
  `GameProgressResource` — inspected): `GET /games?age` (paginated),
  `GET /games/{game}` (route binds by **slug**, not id), `GET …/game-progress` (array),
  `POST …/game-sessions` `{game_id, device_id?, client_session_id}` (idempotency
  key; 201 create / 200 existing), `POST …/game-sessions/{session}/submit`
  `{status?, score?, progress?, ended_at?}`.
- `GameType` (`memory`/`puzzle`/`quiz`/`matching`/`drawing`/`other` — unknown →
  `other`), `GameSessionStatus` (`in_progress`/`completed`/`abandoned` — unknown
  tolerated). `config` is opaque backend JSON the app never interprets.
- **No game engine in the app** — games are **not playable inside Flutter**. The
  details screen shows an honest "can't be played inside the app yet" state and
  the child's **real** `GameProgress` aggregates (best score / attempts / play
  time / last played). `startSession` / `submitSession` are in the repository
  (with the idempotency key) for a future native/web runtime; no score, level,
  star, or elapsed time is ever invented. Reached from the child-details
  "الألعاب" tile.

### Deferred features (Phase 13)

- **AI parenting coach** — no backend endpoint exists. `AiParentingScreen` was
  faking assistant replies locally; that is removed. Now a `ComingSoonView` with
  **no chat input** and no fabricated advice.
- **Nutrition / meal logs / photo analysis** — no backend. `NutritionScreen` +
  `MealResultScreen` produced fabricated "smart" results; removed.
  `NutritionScreen` is now a `ComingSoonView` — no input, because locally entered
  meal/allergy data would not persist anywhere.
- **Allergies** — already dropped from the child model in Phase 3 (no backend).
- **Biometric login** — shown but honestly disabled on Welcome since Phase 2.
- **Secure child mode / native device enforcement** — documented in
  `docs/child-mode-security.md`; not implemented, not faked.

### Mother dashboard & development reports (Phase 7)

- Backend surface (`App\Http\Controllers\Api\V1\DashboardController`,
  `DashboardService`, `DevelopmentReportService` — all inspected, read-only):
  - `GET /families/{family}/dashboard` → `{family_id, children_count,
    children:[<child summary>]}`. **Any active member** (`activeMembershipOrNotFound`
    → 404 for outsiders, not 403). One request returns every active child's digest
    — archived children are excluded server-side.
  - `GET …/children/{child}/summary` → one child digest:
    `{child_id, name, age?, points_balance,
      screen_time_today:{used_minutes, effective_limit_minutes?, remaining_minutes?},
      last_sleep: null | {started_at, ended_at, duration_minutes},
      tasks:{active, pending_approval},
      learning_goals:{active, achieved}}`.
    Gated on **`view_reports`** (owner/parent always; a caregiver needs the grant
    → 403 otherwise).
  - `GET …/children/{child}/reports/{weekly|monthly}?date=YYYY-MM-DD` →
    `{schema_version, period, period_start, period_end (date-only),
      timezone, generated_at, has_sufficient_data,
      sections:{screen_time, sleep, activities, games, tasks, points}}`.
    Each section is `{has_data, …integer aggregates}`. Gated on `view_reports`.
    `date` (optional) anchors the week/month; omitted → "now" in the family
    timezone. **No pagination**, no API Resource — the service array is wrapped
    straight into `{success,message,data}`.
  - Nullable fields kept nullable: `age`, `screen_time_today.effective_limit_minutes`,
    `screen_time_today.remaining_minutes` (null = "no rule configured", **not** 0),
    `last_sleep` (null = no sleep logged). Section metrics are always non-null
    integers (0 with no data, distinguished by `has_data`).
- Providers (`lib/features/dashboard/`):
  - `parentDashboardProvider` — `FutureProvider.autoDispose`, watches
    `activeFamilyIdProvider` (family switch → refetch, old family's numbers never
    shown) **and** `dashboardRefreshSignalProvider`. `null` family → `StateError`
    → error/retry UI.
  - `childSummaryProvider` — `FutureProvider.autoDispose.family` by child UUID,
    watches `activeFamilyIdProvider` + the signal. Auto-disposes when the child
    details screen leaves, so a fresh visit always refetches.
  - `developmentReportProvider` — `FutureProvider.autoDispose.family` by period
    (`weekly` / `monthly`), watches `childScopeProvider` + the signal. Weekly and
    monthly are separate keys, so toggling never shows the other period's data
    under the new label. `reportPeriodProvider` (`StateProvider.autoDispose`,
    defaults `weekly`) drives the toggle.
- **Invalidation**: `dashboardRefreshSignalProvider` (in `core/providers.dart`,
  bumped via `bumpDashboardRefresh(ref)`) is a leaf `StateProvider<int>` the
  three dashboard providers `ref.watch`. It is bumped after: child
  create/update/delete, task create/update/archive, any completion action
  (`_afterAny`), any sleep-log mutation (`_reconcile`), learning-goal
  create/update/archive and progress record, and reward-redemption approve/cancel
  (`_refreshLedger`). No cross-feature import (core is a leaf); no circular
  dependency (dashboard providers don't feed any mutation controller).
- **Screens**:
  - **Home tab** (`HomeScreen`, rebuilt) — real greeting + a per-child card
    (points, screen-time used and, if a limit exists, "of <limit>" — else "No
    limit set"; last-sleep duration or "None yet"; pending approvals). Tap a card
    → selects that child + opens child details. Pull-to-refresh; loading shows a
    spinner and **no numbers**; empty family → honest empty state.
  - **Child details** — `ChildSummarySection` replaces the old placeholder.
    Stat tiles for points / screen-time-today / last-sleep / active-tasks /
    pending-approvals / goals; each tile navigates to the connected feature
    screen (tasks, sleep, learning goals). A caregiver without `view_reports`
    (or a 403) sees an honest "not available with your permissions" line, never a
    blank or a zero. `null` values render as "Not available", distinct from `0`.
  - **Development tab + child-details "تطور الطفل" tile** — `DevelopmentReportScreen`.
    Weekly/monthly `SegmentedButton`; a `has_sufficient_data:false` banner; six
    section cards showing the real aggregates (durations via `formatDurationMinutes`
    from backend minutes, counts plain, points net signed). No selected child →
    "choose a child" empty state. `view_reports` gated like the summary.
- **No charts**: `DevelopmentReportService` returns **period aggregates only** —
  no per-day series, no trend, no composite score. The screen therefore shows
  section cards, not time-series charts, and invents nothing. See "Unsupported
  cards / metrics".
- **Localization**: all new strings in `app_{ar,he,en}.arb` (`dash*`, `home*`,
  `commonDuration*`); RTL verified by widget smoke tests. The backend `timezone`
  string and `period` are shown verbatim (already backend data). Date ranges use
  locale-aware `DateFormat.MMMd`.

### Rewards & redemptions (Phase 6B)

- Providers (`lib/features/rewards/`):
  - `rewardsControllerProvider` (`AsyncNotifier<RewardsListState>`) — **family-scoped**
    (`ref.watch(activeFamilyIdProvider)`, not child): the catalog is the same for
    every child in a family, so a same-family child switch keeps it. Paginated,
    `setIncludeInactive(bool)` (adds `include_inactive=true`, `manage_rewards`
    only), `createReward` / `updateReward` / `deleteReward` → `refresh()`.
    `state.global` / `state.family` split on `scope == 'global' || family_id == null`.
  - `redemptionsControllerProvider` (`AsyncNotifier<RedemptionsListState>`) —
    **child-scoped** through `childScopeProvider`; null scope → empty, no request.
    `requestRedemption` (no ledger touch), `approve` / `reject` / `cancel`.
  - Points: reuses Phase 6A's `pointsBalanceProvider` + `pointsTxControllerProvider`.
- **Enum / metadata mapping** (verified against `App\Enums\*` and the Form Requests):
  - `RewardType`: `screen_time` / `physical` / `family_activity` / `privilege`.
    Immutable after creation (`UpdateRewardRequest` has no `type`) — the edit
    form shows it read-only.
  - `RedemptionStatus`: `pending` / `approved` / `rejected` / `cancelled`.
  - `ScreenTimeOverrideSource`: `manual` / `reward_redemption`.
  - `metadata` is an opaque JSON object; only `metadata.minutes` (int 1–600,
    `screen_time` only) is surfaced and editable. No invented fields.
  - Redemption rows carry backend **snapshots** (`reward_title` /`reward_type` /
    `points_cost` from `*_snapshot` columns) — displayed verbatim even if the
    reward later changes. `reward_type` snapshot is a raw string, parsed leniently.
- **Global vs family**: global templates (`family_id == null`) render with a
  "قالب Mamily" badge, **no** edit/delete menu, and no "استبدال"-disable when
  active — they are redeemable but read-only (backend 404s any write). Family
  rewards get the edit/delete `PopupMenuButton` when `manage_rewards`.
- **Points (never authoritative locally)**: `AffordabilityHint` is an
  informational hint off the cached balance only. `requestRedemption` creates a
  pending row and touches no ledger. `approve` and `cancel` post, then
  `ref.invalidate` the balance + ledger (re-fetched). `reject` touches no
  ledger. The point transaction is never created, edited, or deleted client-side.
- **Screen-time side effect**: rendered **only** from the `screen_time_override`
  object embedded in the approve / cancel / list responses (`ScreenTimeOverrideCard`
  — minutes, expiry, revoked). No call to `GET …/screen-time-overrides`. The card
  copy states it is backend policy data, not a device restriction. If the
  approve response has no override (minutes 0 / already granted), nothing extra
  is shown and no follow-up request is made.
- **Conflicts / validation**: duplicate pending → 409 → `redemptionConflict`;
  inactive reward on request → 422 on `reward_id` → `redemptionRewardUnavailable`;
  insufficient balance on approval → **422** → `redemptionInsufficient`;
  already-reviewed / cancel-non-approved → 409 → `redemptionConflict` + state
  refresh from the server. Mutation buttons carry a per-row busy guard.
- **Permissions**: `manage_rewards` (reward CRUD), `approve_redemptions`
  (approve / reject **and cancel** — the backend's `cancel` enforces
  `ApproveRedemptions`, see "Backend-contract mismatches"). Any active member
  may request a redemption. Permission-load failure → management denied + the
  shared retry banner.
- **Child Mode**: a redemption request uses the adult token and is launched from
  the parent store with an explicit on-behalf-of-child note in the confirm
  dialog — never presented as an authenticated child action. See
  `docs/child-mode-security.md`.

### Tasks & points (Phase 6A)

- Providers scope through `childScopeProvider`: `tasksControllerProvider`
  (`AsyncNotifier`, paginated list + status filter), `taskDetailProvider`
  (`FutureProvider.autoDispose.family` by task id, includes `completions`),
  `completionsControllerProvider` (`AsyncNotifierProvider.autoDispose.family`
  by task id — paginated history + `requestCompletion` / `approve` / `reject`
  / `reverse`), `pointsBalanceProvider` (`FutureProvider.autoDispose`) and
  `pointsTxControllerProvider` (`AsyncNotifier`, paginated ledger). A family or
  selected-child change tears **all** of them down and reloads.
- **Points source of truth**: the app never awards, removes, or sums points.
  `approve` / `reverse` post to the backend and then `ref.invalidate` the
  balance and the ledger — both are re-fetched. `requestCompletion` / `reject`
  touch no ledger and skip that step.
- **Recurrence** — real `recurrence_type` + `recurrence_config`, no invented
  fields:
  - `one_time` / `daily` → `recurrence_config` omitted (backend nulls it).
  - `weekly` → `recurrence_config.days_of_week` (ISO 1–7, ≥1).
  - `custom` → either `recurrence_config.dates` (`YYYY-MM-DD[]`) **or**
    `recurrence_config.interval_days` (1–365) + `recurrence_config.anchor_date`.
  `recurrence_type` / `recurrence_config` are **immutable** after creation (the
  edit form shows them read-only). The completion-request form only lets the
  user pick a date `<= today`; **the backend is authoritative** on whether that
  date is a scheduled occurrence (invalid → 422, shown on the field).
- **Completion state machine** (UI buttons follow `status`, never assumptions):
  - `pending` → **Approve** / **Reject** (needs `approve_task_completions`).
  - `approved` & `reversed_at == null` → **Reverse** (needs `reverse_points`).
  - `approved` & `reversed_at != null` → "Reversed" badge, no actions
    (backend rejects a second reverse with 409).
  - `rejected` → no actions; the backend re-opens the row to `pending` if the
    same occurrence is requested again (the "Log a completion" button).
  - Per-completion busy guard prevents double-taps; 409 → localized
    `completionConflict` + the history/detail refresh from the server.
- **Ledger is read-only** — `point-transactions` is displayed, never edited or
  deleted.
- **Permissions**: `manage_tasks` (create/edit/archive), `approve_task_completions`
  (approve/reject), `reverse_points` (reverse) — all via `permissionsProvider`.
  Any active member may log a completion. Permission-load failure → those
  actions denied + the shared retry banner.

### Sleep (Phase 5)

- Providers scope through `childScopeProvider`: `sleepLogsControllerProvider`
  (`AsyncNotifier`, paginated list + `refresh`/`loadMore`/`createLog`/`updateLog`/
  `deleteLog`), `sleepSummaryProvider` (`FutureProvider.autoDispose.family` by
  period `weekly`/`monthly`), `sleepLogDetailProvider`
  (`FutureProvider.autoDispose.family` by log id — the edit form re-fetches so a
  concurrently deleted record shows a 404 state, not stale data). A family or
  selected-child change tears every provider down and reloads.
- Every mutation refreshes the list, `ref.invalidate`s the affected
  `sleepLogDetailProvider`, and `ref.invalidate`s **all** `sleepSummaryProvider`
  instances so the averages stay in step.
- **Timezone**: wire timestamps are UTC ISO-8601 (parsed `isUtc: true`).
  Displayed via `toLocal()` (device timezone) with locale-aware `DateFormat.jm`
  / `DateFormat.MMMEd`. The summary is computed **server-side in the family
  timezone** — its minute totals and date strings are shown verbatim, no
  client conversion. IANA family-timezone conversion of individual log
  timestamps needs the `timezone` package (deferred); the device timezone is
  correct for the common case (parent's phone in the family's zone). See
  "Backend-contract mismatches".
- **Cross-midnight**: `started_at` and `ended_at` are independent full
  timestamps; a period spanning midnight is one record. `SleepLog.crossesMidnightLocal`
  drives the "Next day" badge. `duration_minutes` is always the backend value —
  never recomputed from the timestamps.
- **Summary insufficient data**: `has_sufficient_data == false` → the average
  card shows an honest "not enough data" message instead of a number, and the
  total stat shows "—".
- **Overlap 409**: mapped to a localized `sleepOverlap` banner on the form
  ("This period overlaps another sleep record…").
- **Permissions**: create/edit/delete gated on
  `permissionsProvider.hasPermission(FamilyPermission.manageSleep)` — owner/parent
  always, caregiver only with the real grant, denied on a permission-load
  failure (with the shared retry banner). `source` is always `manual` on
  create (no device monitoring); edit omits `source` to preserve it.

### Learning goals (Phase 4)

- Providers all scope through `childScopeProvider` (`{familyId, childId}` from
  `activeFamilyIdProvider` + `selectedChildIdProvider`):
  `learningGoalsControllerProvider` (`AsyncNotifier`, paginated list + status
  filter), `learningGoalDetailProvider` (`FutureProvider.autoDispose.family` by
  goal id), `goalProgressControllerProvider`
  (`AsyncNotifierProvider.autoDispose.family` by goal id, paginated history +
  `record()`). Family/child change → `build()` re-runs → state cleared & reloaded.
- Mutations (create / update / archive / record-progress) refresh the list,
  `ref.invalidate` the goal detail, and — for progress — re-`refresh` the list so
  a backend **auto-achieve** is reflected.
- Metric handling: `boolean` (progress 0/1, no target), `numeric`
  (count + optional unit toward target), `percent` (0–100). `metric` and
  `start_date` are immutable after creation (edit form locks the metric picker).
- Edit form status picker offers `active` / `paused` / `achieved` only;
  `archived` is set through the dedicated archive action.
- Edit / archive / record-progress visibility is gated on
  `permissionsProvider.hasPermission(FamilyPermission.manageLearningGoals)`
  (Phase 4.5) — owner/parent always, a caregiver **only when their real
  `effective_permissions` include `manage_learning_goals`**. On a
  permission-load failure a caregiver sees a retry banner and the actions stay
  hidden (denied by default).

## 9. Deferred / blocked features

| Feature | Handling |
|---------|----------|
| AI parenting coach | No backend. Phase 13 → `ComingSoonView`. |
| Nutrition photo analysis | No backend. Phase 13 → `ComingSoonView`. |
| Allergies | Backend deferred. Field dropped from the child model in Phase 3. |
| Biometric login | Deferred. Disabled on Welcome (done). |
| **Child Mode** | Backend has **no** child/device-scoped session. Only parent-facing management/preview flows will be connected. See `child-mode-security.md`. |
| Native screen-time enforcement | Not in scope. The API returns policy only; the app must not claim enforcement. |

## 10. Manual test order

1. `cd ../mamily && php artisan serve`
2. `cd my_app && flutter run --dart-define=API_BASE_URL=<see §2>`
3. Register a new account (fill name, **family name**, email, password) → lands
   on the app shell, Home tab greets you by name.
4. Kill & relaunch the app → you stay signed in (session restored from `/auth/me`).
5. Profile tab → Edit profile → change first name → Save → name updates
   everywhere.
6. Profile tab → Language → switch to English/Hebrew → UI + direction flip,
   `Accept-Language` changes on subsequent calls.
7. Stop the backend, relaunch the app → "retry" screen (token kept); start
   backend, tap retry → restores.
8. Profile tab → Sign out → back to Welcome; token revoked server-side.
9. Log in again with the same credentials.
10. Children tab → empty state → **Add a child**: enter name, pick a birth date
    (age preview updates), pick interests → Save → appears in the list; the
    first child is auto-selected (teal border).
11. Open the child → **Edit** → change the name / interests → Save → list and
    header update. **Delete** → confirm → child archived, list refreshes.
12. Status filter → *Archived* shows it; *All* shows both.
13. As a caregiver account: child Add/Edit/Delete controls are hidden (role);
    a direct attempt still returns a localized "not permitted" message (403).
    As a caregiver granted `manage_learning_goals` in the backend, the
    learning-goal add/edit/archive/record actions **do** appear.
14. Open a child → **أهداف التعلم** → add a goal (try each metric: done/not-done,
    counter with unit, percentage). Open the goal → **Record progress** →
    for a numeric/percent goal enter a value that meets the target → the goal
    flips to **Achieved** (backend auto-achieve) and the history shows the entry.
15. Edit a goal (title / target / status), archive it, check the *Archived*
    filter. Switch child → the goal list reloads for the new child.
16. Open a child → **النوم** → add a record: pick a bedtime of ~21:00 and a
    wake time the *next morning* → the "Next day" badge appears, Save → the
    record shows the backend-derived duration and the summary average updates.
17. Add an overlapping record → localized overlap message. Edit a record's
    times, delete a record (app-bar trash) → list + summary refresh.
18. Toggle the summary between Weekly / Monthly. With no logs in range the
    average card shows "not enough data", not a number.
19. Open a child → **المهام والنقاط** → the balance is real; add a task (try
    each recurrence — weekly needs ≥1 weekday, custom needs dates or an
    interval). Open the task → **Log a completion** (a date ≤ today; an
    out-of-schedule date returns a field error).
20. As an owner/parent: Approve the pending completion → the balance and the
    ledger update (no local math). Reverse it → a compensating entry appears,
    the balance drops back, a second Reverse is refused. Reject a completion,
    then re-request the same occurrence → it re-opens as pending.
21. As a caregiver with only `manage_tasks` you can add/edit tasks but not
    review; with `approve_task_completions` you can approve/reject; with
    `reverse_points` you can reverse. Without a permission the button is hidden
    and a direct attempt returns a localized 403.
22. Open a child → **المهام والنقاط** → tap the rewards-store icon (top bar) →
    the store opens. "الكتالوج" tab: global templates show a "قالب Mamily" badge
    with no edit menu; family rewards have an edit/delete menu (owner/parent, or
    a caregiver with `manage_rewards`). The balance strip is the real balance.
23. Tap "استبدال" on a reward → confirm dialog (title, cost, affordability hint,
    on-behalf-of-child note) → a **pending** row appears in "السجل"; the balance
    does **not** move.
24. As owner/parent (or `approve_redemptions`): in "السجل" approve the pending
    row → balance drops by the snapshot cost, ledger shows a `redemption` entry.
    Cancel the approved row → a refund entry appears, balance returns; for a
    `screen_time` reward the override card flips to "revoked".
25. Reject a different pending row → status only, balance unchanged. Request the
    same reward twice without reviewing the first → 409 "already a pending
    redemption". Approve when the child can't afford it → 422 "not enough points".
26. `include_inactive` chip (manage_rewards) shows archived rewards; create a
    `screen_time` reward (minutes 1–600 required), edit it (type is locked),
    delete it. Switch family → the catalog reloads; switch to another child in
    the same family → the catalog stays, the redemption history reloads.
27. Home tab → the mother dashboard lists each active child with real points,
    screen-time-used (and "of <limit>" or "No limit set"), last-sleep duration
    (or "None yet") and pending-approval count. Pull to refresh. With no children
    → honest empty state; stop the backend and pull → retry state.
28. Approve a task completion for a child, then return to Home → that child's
    points and pending-approval count have updated (the dashboard refresh signal).
29. Open a child → the summary section shows the same real figures as tiles;
    tap a tile → it opens the connected feature screen for that child.
30. Open a child → **تطور الطفل** (or the Development tab) → weekly report. Toggle
    to monthly → a separate request; the date range in the header updates. A
    period with no activity shows "not enough activity", and each empty section
    says "no data for this period" — never a fake 0 or %.
31. As a caregiver **without** `view_reports`: the child summary section and the
    development report show an honest "not available with your permissions"
    message (the Home dashboard itself still loads — the backend allows it). Grant
    `view_reports` in the backend → both surfaces load.

## 11. Verification commands

```bash
flutter pub get
flutter gen-l10n            # if not triggered automatically
flutter analyze             # No issues found
flutter test                # 384 passing
flutter test --coverage     # optional; writes coverage/lcov.info (gitignored)
dart format --output=none --set-exit-if-changed lib $(find test -name '*.dart')
git diff --check
git status --short
```

Running against a local Laravel safely:

```bash
# 1. backend (in ../mamily) — SQLite by default, do NOT migrate:fresh a real DB
php artisan serve            # http://127.0.0.1:8000

# 2. app — point at it (see §2 for emulator/device variants)
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

The base URL is compile-time only — nothing is baked into the binary and no
address is committed. The Sanctum token lives only in `flutter_secure_storage`.

## 12. Backend-contract mismatches / notes

| Area | Note |
|------|------|
| Sleep summary timezone | The summary is computed server-side in the family IANA timezone; individual log timestamps are shown in the **device** timezone (correct for the common case). Full per-log IANA conversion needs the `timezone` package — deferred. |
| Redemption **cancel** permission | The Phase 6B spec expected cancellation to enforce `reverse_points`. The backend's `RewardRedemptionController::cancel` actually enforces `FamilyPermission::ApproveRedemptions`. The app follows the **backend** — cancel is gated on `approve_redemptions`. |
| Redemption request permission | `store` has **no** permission gate beyond active membership — any active member (including a caregiver with no reward permissions) can request a redemption. The app matches this (the "استبدال" button is always enabled for active members). |
| `screen_time_override` on reject | Present (as `null`) on `index`/`approve`/`cancel`; **omitted** on the `reject` response (`whenLoaded`). The model treats absent and `null` identically. |
| `reward_type` snapshot | Stored/returned as a raw string, not the `RewardType` enum's `->value` path. Parsed leniently; an unknown value falls back rather than throwing. |
| Extra screen-time endpoint | `GET/POST /families/{family}/children/{child}/screen-time-overrides` exists but is **not** called — the embedded object on the redemption response is the single source, per the Phase 6B requirement. |
| Dashboard reports: no time series | `DevelopmentReportService` returns period **aggregates only** — no per-day/per-week series, no composite "development score", no trend or week-over-week comparison. Anwar's mock development screen showed all of these; they are **removed**, not reimplemented. If a product spec wants trend charts, the backend needs a series endpoint first. |
| `parentDashboard` authorization | Only `activeMembershipOrNotFound` — **any** active member (including a caregiver with no `view_reports`) can load the mother dashboard. Only the per-child *summary* and the *reports* are `view_reports`-gated. The app matches this: the Home tab is not permission-gated; `ChildSummarySection` and `DevelopmentReportScreen` are. |
| Report `date` param has no Form Request | `DashboardController::report` does `Carbon::parse($request->string('date'))` with no validation — a malformed value would 500. The app only ever sends a valid `YYYY-MM-DD` (from the period toggle; no free-text date picker is exposed). |
| Child summary `age` | Sourced from `Child::$age` (computed from `birth_date`); modelled as nullable on the client in case `birth_date` is absent. |
| Activity catalog age filter | `GET /activities?age=` filters by min/max; the app passes the selected child's age. `family_id` must be an active family (else 404). |
| AI activity generation | `POST …/activities/generate` **always 503** (`UnavailableActivityGenerator`) until `AI_ACTIVITY_PROVIDER` is configured. The app calls it and shows the backend's own 503 — never fabricates. |
| Library engagement | No bookmark/like/view/reading-progress endpoints exist. Not built, not faked. |
| Content-rule POST idempotency | `updateOrCreate` by target key ⇒ 201 on create, **200 on update**. The app treats both as success. |
| Content policy vs device enforcement | `content-policy` / `content-rules` store *policy config*. There is **no** device-side content blocking — enforcement is native work not built. The screen says so. |
| Screen-time `PUT` replaces the whole set | `SyncScreenTimeRulesAction` deletes and re-creates from the payload. The editor always sends the full default + all enabled weekday overrides. |
| Screen-time / dashboard limit fields | `effective_limit_minutes` / `remaining_minutes` / `base_limit_minutes` are `null` when no rule is configured — rendered as "no limit set", never 0. |
| `screen-time/policy` `should_lock` | A **policy decision**, not an action. The app never locks anything; there is no native enforcement layer. |
| Usage ingest | Repository + idempotency-key models are ready; **no native usage collector exists**, so ingest is never called with data. See `docs/child-mode-security.md` for the remaining native work. |
| Device identifier | `device_identifier_hash` = hash of an app-generated per-install random id (`readOrCreateInstallId`), **not** a hardware/advertising id. Documented as such. |
| Games not playable in-app | No game engine. `game-sessions` start/submit (with `client_session_id` idempotency) are in the repository for a future runtime; scores/levels/stars are never invented. Real `game-progress` aggregates are shown. |
| AI coach / nutrition | No backend at all → honest `ComingSoonView`; no chat, no fabricated results, no local persistence. |
| `GET /games/{game}` route key | Binds by **slug** (`Game::getRouteKeyName()` → `'slug'`), same as library articles. `GameDetailsScreen` passes `game.slug`; progress rows are then matched by the returned `game.id`. (`game_id` in the `POST /game-sessions` **body** is the UUID, per `StartGameSessionRequest`.) |

## 13. Unsupported cards / metrics (shown as unavailable, not synthesised)

| Legacy UI element | Status |
|-------------------|--------|
| `_ProgressCard` domain percentages (reading 78%, learning 65%, activity 82%, habits 70%) | **Removed.** No backend equivalent — the reports expose raw counts/minutes per domain, not a 0–100% "mastery". |
| `_ProgressHeader` "+12%" and "12% better than last week" | **Removed.** No week-over-week comparison in the API. |
| `_SummaryCard` "6.5 learning hours" | **Removed.** The report has `tasks`, `activities`, `games` counts and `screen_time`/`sleep` minutes — there is no "learning hours" aggregate. |
| Per-day charts / sparklines | **Not built.** The report is a period aggregate; there is no daily series to plot. Sleep *does* have a per-night series on its own Phase 5 summary endpoint, shown on the sleep screen — not duplicated here. |
| Development score / rating | **Not built.** Deliberately not invented. |

## 14. Real-data coverage matrix (every navigable screen)

Status legend: **Live** = fully backend-connected; **Preview** = read-only
backend data, no in-app write path by design; **Unavailable** = backend/native
support missing, honest state shown; **UI-only** = layout with no business data.

| Screen | File | Role gate | Endpoint(s) | Provider(s) | Data | Mutations | Limitation |
|--------|------|-----------|-------------|-------------|------|-----------|------------|
| Welcome | `features/auth/presentation/welcome_screen.dart` | — | — | — | UI-only | — | biometric shown-disabled |
| Login / Register | `features/auth/presentation/{login,register}_screen.dart` | — | `POST /auth/{login,register}` → `/auth/me` | `authControllerProvider` | Live | login/register | `family_name` required on register |
| Family selection / No family | `features/family/presentation/*` | — | session | `activeMembership*` | Live | select family | edge case |
| Home (mother dashboard) | `features/dashboard/presentation/home_screen.dart` | any member | `GET /families/{f}/dashboard` | `parentDashboardProvider` | Live | — (pull-refresh) | not `view_reports`-gated (matches backend) |
| Children list | `features/children/presentation/children_screen.dart` | any member | `GET …/children` | `childrenControllerProvider` | Live | — | — |
| Add / Edit child | `features/children/presentation/child_form_screen.dart` | owner/parent | `POST/PATCH …/children/{c}` | `childrenControllerProvider` | Live | create/update | role-gated |
| Child details | `features/children/presentation/child_details_screen.dart` | any member | `GET …/children/{c}` | `childDetailProvider` | Live | delete (owner/parent) | — |
| Child summary section | `features/dashboard/presentation/child_summary_section.dart` | `view_reports` | `GET …/children/{c}/summary` | `childSummaryProvider` | Live | — | caregiver w/o grant → honest restricted |
| Development report | `features/dashboard/presentation/development_report_screen.dart` | `view_reports` | `GET …/reports/{weekly\|monthly}` | `developmentReportProvider` | Live | — | period aggregates only, no charts |
| Learning goals + detail + progress | `features/learning_goals/presentation/*` | `manage_learning_goals` | `…/learning-goals*` | `learningGoals*Provider` | Live | create/update/archive/record | — |
| Sleep + form | `features/sleep/presentation/*` | `manage_sleep` | `…/sleep-logs*`, `…/summary` | `sleep*Provider` | Live | create/update/delete | per-log IANA tz deferred |
| Tasks + detail + points | `features/tasks/presentation/*` | `manage_tasks` / `approve_task_completions` / `reverse_points` | `…/tasks*`, `…/completions*`, `…/points-balance`, `…/point-transactions` | `tasks*` / `points*` | Live | CRUD + review; completion is parent-managed | Child Mode boundary |
| Rewards store (catalog + redemptions) | `features/rewards/presentation/rewards_store_screen.dart` | `manage_rewards` / `approve_redemptions` | `…/rewards*`, `…/reward-redemptions*` | `rewardsController` / `redemptionsController` | Live | CRUD + request/approve/reject/cancel | request is parent-managed; screen-time override read-only |
| Reward form | `features/rewards/presentation/reward_form_screen.dart` | `manage_rewards` | `POST/PATCH …/rewards` | `rewardsControllerProvider` | Live | create/update | `type` immutable on edit |
| Activities catalog | `features/activities/presentation/activities_screen.dart` | any member | `GET /activities` | `activitiesCatalogControllerProvider` | Live | — | `family_id` = active family |
| Activity details + assign | `features/activities/presentation/activity_details_screen.dart` | `manage_activities` (assign) | `GET /activities/{a}`, `POST …/activity-assignments` | `activityDetailProvider` | Live | assign | needs selected child |
| Generate activity | `features/activities/presentation/generate_activity_screen.dart` | `manage_activities` | `POST …/activities/generate` | — | Unavailable (503) | "check again" retries | no AI provider configured |
| Child activities (assignments) | `features/activities/presentation/child_activities_screen.dart` | `approve_task_completions` / `reverse_points` | `…/activity-assignments*` | `activityAssignmentsControllerProvider` | Live | complete (parent-managed) / approve / reject / reverse | Child Mode boundary |
| Parent library + article | `features/library/presentation/*` | any user | `/library/*` | `articlesController` / `articleDetailProvider` / recommendations | Live | — | no engagement backend |
| Content controls | `features/content_control/presentation/content_control_screen.dart` | `manage_content_policy` | `…/content-policy`, `…/content-rules` | `contentPolicy` / `contentRulesController` | Live | age filter + rule save/delete (idempotent) | policy config, **not device enforcement** |
| Content catalog | `features/content_control/presentation/content_catalog_screen.dart` | `manage_content_policy` (rules) | `GET /content` | `contentCatalogControllerProvider` | Live | per-item / per-category rule | — |
| Screen time | `features/screen_time/presentation/screen_time_screen.dart` | any member (read) | `…/screen-time/summary`, `…/screen-time-rules` | `screenTimeSummary` / `screenTimeRules` | Live (read) | — | **no device enforcement**; disclaimer shown |
| Screen-time rules editor | `features/screen_time/presentation/screen_time_rules_editor_screen.dart` | `manage_screen_time` | `PUT …/screen-time-rules` | `saveScreenTimeRules` | Live | replace rule set | — |
| Extra time | `features/screen_time/presentation/extra_time_screen.dart` | `grant_extra_time` | `…/screen-time-overrides` | `overridesControllerProvider` | Live | grant / revoke | — |
| Devices | `features/devices/presentation/devices_screen.dart` | any member (read); policy for write | `/families/{f}/devices` | `devicesControllerProvider` | Live | register this install / revoke / remove | app-generated install id; no device control |
| Games catalog + details | `features/games/presentation/*` | any member | `GET /games`, `/games/{g}`, `…/game-progress` | `gamesCatalog` / `gameDetail` / `gameProgress` | Preview (catalog+progress Live) | — | **not playable in-app** (no engine); sessions ready for a future runtime |
| Parenting coach | `features/ai_parenting/ai_parenting_screen.dart` | — | — | — | Unavailable | — | no backend |
| Nutrition | `features/nutrition/nutrition_screen.dart` | — | — | — | Unavailable | — | no backend |
| Profile + edit | `features/profile/*` | — | session, `PATCH /me` | `currentUserProvider` | Live | update profile / language / logout | — |

### Remaining backend work (product decisions, not this integration)

- An AI parenting-coach endpoint; an AI activity-generation provider
  (`AI_ACTIVITY_PROVIDER`); a nutrition / meal-log / photo-analysis service.
- A development-report **daily-series** endpoint if trend charts are wanted.
- A secure child/device session (see `docs/child-mode-security.md`).
- Library engagement (bookmarks / progress) if the product needs it.

### Remaining native Android/iOS work

- A usage-stats collector feeding `POST …/usage/ingest` with stable
  `batch_id` / `client_event_id`s and an offline retry queue.
- Native screen-time / content enforcement (lock surface, app/media blocking),
  `enforcement_scope`-aware.
- A game runtime (native or web view) that drives `game-sessions`.
- A hardware-stable device identifier strategy if stronger de-dup than the
  per-install random id is required.
