# Chocomousse Constitution

Chocomousse is the Flutter app of TravelGenie, an AI trip planner and a USEK final-year project (defence
around June 2027). It runs on Android, iOS and the web, and gets its data from the `pamplemousse` backend,
which has its own constitution.

## Core Principles

### I. Feature-First Structure

- Each feature MUST live in `lib/features/<name>/`, split into `data/` (API calls and models),
  `application/` (Riverpod providers) and `presentation/` (screens and widgets), using only the folders it needs.
- API calls MUST stay in `data/`. Screens MUST get data through providers and MUST NOT use dio directly.
- Code shared by features MUST live in `lib/core/` or, for the theme and routes, `lib/app/`.
- Models MUST be parsed by hand in `data/`, so a changed field shows up in a test or a compile error.
- Code MUST be reusable and cleanly structured: logic or UI needed in more than one place MUST be shared, not
  copied, and each file and widget MUST have one clear job and a name that says what it does.

Rationale: a screen can be tested with a fake repository, and the API can change in one place. No automated
check enforces this yet, so it is covered in review.

### II. Every Feature Is Tested (NON-NEGOTIABLE)

- Every feature MUST ship with unit tests for models, repositories and providers, and widget tests for each
  screen or widget, including its loading, error and empty states.
- A new user journey MUST have a flow test in `test/flows/` through the real router and screens.
- Every test MUST pass. Coverage percentages MUST NOT be used as a gate.
- Tests MUST NOT call the internet; the API is replaced by a fake repository or a fake Dio adapter.
- A visible change MUST be checked in the running app at phone (390 px) and desktop widths, not only by tests.

Rationale: `main` must always be demonstrable, and the backend's state must not make tests flaky.

### III. Zero Lint Findings

- `flutter analyze --fatal-infos` MUST report nothing, using `very_good_analysis`.
- Code MUST pass `dart format --set-exit-if-changed lib test`, at line length 120.
- An exception MUST be listed in `analysis_options.yaml` with its reason, or carry an inline ignore that gives one.

### IV. Design First

- A new screen or a redesign MUST have an approved Figma design before frontend work starts. Approvals are logged
  in the OneDrive project folder.
- Loading, empty and error states of an approved screen MAY be built without their own Figma frame, from the
  screen's layout and the existing tokens. The pull request MUST say so.
- Colours, spacing and radii MUST come from `lib/app/theme/tokens.dart`, which mirrors the Figma variables.
- Every screen MUST work on phones and on wide screens (from `kWideLayoutBreakpoint`).

### V. Never a Blank Screen

- A screen that needs data MUST show its layout with placeholder boxes while loading, not a lone spinner.
- When a request fails, the screen MUST keep that layout and show what went wrong, with a Try again action.
- The error MUST appear at once. Providers MUST NOT retry automatically, because the visitor would see a loading
  state for about 38 seconds.
- A section with no data MUST show the backend's warning, or a short message, and the rest of the screen MUST
  still work.
- The web app MUST show a loading screen until Flutter draws its first frame.

Rationale: free sources fail, and the backend may be down; the app must still look alive and explain itself.

### VI. Backend Only

- The app MUST get its data only from `pamplemousse`, under `/api/v1`, and MUST NOT call third-party APIs or MCP
  servers directly.
- Firebase is used for hosting and, from ADR 0020, for sign-in (Firebase Authentication). Any other direct use of
  Firebase from the app MUST have an ADR first.
- A change that needs a new or different endpoint MUST be agreed with `pamplemousse` in the same delivery.

Rationale: API keys stay on the server, and the app, chatbot and Telegram bot share the same use cases.

### VII. Low Cost First

- The project MUST run at about $0 during development. A paid service, or one requiring a billing card, MUST NOT
  be added without the owner's explicit approval.
- Google Places MUST NOT be used while on hold (ADR 0008).

### VIII. Simplicity

- Prefer the simplest design that meets the current spec; no code for imagined future needs.
- The app uses Riverpod, go_router and dio. A replacement for one of these, or a new framework, MUST have an ADR.
- A new package MUST be justified in its pull request.

## Configuration and Security

- All settings MUST be read through `lib/env.dart` using `Env.get(name, default)`, the single configuration file
  of this repo, and new ones MUST be added to `assets/env/app.env.example`.
- `assets/env/app.env` ships inside the app, so it MUST NOT contain secrets. The only keys allowed in the app are
  a platform-restricted Google Maps key and Firebase's app settings (API key, app id, project id), which Google
  documents as public identifiers protected by authorized domains and app fingerprints.
- Personal data (passport, trips, chat history) MUST NOT be logged.

## Development Workflow

- `main` is protected: every change MUST go through a branch and a pull request, and CI MUST pass.
- The pre-push hook MUST run on every push and MUST NOT be bypassed without the owner's say-so. It runs
  formatting, lint, every test and the web release build.
- A backlog feature MUST have a spec in `specs/`. The owner MUST approve the spec and the plan before
  implementation starts. Bug fixes and small refactors MAY skip the spec. Screens built before this constitution
  need no spec until they change substantially.
- For a feature that needs both repos, the backend spec comes first and the app's spec links to it. The order in
  this repo is spec, Figma approval, plan, code.
- Tests MUST be in the same pull request as the code they cover. Writing them first is encouraged but not required.
- Lasting decisions MUST be recorded as ADRs in `pamplemousse/docs/architecture/adr/`, the shared documentation.
- Documentation about this app's code MUST live in this repo and change in the same pull request as the code.
  Non-code material (Figma, presentations, budget and other studies) stays in the OneDrive project folder.

## Governance

- This constitution takes precedence over other practices. When it conflicts with a spec or a plan, the
  constitution wins until it is amended.
- When principles conflict, the order is: VII Low Cost, then II Tested, then V Never a Blank Screen, then delivery
  speed.
- Only the owner approves amendments, through a pull request stating the reason.
- Versions follow semantic versioning: MAJOR removes or redefines a principle, MINOR adds or expands one, PATCH
  fixes wording.
- Every plan MUST pass the Constitution Check. Any justified violation MUST be recorded in the plan's Complexity
  Tracking table.

**Version**: 1.1.0 | **Ratified**: 2026-11-02 | **Last Amended**: 2026-11-06
