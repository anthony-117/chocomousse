# Implementation Plan: Itinerary and My plans screens

**Branch**: `007-itinerary-screens` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Status**: Approved by the owner on 2026-11-06

## Summary

Add an `itinerary` feature on the plan routes of `pamplemousse` spec 008:
- **Build my plan** on Best for you and the overview, sending the trip settings with a new **Pace**;
- **the itinerary** (I1, I2, W4) with the trip card, day chips and a timeline of TripItemRows;
- **Why the match and the cost** (I3), **Change** for the hotel, flight and car (I4);
- **My plans** (I5, W7) with the plan actions (I6), replacing today's empty Plans tab.

Pace is added to the trip settings, Plan your trip (I0) and the profile (P2). No new package.

## Technical Context

**Language/Version**: Flutter 3.47.0, Dart 3.13.0

**Primary Dependencies**: Riverpod 3, go_router, dio, as today. Nothing new.

**Storage**: none on the device. Plans live in the API.

**Testing**: `flutter_test` with a fake plan API (dio adapter, as the other features) and the existing fake
sign-in. Widget tests at 390 px and desktop width.

**Target Platform**: Web and Android.

**Constraints**: no cost. A plan build may call a paid source once (hotels), as Best for you already does; swaps
never do (API R-7).

## Constitution Check

| Principle | How the plan meets it | Result |
|---|---|---|
| I Feature-First | New `lib/features/itinerary/` with `data/`, `application/`, `presentation/`. Pace sits with the preferences in `destination/data/preferences.dart` | Pass |
| II Tested | Unit: models (every field of the contract's plan), repository (each route, each error code), providers. Widget: every state of I0–I6 and W4 (loading, data, empty, error, 404, 409, 422). Flows: Best for you → build → change hotel → My plans → rename → delete; Plan your trip with Pace → build | Pass |
| III Zero Lint | Normal gate | Pass |
| IV Design First | I0–I6 and W4 approved 2026-11-06 | Pass |
| V Never a Blank Screen | Placeholder day cards while building and opening; placeholder cards in I4 and I5; every error with Try again | Pass |
| VI Backend Only | Only `/api/v1/plans` and `/api/v1/me` | Pass |
| VII Low Cost | No new service | Pass |
| VIII Simplicity | One repository, one family of providers, one `PlanActions` notifier for every change | Pass |

## Design decisions

1. **Models** (`itinerary/data/plan_models.dart`), read from the contract's JSON:
   `Plan`, `PlanMatch` (parts and days fit), `PlanTotal`, `PlanDay`, `PlanItem` (kind, start "HH:mm", minutes,
   name, walk, price, ref), `ChosenOffer<T>`, `PlanSummary`, `PlanList`, `Alternatives<T>`. The offers reuse the
   existing `HotelOffer`, `FlightFare` and `CarOffer` models of the hotels, flights and cars features with their match, so
   the cards of I4 are the existing ranked cards. Unknown enum values are kept as "other", never a crash.
2. **Repository** (`itinerary/data/plan_repository.dart`): `build(TripSettings, departureCityId)`, `plan(id)`,
   `list()`, `rename(id, name)`, `setStatus(id, planned)`, `delete(id)`, `alternatives(id, kind)`, `swap(id, kind,
   offerId)`, `removeCar(id)`. Errors become typed failures: `PlanLimitReached` (409 `too-many-plans`), `NoPlaces` (422
   `no-places`), `PlanNotFound` (404), `PlanFieldError` (400, with the field), and the existing network failure.
3. **State** (`itinerary/application/`):
   - `planProvider(id)`: the plan, kept while its screens are open.
   - `plansProvider`: My plans.
   - `PlanActions`: build, swap, remove car, rename, status, delete. Each writes the returned plan into
     `planProvider(id)` and refreshes `plansProvider`, so the itinerary and the list never disagree.
   - Build opens `/plans/new` at once with placeholders; when the API answers, it replaces the address with
     `/plans/{id}`, so Back returns to Best for you and a reload opens the saved plan.
4. **Pace**:
   - `enum Pace { relaxed, balanced, packed }` with "2, 3 or 4 places a day" in `preferences.dart`.
   - `TripSettings.pace` (default balanced) and `setPace`.
   - A three-way choice on Plan your trip (I0) under the sliders, with the frame's line of help.
   - `Profile.pace` and `ProfileForm.pace`, shown on Profile and in Edit profile (P2).
   - The session fills it from the profile once after sign-in, as it does the preferences.
   - Ranked lists don't send it (the API ignores it there).
5. **Routes** (Plans tab):
   - `/plans`: My plans.
   - `/plans/new`: the plan being built.
   - `/plans/:id`: the itinerary, with `?day=n`.
   - `/plans/:id/change/:kind` (`hotel`, `flight`, `car`) on phones. On wide screens Why and Change are dialogs over W4.
6. **Item taps**:
   - A place with an `otm:` id opens place details. The details route knows only OpenTripMap ids, so a Wikidata sight
     opens its `url` when it has one, and nothing otherwise.
   - An event opens its ticket page through `LinkOpener`.
   - The flight and the hotel open their existing details.
7. **Wide layout (W4)**: the trip card and the day list on the left (360 px), the chosen day on the right. My plans is
   a 3-column grid (W7).
8. **Texts**: notes, warnings and reasons are shown as the API writes them. The app's own texts are the frames'.

## Project Structure

```text
lib/features/itinerary/
  data/plan_models.dart · plan_repository.dart
  application/plan_providers.dart · plan_actions.dart
  presentation/
    itinerary_screen.dart          // I1, I2, W4; placeholders while building
    why_view.dart                  // I3 (sheet on phones, dialog on wide)
    change_offer_screen.dart       // I4 for hotel, flight and car
    my_plans_screen.dart           // I5, W7; replaces plans/presentation/plans_screen.dart
    widgets/ trip_card.dart · day_chips.dart · trip_item_row.dart · plan_card.dart · plan_actions_sheet.dart · build_plan_button.dart
lib/features/destination/data/preferences.dart       // + Pace
lib/features/destination/application/destination_providers.dart  // TripSettings.pace
lib/features/ranking/presentation/…                 // Pace on I0; Build my plan on Best for you
lib/features/account/…                              // Pace on Profile, Edit profile and the session fill
lib/app/router.dart                                 // the routes above
test/itinerary/ · test/flows/itinerary_flow_test.dart
```

## Delivery order

1. Pace: preferences, trip settings, I0, profile, session fill. Tests.
2. Models and repository against canned JSON from the contract. Tests.
3. Itinerary (I1, I2, W4) and Why (I3), opened from a saved plan. Tests.
4. Build my plan (Best for you, overview), the placeholder state and the 409, 422 and 400 messages. Tests.
5. Change (I4): hotel, flight, car add, swap and remove. Tests.
6. My plans (I5, W7) and the actions (I6). Tests.
7. Flows, 390 px and desktop checks, `flutter analyze --fatal-infos`, `flutter build web`, then the PR.

## Owner actions before the live check

- Merge `pamplemousse` PR #20 (still open on 2026-11-06) and deploy it with this feature.
- Live checks with a real account: SC-001 to SC-003.

## Risks

- **Wikidata sights can't open details** (decision 6). Fine for now; place details for Wikidata ids would be an API
  change, later.
- **The first build of a city may take longer** when the hotel search isn't stored: the placeholders stay until it
  answers, with the API's own time limit.

## Complexity Tracking

None.
