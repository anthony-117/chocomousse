# Implementation Plan: Weighted search screens

**Branch**: `005-weighted-search-screen` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Status**: Draft, waiting for the owner's approval

## Summary

Add a `ranking` feature to the app with:
- two routes under the destination: "Plan your trip" (S1) and "Best for you" (S2, S4–S6), plus the "Why" sheet (S3) and the wide layout (W1);
- a repository that asks the existing hotel, flight and car endpoints for `sort=match` with the preferences;
- providers that load only the open tab.

The preferences and the total budget join the shared trip settings. The existing hotel, flight and car code isn't changed, apart from reusing its parsers, cards' pieces and details routes. No backend change is needed.

## Technical Context

**Language/Version**: Flutter 3.47.0, Dart 3.13.0

**Primary Dependencies**: Riverpod 3, go_router, dio, intl and url_launcher, all already used. No new package

**Storage**: None. Preferences, like dates and adults, live in memory for the session

**Testing**: `flutter_test` with a fake repository and the existing fake link opener

**Target Platform**: Web, Android and iOS, at phone and wide widths

**Constraints**: About $0. The ranked lists reuse the backend's saved searches, so changing a preference costs no paid request. No automatic retries

## Constitution Check

| Principle | How the plan meets it | Result |
|---|---|---|
| I Feature-First | New `lib/features/ranking/` with `data/`, `application/` and `presentation/`. It reads the other features' models; they don't read it | Pass |
| II Tested | Unit tests for models, repository, providers and trip settings. Widget tests for every state of both screens and the sheet, one flow test, and a check at 390 px and desktop | Pass |
| III Zero Lint | `flutter analyze --fatal-infos` and `dart format`, through the pre-push hook | Pass |
| IV Design First | Figma page "Sprint 3 — Weighted search" approved and logged on 2026-11-05; its note now says Low sends 10 | Pass |
| V Never a Blank Screen | Placeholder cards while loading (the car tab keeps its searching state). Errors show at once with Try again, and nothing retries by itself | Pass |
| VI Backend Only | Only the three existing list endpoints. Links open in the browser | Pass |
| VII Low Cost | Only the open tab loads, and a tab's result is reused while its values don't change | Pass |
| VIII Simplicity | One generic ranked list, one card shell and one "Why" view shared by the three kinds | Pass |

## Design decisions

1. **Preferences in the trip settings.**
   - `Level` enum: `low(10)`, `medium(50)`, `high(90)`, with labels.
   - `Preferences`: an immutable value with the six levels (all Medium by default) and an optional `tripBudget`, with equality.
   - `TripSettings` gains `preferences`, and the notifier gains `setPreferences`.
   - `Preferences.toQuery()` gives the seven query parameters, leaving `tripBudget` out when empty.
2. **A separate ranking repository.** `RankingRepository` has three methods: `hotels(RankedQuery)`, `flights(RankedQuery, originId)` and `cars(RankedQuery)`.
   - Each calls the existing endpoint with the trip's values, `sort=match` and the preferences.
   - Cars keep the 60 s limit, set the same way as on the car screen (receive and connect timeout).
   - Hotels and cars ask for page 1 only.
   - Flights use the flight screen's round-trip and direct-only defaults.
   - The existing repositories and their query records are not changed. Adding a field to those records would touch every caller for no gain.
3. **Parsing.** Each response is parsed twice:
   - once by the existing `HotelResults`, `FlightResults` or `CarResults` parser, so offers stay the same types as elsewhere;
   - once for the new fields: each item's `match`, plus `weights`, `tripBudget` and `rankingNote`. Matches are joined to offers by `id`.
   - The result is `RankedList<T>` with `results`, a `List<Ranked<T>>` (offer and optional `Match`), `rankingNote` and `tripBudget`.
   - `Match` and `MatchPart` throw on a missing `percent`, `reason` or `criterion`, so a broken response shows the error state. A missing `match` is allowed (spec edge case).
4. **Providers.**
   - Three `autoDispose.family` providers keyed by a `RankedQuery` record: destination, dates, adults, currency, driver's age and preferences. The flights provider also takes the departure city id.
   - All use `noRetry`.
   - "Only the open tab loads" (FR-006) follows from watching only the open tab's provider.
   - "Reuse when returning" uses `ref.keepAlive()` for the life of the "Best for you" route, released when it closes. Returning to a tab with the same values shows its result at once.
5. **Routes.**
   - `destination/:id/plan` is S1.
   - `destination/:id/plan/best?tab=hotels|flights|cars` is "Best for you". The tab is in the link (FR-002), and an unknown tab reads as hotels.
   - Edit pushes S1 with the current tab, so "Find my best plans" returns to it.
6. **S1, the form.**
   - It holds a draft of the preferences and budget, written to the trip settings only by "Find my best plans".
   - Dates and travellers use the same pickers as the trip chips.
   - "Flying from" reuses `DepartureCityField` and `departureCityProvider`.
   - The budget field takes whole numbers in the trip's currency and must be above 0 when filled.
   - Each slider is a `Slider` with `divisions: 2` (Low, Medium, High) and the level label on the right, as the MeasureRow and slider rows in the design.
