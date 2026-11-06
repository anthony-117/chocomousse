# chocomousse — TravelGenie app

Flutter app for Android, iOS and web, built from the approved Figma design v0.2 (minimalist, floating icon-only nav on phones, header on desktop).

- Talks only to `pamplemousse` (the .NET backend) — never to third-party APIs or MCP servers directly
- State: Riverpod · Navigation: go_router · HTTP: dio · Logo: flutter_svg
- Hosting: Firebase Hosting (web), Firebase App Distribution (Android test builds)
- Design: OneDrive FYP folder (`04-design/figma/figma-links.md`)
- Docs (architecture, ADRs, process): [`pamplemousse/docs`](https://github.com/anthony-117/pamplemousse/blob/main/docs/README.md)
- Rules: the [constitution](.specify/memory/constitution.md). Feature specs go in `specs/`, written with Spec Kit (`/speckit-specify`, `/speckit-plan`, `/speckit-tasks`, `/speckit-implement`)

## Structure
```
lib/
  main.dart
  env.dart        every environment value the app reads (Env.get(name, default))
  app/            app widget, router (4 tabs + sign-in screens), sign-in guard, theme + design tokens from Figma
  core/           network (dio, ID-token interceptor), shared widgets (logo, page frame, empty state)
  features/
    account/      sign-in (Firebase Auth), Profile tab, edit profile, delete account; seeds trips from the profile
    shell/        app shell: floating nav (phone) / web header (≥ 900 px wide)
    discover/     Discover tab: search entry, trending destinations
    destination/  search, city overview, places, place details (data → application → presentation)
    flights/      flights screen: departure city, fares, links to book (data → application → presentation)
    hotels/       hotels list and details: sort, filters, pages, links to book on Booking.com
    cars/         rental cars: pick-up place and driver's age, sort, filters, pages, car details, Booking.com search
    plans/        My plans tab
    assistant/    Assistant tab: chat with TravelGenie (Gemini on the backend), cards into the screens
    system/       ping API and the backend status card
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
| `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID` | empty | Firebase project used for sign-in (ADR 0020) |
| `FIREBASE_WEB_APP_ID`, `FIREBASE_WEB_API_KEY`, `FIREBASE_AUTH_DOMAIN` | empty | Firebase web app (web builds) |
| `FIREBASE_ANDROID_APP_ID`, `FIREBASE_ANDROID_API_KEY` | empty | Firebase Android app (Android builds) |

The Firebase values are the app's public Firebase configuration (Firebase console → Project settings → Your apps), not secrets: Firebase identifies the app with them, and access is controlled by sign-in and the API. Restrict the API keys to Firebase Auth and your domains / Android app in Google Cloud. With any of them blank the app still runs, and Welcome says which setting is missing.

## Run
Start the backend first (`pamplemousse`, port 5064), then:
```bash
flutter pub get
flutter run -d chrome
flutter test
flutter analyze
flutter build web --release
```

## Deploy (Firebase Hosting)
The web app is hosted on Firebase project `travelgenie-1fdd1`. Install the Firebase CLI and run `firebase login` once, then:
```bash
API_BASE_URL=https://your-api.example.com sh scripts/deploy-web.sh
```
The script requires an https API address, builds with it, deploys, and leaves any local `app.env` as it was. Until the backend is online, use `https://api.invalid`: the app loads but data sections fail.

## Screens
Every screen needs a signed-in traveller with a confirmed email; signed out, the app shows Welcome and returns to the address afterwards.

| Route | Screen | Design |
|---|---|---|
| `/welcome` | Welcome: Continue with Google or email, I already have an account | Sprint 4: A1 |
| `/sign-in` | Sign in with Google or email and password; on wide screens the brand panel beside the form | Sprint 4: A2 / W5 |
| `/sign-up` | Create your account; sends the confirmation email | Sprint 4: A3 |
| `/check-email` | Check your email: I've confirmed, Resend email (once a minute), Sign out | Sprint 4: A4 |
| `/forgot-password` | Reset your password | Sprint 4: A5 |
| `/profile` | Profile: name, email, travel profile, default preferences, Sign out, Delete my account | Sprint 4: P1, P3 |
| `/profile/edit` | Edit profile: name, passport, home currency, home city, default preferences | Sprint 4: P2 |
| `/discover` | Discover: search pill, trending destinations | 02 / W1 |
| `/discover/search` | City search + passport, currency and dates | 03 |
| `/discover/destination/:id` | City overview: weather, currency, visa, safety, holidays, country, attractions, events | 04 / W2 |
| `/discover/destination/:id/places?category=` | Attractions / restaurants with map | 05 / W2 |
| `/discover/destination/:id/flights` | Recent flight prices from a chosen city | Sprint 2: F1–F5 / W1 |
| `/discover/destination/:id/hotels` | Hotels for the trip's dates and adults, with sort, filters and pages | Sprint 2: H1, H2, H4–H7 / W1 |
| `/discover/destination/:id/hotels/:hotelId` | One hotel's details and its Booking.com link | Sprint 2: H3 |
| `/discover/destination/:id/cars` | Rental cars for the trip's dates, a pick-up place (city centre or an airport) and the driver's age, with sort, filters and pages | Sprint 2: C1–C3, C5–C7 |
| `/discover/destination/:id/cars/:carId` | One car from the list, and Booking.com's search for it. Opened without the list (a reload or a shared link), it goes to the list | Sprint 2: C4 |
| `/discover/destination/:id/plan` | Plan your trip: dates, travellers, departure city, total budget and how much six things matter. `?edit=<tab>` returns to that tab | Sprint 3: S1 |
| `/discover/destination/:id/plan/best?tab=hotels\|flights\|cars` | Best for you: one tab ranked by those preferences, with why each offer ranks where it does; on wide screens the form, the list and the reasons side by side | Sprint 3: S2–S6 / W1 |
| `/discover/place/:placeId` | Place details | 13 |
| `/assistant` | Assistant: chat about any city, or the one opened from an overview; answers carry cards into the screens above | 09 / W6 (chat column) |

The map is a lightweight preview (pins around the city centre); Google Maps replaces it once a Maps key is configured.
Sections whose data source has no API key yet show the backend's warning instead of data.

## Releases
Pushing a tag such as `v1.2.0` runs the tests and publishes a web bundle on the GitHub release. That doesn't make it live: [`factory_mousse`](https://github.com/anthony-117/factory_mousse) decides which version runs.

## Git hooks (run once per clone)
```bash
sh scripts/install-hooks.sh
```
This sets `core.hooksPath` to the versioned `.githooks/` folder. The **pre-push** hook runs `dart format`, `flutter analyze --fatal-infos`, every test and the web release build
— every CI step — and **blocks the push if any of them fails**. (Emergency bypass: `git push --no-verify`; CI still runs.)

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
| `test/destination/*_test.dart`, `test/flights/*_test.dart`, `test/hotels/hotel_data_test.dart`, `test/cars/car_data_test.dart`, `test/system/`, `test/core/` | Unit | Models, repository against a fake Dio adapter (URLs, query, parsing), providers, error messages, `Env` |
| `test/destination/` (screens, chips, events), `test/flights/flights_screen_test.dart`, `test/hotels/hotels_screen_test.dart`, `test/cars/cars_screen_test.dart` | Widget | Each screen and widget with a fake repository, incl. loading, error, empty and missing-key states |
| `test/assistant/` | Unit + widget | Models, repository (body, last 20 messages, time-out), chat controller (send, retry, New chat, context), card opener, the screen's states |
| `test/account/` | Unit | Sign-in guard (incl. `from` never leaving the app), ID-token interceptor (renew once, sign out, email not confirmed), profile models and repository, Firebase settings, session (seeding, sign-out) |
| `test/flows/` | Flow (integration) | The real app — router, shell, providers, screens — driven like a user: Discover → overview → places → details, flights, hotels, cars, assistant, search, failures; sign-in screens A1–A5, W5 and profile P1–P3 (`account_flow_test.dart`) |

```bash
flutter test
```
Shared test helpers: `test/helpers.dart` (host a screen, phone size), `test/account/fakes.dart` (fake sign-in and account API; `signedIn()` for every test of the signed-in app) and `test/destination/fakes.dart`, `test/flights/fakes.dart`, `test/hotels/fakes.dart`, `test/cars/fakes.dart` (configurable fake APIs).

## Conventions
- Colours, spacing and radii live in `lib/app/theme/tokens.dart` and mirror the Figma variables; don't hard-code new values in screens.
- Line length 120 (`analysis_options.yaml`); CI fails on unformatted code (`dart format lib test`).
- No frontend code for a screen until its Figma design is approved (approval log in the FYP folder).

## Secrets
No API keys in the app except platform-restricted Google Maps keys and the public Firebase configuration (see Configuration). ID tokens are never logged.
