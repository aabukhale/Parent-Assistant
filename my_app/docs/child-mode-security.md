# Child Mode — security limitation (v1)

The Mamily backend (v1) **does not implement child- or device-scoped
authentication**. Every write endpoint — task-completion requests, activity
completions, reward-redemption requests, game start/submit, device usage
ingestion — is authenticated only by a normal **adult family-member Sanctum
token** (`mamily/docs/backend-implementation.md` §14).

## What the Flutter app must NOT do

- Do not build a "Child Mode" that keeps using the parent's unrestricted token.
- Do not expose parent/management endpoints inside a child-facing surface.
- Do not connect child task completion, child reward redemption, child activity
  completion, game-session submission, or usage ingestion **as if the child were
  securely authenticated**.
- Do not solve this with a locally-selected child id and the adult token.

## What is allowed now

- Parent-facing management and **preview** flows (catalogs, read-only progress,
  rule configuration) may be connected normally with the adult token.
- **Task completion requests (Phase 6A)** are connected, but strictly as a
  **parent-managed / on-behalf-of-child** action: `POST …/tasks/{task}/completions`
  is called with the adult token, the flow is launched from the parent's task
  detail screen, and the request sheet carries an explicit note — "You're
  logging this on the child's behalf (secure Child Mode isn't available yet)".
  It is **not** presented as an authenticated child action and there is no
  child-facing surface. Approve / reject / reverse stay parent/caregiver-only
  (permission-gated). When a real child/device session exists, the completion
  request should move behind it.
- **Activity completions (Phase 8)** follow the same rule:
  `POST …/activity-assignments/{a}/complete` is called with the **adult token**
  from the parent's `ChildActivitiesScreen`, and every completion card carries an
  explicit "parent-managed on the child's behalf" note. Approve / reject /
  reverse are permission-gated (`approve_task_completions` / `reverse_points`).
  When a real child/device session exists, the completion action should move
  behind it.
- **Reward redemption requests (Phase 6B)** follow the same rule:
  `POST …/children/{child}/reward-redemptions` is called with the adult token
  from the parent's rewards store, and the confirm dialog carries the explicit
  on-behalf-of-child note (`rewardOnBehalfNote`). It is **not** a child-authenticated
  action and there is no child surface. Approve / reject / cancel are
  permission-gated (`approve_redemptions`), and points only move after a
  parent's backend-side approval. When a real child/device session exists, the
  redemption request should move behind it.

## Blocked child-facing actions (until the backend ships child sessions)

| Action | Endpoint | Blocked in app |
|--------|----------|----------------|
| Child completes a task | `POST …/tasks/{task}/completions` | yes — connected only as parent-managed on-behalf-of (Phase 6A) |
| Child completes an activity | `POST …/activity-assignments/{a}/complete` | yes — connected only as parent-managed on-behalf-of (Phase 8) |
| Child requests a reward | `POST …/children/{child}/reward-redemptions` | yes — connected only as parent-managed on-behalf-of (Phase 6B) |
| Child plays a game | `POST …/game-sessions`, `…/{s}/submit` | yes |
| Device reports usage | `POST …/children/{child}/usage/ingest` | yes — repository ready with idempotency keys (Phase 11); **no native collector**, never called with fabricated data |

## Future requirement (backend + product, not this task)

A product-approved architecture is needed before any unsupervised child use:

- **PIN-verified transition** into Child Mode from the parent app.
- **Device-bound child session** — a per-device token that carries the child
  identity, minted after the PIN check.
- **Restricted API abilities** — the child token may call only the child-facing
  write endpoints for its bound child, nothing else.
- **Expiration / revocation** — short-lived, refreshable while the device stays
  trusted; revocable from the parent app and on device revoke.
- **Return-to-parent PIN gate** — leaving Child Mode requires the parent PIN.
- **Dedicated vs shared device** — `child_dedicated` may (eventually) lock the
  whole device; `family_shared` locks only Mamily Child Mode
  (`enforcement_scope` from `…/screen-time/policy`). Enforcement is **native
  code**; the API only reports policy.

Do **not** modify the Laravel backend to implement this as part of the current
integration task. Track TODOs here, not as scattered code comments.

## Phase 11 — screen time, devices, usage (what is and isn't connected)

Connected as **parent-facing policy configuration only**:

- **Screen-time rules** (`GET/PUT …/screen-time-rules`) and **manual extra-time
  overrides** (`…/screen-time-overrides`) — the parent edits policy; the backend
  stores it and recomputes the effective limit. The Flutter app shows the
  server-computed **summary** (`…/screen-time/summary`) and **policy evaluation**
  (`…/screen-time/policy`).
- The screen-time screen carries a standing disclaimer: *"The app itself does not
  and cannot enforce screen time on the device — that needs native support not
  built yet."* No fake lock screen is shown. `should_lock` / `enforcement_scope`
  from the policy endpoint are **policy data**, not actions.

**Device registration** (`POST /families/{family}/devices`): the app registers
**this install** with a `device_identifier_hash` derived from an app-generated
per-install random id (`SecureTokenStorage.readOrCreateInstallId`) — **not** a
hardware id, IDFA/GAID, or IMEI. It survives logout (a device belongs to the
install, not the session) and is wiped only with app data. Re-registering from
the same install de-duplicates rather than creating a new device row. This grants
the app **no control** over the device.

**Usage ingestion** (`POST …/usage/ingest`): the repository method and typed
`UsageIngestBatch` / `UsageEvent` models exist and correctly carry the two
idempotency keys — `batch_id` (batch) and per-event `client_event_id` — so a
retry reuses them and the backend returns `replayed: true` instead of
double-counting. **There is no native usage collector in this app**, so the
method is never called with data. No UI manufactures usage sessions.

### Remaining native Android/iOS work (not in scope for this integration)

- A native usage-stats collector (Android `UsageStatsManager`, iOS Screen Time /
  `DeviceActivity`) that produces real `UsageEvent`s with stable
  `client_event_id`s, batched with a stable `batch_id`, and an offline queue that
  retries the *same* batch id.
- Native Child Mode enforcement: a device-bound child session (PIN-gated), a real
  lock surface, and `enforcement_scope`-aware locking (`child_dedicated` =
  whole-device where the OS permits; `family_shared` = Mamily Child Mode only).
- A hardware-stable device identifier strategy if the product needs stronger
  de-duplication than the per-install random id.
