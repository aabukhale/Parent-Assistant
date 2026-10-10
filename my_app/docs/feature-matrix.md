# Feature preservation matrix

Every capability that existed before the redesign (left) and where it lives now.
"Verified by" names the automated test(s) or the manual/simulator check.
Status is updated as work lands; see `docs/PROGRESS.md` for the log.

Legend — Role: **P** parent/caregiver session, **C** paired child session.

## Existing capabilities (must survive)

| # | Capability | Before (file / tab) | After (redesigned location) | API | Verified by |
|---|------------|---------------------|-----------------------------|-----|-------------|
| 1 | Welcome, login, register | `auth/presentation/*` | Role entry → "I'm a parent" → sign in / create family | `POST /auth/login|register`, `GET /auth/me` | `test/features/auth/*` |
| 2 | Session restore / offline retry / 401 wipe | `auth_gate.dart` | Same gate, now role-aware (parent: `/auth/me`, child: `/child/me`) | same + `/child/me` | `auth_flow_test`, `session_restore_test` |
| 3 | Family selection / no family | `family/presentation/*` | Unchanged flow, restyled | session | `auth_flow_test` |
| 4 | Mother dashboard | Home tab | **Today** tab: Family Pulse + dashboard stats per child | `/families/{f}/pulse`, `/dashboard` | `today_screen_test` |
| 5 | Children list, add/edit/delete child | Children tab | **Children** tab → child hub; avatar picker added | `…/children*` | `children_screen_test`, `child_form_test` |
| 6 | Child details + summary | child_details_screen | Child hub header + "Summary" card | `…/children/{c}`, `…/summary` | `child_hub_test` |
| 7 | Development report (weekly/monthly) | Development tab | Child hub → "Growth report" | `…/reports/*` | `development_report_screen_test` |
| 8 | Learning goals CRUD + progress | child details → goals | Child hub → Goals | `…/learning-goals*` | `learning_goals_*` |
| 9 | Sleep logs + summary | child details → sleep | Child hub → Sleep | `…/sleep-logs*` | `sleep_*` |
| 10 | Tasks CRUD, review (approve/reject/reverse), points ledger | child details → tasks | Child hub → Tasks & points; approvals also in **Inbox** | `…/tasks*`, `…/completions*`, `…/points-*` | `tasks_*`, `inbox_test` |
| 11 | Rewards catalog CRUD + redemptions | child details → rewards | Child hub → Rewards; approvals in **Inbox** | `…/rewards*`, `…/reward-redemptions*` | `rewards_*`, `inbox_test` |
| 12 | Activities catalog, details, assign | Activities tab | **Discover** → Activities | `/activities*`, `…/activity-assignments` | `activities_*` |
| 13 | Child activity assignments + review | child details | Child hub → Activities; approvals in **Inbox** | `…/activity-assignments*` | `activities_*` |
| 14 | AI activity generation (honest 503) | Activities | Discover → Activities → "Generate" (unavailable state) | `…/activities/generate` | `deferred_screens_test` |
| 15 | Parent library + articles | child details / home | **Discover** → Library | `/library/*` | `library_test` |
| 16 | Content controls + catalog | child details | Child hub → Content | `…/content-*`, `/content` | `content_control_test` |
| 17 | Screen time summary, rules editor, extra time | child details | Child hub → Screen time (honest source labels) | `…/screen-time*` | `screen_time_test` |
| 18 | Devices (register install / revoke) | child details | Account → This device; Child hub → Devices & pairing | `/families/{f}/devices*` | `devices_test` |
| 19 | Games catalog + details + progress (preview) | child details | **Discover** → Games | `/games*`, `…/game-progress` | `games_test` |
| 20 | Caregiver effective permissions | everywhere | Unchanged provider; actions hidden/denied when not granted | `/families/{f}/members` | `permissions_controller_test` |
| 21 | Profile edit, language switch, logout | Profile tab | **Account** tab | `PATCH /me`, `/auth/logout` | `profile_test` |
| 22 | Parenting coach (unavailable) | Profile | Discover → Coach (honest unavailable) | — | `deferred_screens_test` |
| 23 | Nutrition (unavailable) → **meal log diary** | Profile | Child hub → Meals (diary, no analysis) | `…/meal-logs*` | `meals_test` |

## New capabilities

| # | Feature | Where (P / C) | API | Verified by |
|---|---------|---------------|-----|-------------|
| N1 | Role entry (parent / child), child pairing by code or QR, child session restore | Entry; Child hub → Devices & pairing | `/child-auth/pair`, `/child/me`, `…/pairing-codes`, `…/devices` | `pairing_flow_test`, backend `ChildPairingTest` |
| N2 | Password recovery | Sign-in → "Forgot password" | `/auth/forgot-password`, `/auth/reset-password` | `password_reset_test`, backend `PasswordResetTest` |
| A | Family Pulse | P: Today | `/families/{f}/pulse` | `today_screen_test`, backend `FamilyOverviewTest` |
| B | My Day | C: My Day | `/child/my-day` | `my_day_test`, backend `ChildJourneyTest` |
| C | Routine Builder + runs | P: child hub → Routines; C: My Day → routine | `…/routines*`, `/child/routines*` | `routines_test`, backend `RoutineTest` |
| D | Mood check-ins + replies | C: My Day / Me; P: Inbox + child hub | `/child/checkins`, `/families/{f}/checkins*` | `checkins_test`, backend `EngagementTest` |
| E | Family challenges | P: Discover/Today; C: Together | `/families/{f}/challenges*`, `/child/challenges*` | `challenges_test`, backend `ChallengeTest` |
| F | Reward wish list + saving goal | C: Rewards; P: Inbox | `/child/wishes`, `/child/saving-for`, `…/reward-wishes*` | `wishes_test`, backend `EngagementTest` |
| G | Requests & Approvals inbox; child request status | P: Today → Inbox; C: Me → My requests | `/families/{f}/inbox`, `/child/requests` | `inbox_test`, backend `ChildJourneyTest` |
| H | Encouragement | P: Inbox/child hub → Praise; C: Together → Messages | `…/encouragements`, `/child/encouragements` | `encouragement_test`, backend `EngagementTest` |
| I | Weekly recap | P: Today → Recap | `/families/{f}/recap/weekly` | `recap_test`, backend `FamilyOverviewTest` |
| J | Family planner | P: Today → Planner; C: My Day (events) | `/families/{f}/planner`, `…/events*`, `/child/planner` | `planner_test`, backend `EngagementTest` |
| K | Extra screen-time requests | C: Me → Ask for time; P: Inbox | `/child/screen-time*`, `…/screen-time-requests*` | backend `EngagementTest` |
| L | Notification inbox, preferences, quiet hours | P: Account; C: Me | `/notifications*`, `/child/notifications*`, `…/notification-preferences` | `notifications_test`, backend `NotificationTest` |
| M | Widgets / Android overlay / iOS Live Activity | OS surfaces | `/families/{f}/pulse/surface` | `surface_snapshot_test`; simulator checks |
