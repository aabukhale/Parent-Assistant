# Mamily — Parent Assistant (Flutter)

Flutter client for the Mamily Laravel `/api/v1` backend (`../mamily`, read-only
reference). Feature-first architecture, `flutter_riverpod` for state, `dio` for
HTTP, `flutter_secure_storage` for the Sanctum token.

## Run against a local backend

```bash
flutter pub get
flutter gen-l10n

# 1. Start the backend (in ../mamily) — SQLite by default; do NOT migrate:fresh a real DB
#    php artisan serve        →  http://127.0.0.1:8000

# 2. Run the app pointed at it (compile-time only — no address is baked in)
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1     # iOS sim / desktop
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1      # Android emulator
```

A trailing slash is tolerated. The base URL is never committed. See
[`docs/flutter-integration.md`](docs/flutter-integration.md) §2 for device / tunnel variants.

## Verify

```bash
flutter analyze
flutter test
flutter test --coverage
dart format --output=none --set-exit-if-changed lib $(find test -name '*.dart')
```

## Docs

- [`docs/flutter-integration.md`](docs/flutter-integration.md) — phase-by-phase
  API integration status, endpoint→screen map, provider scopes, mock-removal
  inventory, backend-contract mismatches, and the real-data coverage matrix (§14).
- [`docs/child-mode-security.md`](docs/child-mode-security.md) — why there is no
  secure Child Mode yet, what is connected as parent-managed on-behalf-of-child,
  and the remaining backend + native work.
