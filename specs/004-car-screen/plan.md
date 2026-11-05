# Implementation Plan: Car rental screen

**Branch**: `004-car-screen` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Status**: Draft, waiting for the owner's approval

## Summary

Add a `cars` feature to the app, built like hotels. It has:
- a list route and a details route under the destination;
- a repository for the two car endpoints, with a longer time limit for the search;
- providers for the places and the search;
- the approved screens from the Figma page "Sprint 2 — Cars" (C1–C7).

The driver's age joins the shared trip settings. No backend change is needed.

## Technical Context

**Language/Version**: Flutter 3.47.0, Dart 3.13.0

**Primary Dependencies**: Riverpod 3, go_router, dio, intl and url_launcher, all already used. No new package

**Storage**: None. The driver's age, like dates and adults, lives in memory for the session

**Testing**: `flutter_test` with a fake repository and the existing fake link opener

**Target Platform**: Web, Android and iOS, at phone and wide widths

**Constraints**: About $0. The app calls no third party except to load car photos and company logos. No automatic retries

## Constitution Check

| Principle | How the plan meets it | Result |
|---|---|---|
| I Feature-First | New `lib/features/cars/` with `data/`, `application/` and `presentation/`. Reuses the trip chips, link opener, photo placeholder and pager from hotels | Pass |
| II Tested | Unit tests for models, repository and providers. Widget tests for every state and both screens, one flow test, and a check at 390 px and desktop | Pass |
| III Zero Lint | `flutter analyze --fatal-infos` and `dart format`, through the pre-push hook | Pass |
| IV Design First | Figma approved and logged on 2026-11-05. The wide layout follows hotels' approved W1, as agreed in the spec | Pass |
| V Never a Blank Screen | The searching state (C5) while waiting. Errors show at once with Try again, and nothing retries by itself | Pass |
| VI Backend Only | Only the two car endpoints. Photos and logos load from the URLs the API gives, and links open in the browser | Pass |
| VII Low Cost | No new package or service | Pass |
| VIII Simplicity | The card, the filter sheet, the pick-up sheet and the details are small separate widgets | Pass |

## Design decisions

1. **Separate feature and repository.** `CarRepository` has two methods:
   - `places(destinationId)`;
   - `search(CarQuery)`, which sends repeated `size`, `company` and `pickUpType` values with `ListFormat.multi`, as hotels does for stay types.
2. **The 60 s search limit (FR-004).** `search` passes `Options(receiveTimeout: 60 s)` on that one request. The shared Dio client keeps 30 s for everything else. If the limit is reached, the message is the existing "The server took too long to answer."
3. **Driver's age in the trip settings.**
   - `TripSettings` gains `driverAge` (default 30) and `setDriverAge`, clamped to 18–99.
   - `TripChips` is not changed. The car screen draws its own chips row (dates, pick-up place, driver, currency), as in C1. It reuses the dates and currency chips from `TripChips` and adds the pick-up and driver chips, which both open the C3 sheet.
4. **Search state.**
   - `CarFilters`: an immutable value. It holds the sort, sizes, gearbox, minimum seats, minimum bags, maximum total, pick-up types, companies and free cancellation, plus `activeCount` for the Filters chip.
   - The pick-up place id (default `centre`), the filters and the page are local to the screen. Each city starts from the defaults, as the spec asks.
   - The page goes back to 1 whenever the trip, place, age or filters change.
   - `carResultsProvider`: an `autoDispose.family` keyed by a `CarQuery` value with equality. The key is the destination, dates, place, age, currency, filters and page.
   - `carPlacesProvider`: an `autoDispose.family` keyed by the destination. It is only read when the C3 sheet opens; if it fails, the sheet offers the centre alone.
   - Both use `noRetry`.
5. **Models.**
   - Parsing throws on a missing `id`, `model`, `price` or `bookingUrl`, or on a bad date, so the error state shows.
   - Nullable fields stay null, and the widgets hide them.
   - The sort, gearbox and pick-up type are enums, sent and read as the API's camelCase names. An unknown pick-up type reads as `other`, so a new value from the source can't break the screen.
6. **Searching state (C5).** While the request runs, the screen shows the trip chips, the 30-second note, an indeterminate progress bar and two placeholder cards. The bar is not a countdown, because the real time varies.
7. **Details route.**
   - `destination/:id/cars/:carId`. Tapping a card passes the car through go_router's `extra`, and the details screen shows it with no request.
   - With no car in `extra` (a reload or a pasted link), the screen sends the traveller back to the list route, which loads from the server's cache (spec clarification 2).
