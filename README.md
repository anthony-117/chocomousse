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
  env.dart        every environment value the app reads (Env.get(name, default))
  app/            app widget, router (4 tabs), theme + design tokens from Figma
  core/           network (dio), shared widgets (logo, page frame, empty state)
  features/
    shell/        app shell: floating nav (phone) / web header (≥ 900 px wide)
    discover/     Discover tab: search entry, trending destinations
    destination/  search, city overview, places, place details (data → application → presentation)
    plans/        My plans tab
    assistant/    Assistant tab
    profile/      Profile tab (shows backend connection status)
    system/       ping API
assets/
  brand/          logo mark (approved v0.3)
  env/            app.env.example (copy to app.env, git-ignored)
  fonts/          Plus Jakarta Sans (SIL OFL, see OFL.txt)
test/             widget and unit tests
```

## Configuration (`env.dart`)
Every environment value is in `lib/env.dart`, read through `Env.get(name, default)`.
Values come from `assets/env/app.env`; copy `assets/env/app.env.example` and adjust. Without the file every value keeps its default.
`app.env` ships inside the app, so it holds settings only — **never secrets**.

| Variable | Default | Purpose |
|---|---|---|
| `API_BASE_URL` | `http://localhost:5064` | pamplemousse API (Android emulator: `http://10.0.2.2:5064`) |
| `DEFAULT_PASSPORT` | `LB` | Passport for visa checks until the traveller picks one |
| `DEFAULT_CURRENCY` | `USD` | Currency for exchange rates until the traveller picks one |

## Run
Start the backend first (`pamplemousse`, port 5064), then:
```bash
flutter pub get
flutter run -d chrome
flutter test
flutter analyze
flutter build web --release
```

## Screens (Sprint 1)
| Route | Screen | Design |
|---|---|---|
| `/discover` | Discover: search pill, trending destinations | 02 / W1 |
| `/discover/search` | City search + passport, currency and dates | 03 |
| `/discover/destination/:id` | City overview: weather, currency, visa, safety, holidays, country, attractions, events | 04 / W2 |
| `/discover/destination/:id/places?category=` | Attractions / restaurants with map | 05 / W2 |
| `/discover/place/:placeId` | Place details | 13 |

The map is a lightweight preview (pins around the city centre); Google Maps replaces it once a Maps key is configured.
Sections whose data source has no API key yet show the backend's warning instead of data.

## Git hooks (run once per clone)
```bash
sh scripts/install-hooks.sh
```
This sets `core.hooksPath` to the versioned `.githooks/` folder. The **pre-push** hook runs `dart format`, `flutter analyze --fatal-infos` and every test
— the same checks as CI — and **blocks the push if any of them fails**. (Emergency bypass: `git push --no-verify`; CI still runs.)

## Linting (like Rust's clippy)
[very_good_analysis](https://pub.dev/packages/very_good_analysis) turns on almost every Dart lint, plus strict casts, inference and raw types.
CI runs `flutter analyze --fatal-infos`, so any finding fails. Deliberate exceptions are listed with a reason in `analysis_options.yaml`.
```bash
dart format lib test          # format (CI fails on unformatted code)
dart fix --apply              # apply automatic lint fixes
flutter analyze --fatal-infos # lint
```

## Tests
Every feature ships with tests, and CI requires **every test to pass**:

| Folder | Kind | What it covers |
|---|---|---|
| `test/destination/*_test.dart`, `test/system/`, `test/core/` | Unit | Models, repository against a fake Dio adapter (URLs, query, parsing), providers, error messages, `Env` |
| `test/destination/` (screens, chips, events) | Widget | Each screen and widget with a fake repository, incl. loading, error, empty and missing-key states |
| `test/flows/` | Flow (integration) | The real app — router, shell, providers, screens — driven like a user: Discover → overview → places → details, search, failures |

```bash
flutter test
```
Shared test helpers: `test/helpers.dart` (host a screen, phone size) and `test/destination/fakes.dart` (configurable fake API).

## Conventions
- Colours, spacing and radii live in `lib/app/theme/tokens.dart` and mirror the Figma variables; don't hard-code new values in screens.
- Line length 120 (`analysis_options.yaml`); CI fails on unformatted code (`dart format lib test`).
- No frontend code for a screen until its Figma design is approved (approval log in the FYP folder).

## Secrets
No API keys in the app except platform-restricted Google Maps keys.
