# Implementation Plan: Hotel screen

**Branch**: `002-hotel-screen` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Status**: Approved by the owner on 2026-11-04

## Summary

Add a `hotels` feature to the app: a list route and a details route under the destination, a repository for the two hotel endpoints, providers for the search, and the approved screens (Figma page "Sprint 2 — Hotels", H1–H7 and W1). Adults join the shared trip settings. In `pamplemousse`, the search response gains `totalPages`, on the `002-hotels` branch before it is pushed.

## Technical Context

**Language/Version**: Flutter 3.47.0, Dart 3.13.0 (app); .NET 10 (one backend change)

**Primary Dependencies**: Riverpod 3, go_router, dio, intl, url_launcher (already added for flights). No new package

**Storage**: None. Adults, like dates and currency, live in memory for the session

**Testing**: `flutter_test` with a fake repository and the existing fake link opener; xUnit in `pamplemousse`

**Target Platform**: Web, Android and iOS, at phone and wide widths

**Constraints**: About $0; no third-party calls from the app except loading Booking.com photos; no automatic retries

## Constitution Check

| Principle | How the plan meets it | Result |
|---|---|---|
| I Feature-First | New `lib/features/hotels/` with `data/`, `application/` and `presentation/`. Trip chips, link opener and photo placeholder are reused | Pass |
| II Tested | Unit tests for models, repository and providers; widget tests for every state and both screens; one flow test; checked at 390 px and desktop | Pass |
| III Zero Lint | `flutter analyze --fatal-infos` and `dart format` through the pre-push hook | Pass |
| IV Design First | Figma approved 2026-11-04 and logged. Loading and error states follow the layout, and the PR says so | Pass |
| V Never a Blank Screen | Placeholder cards while loading; error with Try again above them; no retries | Pass |
| VI Backend Only | Only the two hotel endpoints. Photos load from the URLs the API gives; links open in the browser | Pass |
| VII Low Cost | No new package or service | Pass |
| VIII Simplicity | Card, filter sheet, adults sheet and details are small separate widgets | Pass |

## Design decisions

1. **Separate feature, separate repository.** `HotelRepository` has `search(HotelQuery)` and `details(HotelDetailsQuery)`. The feature imports `tripSettingsProvider`, `TripChips` and `kPhotoGradient` from `destination`, as flights does.
2. **Adults in the trip settings.** `TripSettings` gains `adults` (default 2) and `setAdults`, clamped to 1–8. `TripChips` gets `showAdults` (off by default), so the overview and search screens don't change; the hotel screen turns it on and hides the passport. The chip opens a small sheet with − and + buttons. Flights ignore adults.
3. **Search state.**
   - `HotelFilters`: an immutable value with sort, minimum stars, minimum review, price range, stay types and free cancellation, and `activeCount` for the Filters button. Local to the screen, so each destination starts from the defaults.
   - The page is local to the screen and resets to 1 whenever the trip settings or filters change.
   - `hotelResultsProvider`: `autoDispose.family` keyed by a `HotelQuery` value with equality (destination, dates, adults, currency, filters, page).
   - `hotelDetailsProvider`: `autoDispose.family` keyed by `HotelDetailsQuery` (hotel id, dates, adults, currency).
4. **Models.** Parsing throws on a missing `id`, `name` or list `price`, or a bad date, so the error state shows. Nullable fields stay null; the widgets hide them. The sort is an enum sent as the API's names.
5. **Routes.** `destination/:id/hotels` and `destination/:id/hotels/:hotelId`. Opening a hotel from the list pushes the details route; a web link to it uses the current trip settings (spec story 2, scenario 6).
6. **Filter sheet.** Edits a copy of the filters, applied only on "Show hotels", so the list doesn't reload on every tap. The price fields accept whole numbers in the trip's currency and block a minimum above the maximum.
7. **Notes.** The price note uses `pricesFetchedAt` in the device's time ("checked today at 09:40"). `warnings` show in the boxed warning note. A `sourceName` note appears when it differs from the destination. `filtersCheckedOn` shows only when a stay-type or free-cancellation filter is on.
8. **Photos.** `Image.network` with the gradient placeholder on error, as places do. On the web, Booking.com's image server may not allow cross-origin reads; the image uses `webHtmlElementStrategy: WebHtmlElementStrategy.fallback`, which shows it as a plain `<img>` when that happens. Checked in the running app (SC-004).
9. **Languages.** A small map from the codes seen in live data to English names; anything else is shown as the code.
10. **Overview entry.** A row under the flights entry (H7) that makes no hotel request. Its subtitle shows the dates and adults; the placeholder layout gets a matching box.
11. **Wide layout.** At the app's wide breakpoint (900 px, as flights) and above, filters sit in a side panel and hotels in two columns (W1); below that, the sheet and one column.

## Project Structure

```text
specs/002-hotel-screen/                 spec.md, plan.md
lib/features/hotels/
├── data/hotel_models.dart              HotelQuery, HotelFilters, HotelSort, HotelOffer, HotelResults, HotelDetails
├── data/hotel_repository.dart
├── application/hotel_providers.dart
└── presentation/
    ├── hotels_screen.dart              list, notes, paging, wide layout
    ├── hotel_details_screen.dart
    └── widgets/
        ├── hotel_card.dart
        ├── hotel_filters_sheet.dart    sheet and the wide side panel share its form
        ├── hotels_entry.dart           overview row
        └── language_names.dart
lib/features/destination/application/destination_providers.dart   adults in TripSettings
lib/features/destination/presentation/widgets/trip_chips.dart      adults chip and sheet
lib/features/destination/presentation/overview_screen.dart         add the entry row
lib/app/router.dart                     add the two routes
test/hotels/                            models, repository, providers, card, sheet, list and details screens, fakes
test/destination/                       trip settings and chips tests for adults
test/flows/hotels_flow_test.dart
```

In `pamplemousse` (`002-hotels` branch): `SearchHotelsResponse` and its view model gain `TotalPages` (the source's page count, at least the requested page), with handler and endpoint tests, and the contract updated. No other API change.

## Build order

1. `pamplemousse`: add `totalPages`, then push `002-hotels` with the rest of the backend.
2. Adults in the trip settings and chips, with tests.
3. Models and repository, with tests.
4. Providers, with tests.
5. Story 1: list route, screen, card, notes and overview entry, with widget tests for every state.
6. Story 2: details route and screen, booking link, with tests.
7. Story 3: filter sheet and wide side panel, with tests.
8. Story 4: paging, with tests.
9. Flow test, then run against the real backend at 390 px and desktop for Rome, Zahlé, a filtered search and a hotel's details (SC-004).
10. Update the README and `pamplemousse`'s sprint review.

## Risks

- **Live data needs the local backend**, and each new search uses 1–2 of the 530 monthly Booking.com requests. Repeat checks reuse the 12-hour cache.
- **Photos on the web.** If the fallback in decision 8 doesn't work, photos show as placeholders on the web only; the fix (serving them through the API) would be its own change.
- **Stay type names.** If live data uses other names, the choices follow the data.
- **Developer wording in warnings.** A missing key shows "Hotels are not configured (RAPIDAPI_KEY)", as other providers do. Same open point as flights.

## Complexity Tracking

No violations.