8. **Texts.**
   - **Pick-up types:** Airport terminal, Airport shuttle, Rental centre, Train station, Downtown, Other.
   - **Fuel policies:** "Like for like" reads "return as you found it", and the other known values get short plain names. An unknown value is shown as it is.
   - **Money in its own currency:** the deposit and damage excess use `NumberFormat.simpleCurrency` ("€3,294"). The total uses the trip's currency, as on the hotel screen.
9. **Notes.**
   - The price note uses `pricesFetchedAt` in the device's time ("checked today at 09:40") and says pick-up and return are at 10:00.
   - `warnings` show in the boxed warning note.
   - When `mayHaveMore` is true, a note links to `bookingUrl` of the first car, or to `searchUrl`, which is the same Booking.com search.
   - When there is a `driverNote`, it shows above the list.
10. **Filter sheet (C2).**
    - It edits a copy of the filters, applied only when the button is tapped.
    - Sizes, pick-up types and companies come from `filterOptions`. The first 6 companies show, with "+N more" opening the rest.
    - Seats offer 4+, 5+ and 7+; bags offer 1+, 2+ and 3+.
    - The maximum total is a whole number in the trip's currency and must be above 0.
    - The note says filters cover all the cars of this search.
11. **Pick-up and driver sheet (C3).**
    - It shows the places as choice chips: "City centre", and airports as "Name · CODE".
    - The age field takes whole numbers, shows the young or senior note live, and blocks values outside 18–99.
    - Applying closes the sheet, sets the place on the screen and the age in the trip settings, and reloads the cars.
12. **Overview entry (C7).** A row under the hotels entry. Its subtitle shows the dates, "city centre", the driver's age and the 30-second note. It makes no car request, and the overview's placeholder layout gets a matching box.
13. **Wide layout.** From 900 px, as hotels: the filters sit in a side panel and the cars in two columns. The details screen keeps one column, at most 720 px wide.
14. **Images.** Car photos and company logos use `Image.network` with `webHtmlElementStrategy: WebHtmlElementStrategy.fallback`, as hotel photos do. A failed photo shows the gradient placeholder; a failed logo is hidden and the company name stays.

## Project Structure

```text
specs/004-car-screen/                   spec.md, plan.md
lib/features/cars/
├── data/car_models.dart                CarQuery, CarFilters, CarSort, PickUpPlace, CarOffer, CarResults, FilterOption
├── data/car_repository.dart
├── application/car_providers.dart
└── presentation/
    ├── cars_screen.dart                chips, notes, searching state, list, paging, wide layout
    ├── car_details_screen.dart
    └── widgets/
        ├── car_card.dart
        ├── car_filters_sheet.dart      the sheet and the wide side panel share its form
        ├── pick_up_sheet.dart          place and driver's age (C3)
        ├── cars_entry.dart             overview row (C7)
        └── car_texts.dart              names for pick-up types and fuel policies
lib/features/destination/application/destination_providers.dart   driverAge in TripSettings
lib/features/destination/presentation/overview_screen.dart         add the entry row
lib/app/router.dart                     add the two routes
test/cars/                              models, repository, providers, card, sheets, list and details screens, fakes
test/destination/                       trip settings test for the driver's age
test/flows/cars_flow_test.dart
```

## Build order

1. Driver's age in the trip settings, with tests.
2. Models and repository, including the 60 s limit, with tests.
3. Providers, with tests.
4. Story 1: list route, screen, card, searching state, notes and overview entry, with widget tests for every state.
5. Story 3: details route and screen, with the Booking.com button and the fallback to the list, with tests.
6. Story 2: pick-up and driver sheet, with tests.
7. Story 4: filter sheet, wide side panel and paging, with tests.
8. Flow test. Then run against the real backend at 390 px and desktop: Rome at the centre, Rome at Fiumicino with a 23-year-old driver, a filtered search, a car's details, and Zahlé (SC-004).
9. Update the README and `pamplemousse`'s sprint review.

## Risks

- **Requests from the monthly 530.** Live data needs the local backend. Each new place, date, age or currency costs 1 of the 530 Booking.com requests, and each new city's airports cost 1 more. The SC-004 checks need about 4. Repeat checks reuse the 1-day cache.
- **Photos and logos on the web.** They come from `cdn.rcstatic.com`, not Booking.com's image server. If the fallback in decision 14 doesn't work there, photos show as placeholders on the web only.
- **Fuel policy names.** Only "Like for like" was seen in Rome. Other values show as the source writes them until they are named.
- **Developer wording in warnings.** A missing key shows "Cars are not configured (RAPIDAPI_KEY)", as for hotels.

## Complexity Tracking

No violations.