7. **"Best for you" (S2, S4–S6).**
   - **Header:** "Best for you", "Ranked by what matters to you", the three tab chips, and the one-line preference summary with Edit.
   - **Notes per tab:**
     - Hotels: count, source, dates and when checked, and "Tap a match to see why".
     - Flights: ranked on budget and comfort only, and recent prices from Aviasales, not live.
     - Cars: ranked on budget and comfort only, at the city centre, for the trip's driver, from Booking.com.
   - **Warnings** (the API's, including the places-near-hotels one) show in the boxed warning note (S5).
   - **The over-budget note** shows under the list when any offer is over.
   - **Cars tab:** a "See all cars" link at the end opens the existing car list.
8. **Cards.**
   - One `RankedCard` shell: the kind line, the match badge (green, or grey when over budget), the title, the details line, the reason (accent colour, or the warning colour when over budget) and the price.
   - Hotels, flights and cars each have a small function that fills it from their offer.
   - Tapping a card opens the "Why" sheet on phones, and selects it on wide screens.
9. **"Why" (S3).**
   - A modal sheet on phones and a side panel on wide screens, built by one widget.
   - **Rows:** one per part, in the API's order. Each has the criterion name ("Culture & history"), the level of its weight (10, 50 or 90 read as Low, Medium or High; other values show the number), the percentage, a bar, and the detail.
   - **Unknown parts:** the detail reads "Not known, counted as average".
   - **Foot:** the averaging note and the open button.
     - "Open hotel" goes to the existing hotel details route.
     - "Open car" goes to the car details route with the car in `extra`.
     - "Open flight" opens `bookingUrl` with the existing link opener.
10. **Flights with no departure city.** The Flights tab shows `DepartureCityField` instead of a list, and loads once a city is chosen.
11. **Wide layout (W1).**
    - From 900 px, three columns: S1's form (no button), the list, and the "Why" panel for the selected offer (the first by default; the selection is outlined).
    - Form changes write to the trip settings after 500 ms without another change, which reloads the open tab.
    - The note under the form says the ranking updates as sliders move and no new search runs.
12. **Overview entry.** A "Plan your trip" row under the cars entry, showing the preference summary and "Find my best plans". It makes no request, and the overview's placeholder layout gets a matching box.
13. **Plans tab.** The empty state's text becomes "Open a destination and choose Plan your trip to rank hotels, flights and cars. Saved plans and itineraries arrive in Sprint 4."

## Project Structure

```text
specs/005-weighted-search-screen/            spec.md, plan.md
lib/features/ranking/
├── data/ranking_models.dart                 Level, Preferences, Match, MatchPart, Ranked, RankedList, RankedQuery
├── data/ranking_repository.dart
├── application/ranking_providers.dart
└── presentation/
    ├── plan_trip_screen.dart                S1
    ├── best_for_you_screen.dart             S2, S4–S6, W1
    └── widgets/
        ├── preferences_form.dart            the sliders and budget, shared by S1 and W1
        ├── ranked_card.dart                 the shell and the hotel, flight and car fillers
        ├── why_view.dart                    S3 sheet and W1 panel
        ├── measure_row.dart                 one part, as the Figma component
        └── plan_entry.dart                  overview row
lib/features/destination/application/destination_providers.dart   preferences in TripSettings
lib/features/destination/presentation/overview_screen.dart         add the entry row
lib/features/plans/presentation/plans_screen.dart                  new empty-state text
lib/app/router.dart                          add the two routes
test/ranking/                                models, repository, providers, card, why view, both screens, fakes
test/destination/                            trip settings test for preferences
test/flows/ranking_flow_test.dart
```

## Build order

1. Preferences in the trip settings, with tests.
2. Models, parsing and repository (the query parameters and the 60 s car limit), with tests.
3. Providers, with tests.
4. Story 1: S1, "Best for you" with the Hotels tab, the card, the notes and the overview entry, with widget tests for every state.
5. Story 2: the "Why" sheet and its three open buttons, with tests.
6. Story 3: the Flights and Cars tabs, with the departure-city prompt and "See all cars", with tests.
7. Story 4: over-budget badge, reason and note, with tests.
8. Story 5: the wide layout with the debounced reload and the selection, with tests.
9. Flow test. Then run against the real backend at 390 px and desktop (SC-005), and check the backend log for no paid request when a preference changes (SC-004).
10. Update the README and `pamplemousse`'s sprint 3 review.

## Risks

- **Requests from the monthly 530.** A new city or new dates cost 1 hotel request and 1 car request. The live check plans Rome with dates already searched where possible, so about 2.
- **The first ranked hotel search for a city** counts places near each hotel, so it takes about 20 s, once a month per city. The placeholders cover it. This is longer than the hotel screen's first search, and the car tab's searching state is the only one that says how long to wait.
- **The car search may not finish in time.** On 5 Nov the backend sometimes didn't finish reading Booking.com's answer within its limit. The car tab then shows its error with Try again, as the car screen does.

## Complexity Tracking

No violations.
