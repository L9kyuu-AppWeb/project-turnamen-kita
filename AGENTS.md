# Turnamen Kita

Flutter app for managing football tournaments (round-robin leagues + group stages + knockout). Pub name is `project_liga_standing` (display title "Turnamen Kita"). Single-page tournament lifecycle: setup -> team entry -> round-robin schedule -> standings -> knockout -> PDF/share export. Data in local SQLite (`liga_standing.db`).

## Dev environment

- Flutter + Dart SDK `^3.10.7` (see `pubspec.yaml`). Java 17 for Android builds.
- Install deps: `flutter pub get`
- Desktop (Linux/Windows/macOS) uses `sqflite_common_ffi` — initialized in `lib/main.dart` via `sqfliteFfiInit()`. No extra env vars.
- Android release signing reads `android/key.properties` (`keyAlias`, `keyPassword`, `storePassword`, `storeFile`). Debug builds work without it.

## Build, run, analyze

- Run (device/emulator): `flutter run`
- Analyze: `flutter analyze` (config in `analysis_options.yaml`, includes `package:flutter_lints/flutter.yaml`, excludes `build/`, `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`)
- Test: `flutter test` (only `test/widget_test.dart` exists; add more under `test/`)
- Build APK: `flutter build apk --release` (requires `android/key.properties` or the `release` signing block falls back to unsigned)
- Regenerate launcher icon: `dart run flutter_launcher_icons` (source `assets/icon.png`)

## Project layout

- `lib/main.dart` — entry, `SplashScreen`, `LigaStandingApp` (Material 3, light/dark `ColorScheme.fromSeed`)
- `lib/models/` — `league_config.dart`, `group_model.dart`, `team_model.dart`, `match_model.dart`, `standing_entry.dart`, `knockout_match.dart` (each has `toMap`/`fromMap`/`copyWith`)
- `lib/database/database_helper.dart` — singleton `DatabaseHelper.instance`, schema v2, all CRUD + `getStandings` (raw SQL), knockout helpers (`getKnockoutStatus`, `createKnockoutFromGroups`, `advanceWinnerToFinal`)
- `lib/logic/scheduler.dart` — `Scheduler.generateRoundRobin` (Circle Method, BYE sentinel `-1` for odd teams, doubles fixtures when `isHomeAway`)
- `lib/services/export_service.dart` — `ExportService.instance` (PDF via `pdf`, share via `share_plus`, clipboard copy for WhatsApp)
- `lib/screens/` — `home_screen.dart`, `setup_screen.dart`, `team_entry_screen.dart`, `main_screen.dart` (3-tab: matches/standings/knockout), `knockout_screen.dart`, `league_list_screen.dart`, `score_input_dialog.dart`
- `assets/icon.png` — app/launcher icon

## Conventions

- Naming: files `snake_case`, classes `PascalCase`, DB columns `snake_case` (`pts_win`, `is_home_away`, `number_of_groups`), model fields `camelCase` (`ptsWin`, `isHomeAway`).
- DB: tables `leagues`, `groups`, `teams`, `matches`, `knockout_matches`; all cross-table queries use `JOIN groups` filtered by `league_id`.
- Error handling: `try/catch` at screen level with `SnackBar(content: Text('Error: $e'))`; DB methods throw `Exception('...')` with Indonesian messages.
- UI text is Indonesian; keep new strings in Indonesian.
- Theme: green seed (`0xFF1B5E20` light / `0xFF4CAF50` dark), `useMaterial3: true`, rounded `InputDecoration`/`CardTheme`.

## Pitfalls

- Do not hand-edit generated/build dirs: `build/`, `.dart_tool/`, `android/.kotlin/`, `.widget_preview/` (all gitignored).
- `android/app/build.gradle.kts` must not add `kotlin-android` plugin (comment in file) — Flutter plugin handles it; `kotlin { jvmTarget = JVM_17 }` is required.
- Resetting scores (`resetMatchesByGroup` / `resetMatchesByLeague`) also deletes `knockout_matches` for that league — bracket becomes invalid by design.
- Knockout creation only supports 2 or 4 qualifiers (1 group top-2, or 2 groups top-2 each); tied `points|GD|GF` for position 2 blocks creation.
- `assets/icon.png` must exist or `flutter run` / icon generation fails.
