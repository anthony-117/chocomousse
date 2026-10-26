# chocomousse — TravelGenie app

Flutter app for Android, iOS and web, built from the approved Figma design v0.2 (minimalist, floating icon-only nav on phones, header on desktop).

- Talks only to `pamplemousse` (the .NET backend) — never to third-party APIs or MCP servers directly
- State: Riverpod · Navigation: go_router · HTTP: dio · Logo: flutter_svg
- Hosting: Firebase Hosting (web), Firebase App Distribution (Android test builds)
- Design and docs: OneDrive FYP folder (`04-design/figma/figma-links.md`)

## Structure
```
lib/
  main.dart
  app/            app widget, router (4 tabs), theme + design tokens from Figma
  core/           network (dio), shared widgets (logo, page frame, empty state)
  features/
    shell/        app shell: floating nav (phone) / web header (≥ 900 px wide)
    discover/     Discover tab
    plans/        My plans tab
    assistant/    Assistant tab
    profile/      Profile tab (shows backend connection status)
    system/       ping API
assets/
  brand/          logo mark (approved v0.3)
  fonts/          Plus Jakarta Sans (SIL OFL, see OFL.txt)
test/             widget and unit tests
```

## Run
Start the backend first (`pamplemousse`, port 5064), then:
```bash
flutter pub get
flutter run -d chrome
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5064
flutter test
flutter analyze
flutter build web --release
```
Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:5064`.

## Conventions
- Colours, spacing and radii live in `lib/app/theme/tokens.dart` and mirror the Figma variables; don't hard-code new values in screens.
- Line length 120 (`analysis_options.yaml`); CI fails on unformatted code (`dart format lib test`).
- No frontend code for a screen until its Figma design is approved (approval log in the FYP folder).

## Secrets
No API keys in the app except platform-restricted Google Maps keys.
