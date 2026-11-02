# Implementation Plan: Flight screen

**Branch**: `001-flight-screen` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Status**: Approved by the owner on 2026-11-02

## Summary

Add a `flights` feature to the app: a route under the destination, a repository for the existing flights endpoint, providers for the search, and the approved screens (Figma page "Sprint 2 — Flights", F1–F5 and W1). In `pamplemousse`, the missing-marker warning moves from the response to the log.

## Technical Context

**Language/Version**: Flutter 3.47.0, Dart 3.13.0 (app); .NET 10 (one backend change)

**Primary Dependencies**: Riverpod 3, go_router, dio, intl. New: `url_launcher`, because nothing in the app opens links yet (place websites are copied to the clipboard)

**Storage**: None. The departure city lives in memory for the session

**Testing**: `flutter_test` with a fake repository and a fake link opener; xUnit in `pamplemousse`

**Target Platform**: Web, Android and iOS, at phone and wide widths

**Constraints**: About $0; no third-party calls from the app; no automatic retries

## Constitution Check

| Principle | How the plan meets it | Result |
|---|---|---|
| I Feature-First | New `lib/features/flights/` with `data/`, `application/` and `presentation/`. Shared pieces are reused, not copied | Pass |
| II Tested | Unit tests for models, repository and providers; widget tests for every state; one flow test; checked at 390 px and desktop | Pass |
| III Zero Lint | `flutter analyze --fatal-infos` and `dart format` through the pre-push hook | Pass |
| IV Design First | Figma approved 2026-11-02 and logged. Loading and error states follow the layout, and the PR says so | Pass |
| V Never a Blank Screen | Placeholder fare cards while loading; error with Try again above them; no retries | Pass |
| VI Backend Only | Only `/api/v1/destinations/{id}/flights` and the existing city search. Booking links open in the browser, not as API calls | Pass |
| VII Low Cost | `url_launcher` is free; no new service | Pass |
| VIII Simplicity | One new package, justified in the PR. Fare tile, picker and screen are small separate widgets | Pass |

## Design decisions

1. **Separate feature, separate repository.** `FlightRepository` is its own class, so `DestinationRepository` and its fake don't change. The flights feature imports `tripSettingsProvider` and `DestinationSummary` from `destination`, because the trip and cities are shared.
2. **Models skip airline and flight number.** `FlightFare.fromJson` doesn't read them (FR-007), so they can't appear by accident, and a test asserts that. A missing `bookingUrl` or bad date throws while parsing, which shows the error state.
3. **Search state.**
   - `departureCityProvider`: `Notifier<DestinationSummary?>`, kept alive for the session (FR-004).
   - Trip type and direct only: local state in the screen, so each destination starts from the defaults.
   - `flightResultsProvider`: `autoDispose.family` keyed by a `FlightQuery` value with equality. Dates and currency come from `tripSettingsProvider`, as the overview does.
4. **Opening links.** `linkOpenerProvider` in `lib/core/links/link_opener.dart` wraps `url_launcher`, returning `false` on failure. Tests replace it. It's shared because hotels and cars will also need it.
5. **Departure city picker.** A bottom sheet, like the country picker, using the existing `destinationSearchProvider`. Search logic isn't duplicated.
6. **Same-city error.** The API's 400 for the same flight city gets its own message on the screen. `describeApiError` stays as it is for other errors, and the city stays changeable.
7. **Date labels.** An enum `FlightDateMatch` holds the label: none for `exact`, then "Nearby dates", "Same month" and "Different return". An unknown value from the API shows no label rather than failing, but the API's `message` still shows.
8. **Dates and times.** Shown as the API gives them, using their own offset, with `intl`, so they match the airport's local time rather than the device's.
9. **Overview entry.** A row in the overview's main column under the facts (F5), which makes no flight request. It reads the session's departure city for its subtitle. The placeholder layout gets a matching box.

## Project Structure

```text
specs/001-flight-screen/        spec.md, plan.md
lib/core/links/link_opener.dart
lib/features/flights/
├── data/flight_models.dart
├── data/flight_repository.dart
├── application/flight_providers.dart
└── presentation/
    ├── flights_screen.dart
    └── widgets/
        ├── fare_tile.dart
        ├── departure_city_field.dart   (field and picker sheet)
        └── flight_options.dart         (trip type and direct only)
lib/app/router.dart                     add destination/:id/flights
lib/features/destination/presentation/overview_screen.dart   add the entry row
test/flights/                           models, repository, providers, screen and tile tests, fakes
test/flows/flights_flow_test.dart
```

In `pamplemousse`: `TravelpayoutsFlightProvider` logs the missing marker instead of returning it; update its test, the contract, `data-model.md`, the README line and ADR 0010's note. No other API change.

## Build order

1. `pamplemousse`: move the marker warning to the log, on its own branch and PR.
2. Models and repository, with tests.
3. Providers and link opener, with tests.
4. Story 1: route, screen, fare tile, departure city picker and overview entry, with widget tests for every state.
5. Story 2: opening links, with tests.
6. Story 3: trip type and direct only, with tests.
7. Flow test, then run against the real backend at 390 px and desktop for an exact, a non-exact and an empty route (SC-005).
8. Update the README and `pamplemousse`'s sprint review.

## Risks

- **Live data needs the local backend.** Nothing here is deployed, and the live site stays unchanged.
- **Other warnings use developer wording.** A missing token shows "Set TRAVELPAYOUTS_API_TOKEN…", as Sprint 1's providers do for their keys. That won't happen on a configured server, so this plan leaves it. Changing it would touch every provider, so it would be its own small piece of work.

## Complexity Tracking

No violations.
