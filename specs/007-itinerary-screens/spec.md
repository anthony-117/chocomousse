# Feature Specification: Itinerary and My plans screens

**Feature Branch**: `007-itinerary-screens`

**Created**: 2026-11-06

**Status**: Approved by the owner on 2026-11-06. Design: Figma page "Sprint 4 — Accounts & itinerary", I0–I6 and W4, approved 2026-11-06

**Input**: User description: "TG-10: As Fares, I want a complete day-by-day plan built from my preferences, so I can see my whole trip, change the hotel, flight or car, and keep my plans." The API is built in `pamplemousse` on `008-itinerary` (PR #20): [spec](https://github.com/anthony-117/pamplemousse/blob/008-itinerary/specs/008-itinerary/spec.md), [contract](https://github.com/anthony-117/pamplemousse/blob/008-itinerary/specs/008-itinerary/contracts/itinerary-api.md).

The rules are the API spec's (FR-001 to FR-018, Edge Cases). The API builds the days, the total and the match; the app
only shows them and sends the traveller's choices. This spec says how the app does that.

## Clarifications

### Session 2026-11-06

Confirmed by the owner with the spec on 2026-11-06.

- Q: Where does a plan start? → A: A "Build my plan" button at the bottom of Best for you (on each of its tabs) and on the overview's Plan your trip row (Figma note under I1). It sends the trip settings as they are: destination, dates, adults, currency, departure city, the six preferences, pace and trip budget.
- Q: Where is Pace set? → A: On Plan your trip (I0), below the six sliders, and in Edit profile (P2) under Default preferences. It is part of the trip settings, filled once from the profile after sign-in, like the preferences. It changes the itinerary only, never the rankings.
- Q: What shows while the plan is built? → A: The itinerary screen at once, with placeholder day cards, as Best for you does (S2). It takes a few seconds when the searches are stored, longer when a source is asked.
- Q: What does "Change" do? → A: It opens the ranked list kept with the plan (I4): up to 20 hotels, flights or cars with their match, the one in the plan marked "In your plan". Choosing one swaps it and returns to the itinerary with the days rebuilt. Nothing new is searched, except the first time a car list opens, which runs the car search once.
- Q: The car? → A: A plan has no car at first. "Add" opens the ranked cars; the car row then shows Change and Remove.
- Q: The day's items? → A: The times are the destination's local times, as the API gives them. A sight, park, restaurant or nightlife place opens its place details; an event opens its ticket page; the flight and hotel open their details as in their lists.
- Q: My plans? → A: The Plans tab becomes My plans (I5): every saved plan, newest change first, with All, Drafts and Planned chips and "3 of 50 plans". The ⋯ of a plan opens its actions (I6): Rename, Mark as planned (or Mark as draft), Delete plan.
- Q: The plan dock of design v0.2? → A: Not in the Sprint 4 frames, so not in this feature.
- Q: The assistant side panel of W4? → A: It comes with TG-11. This feature shows W4 without it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build and read my plan (Priority: P1)

Fares has ranked Rome's hotels and flights in Best for you. They choose Build my plan and see five days, each with
its places, meals and walking distance, the trip's total and a 91 % match they can explain.

**Independent Test**: From Best for you, build a plan; check every day, the trip card, the notes, and Why 91 %; reopen
the app and find the plan in My plans.

**Acceptance Scenarios**:

1. **Given** Best for you, **When** Fares chooses Build my plan, **Then** the itinerary opens with placeholder days, then shows the plan (I1): name, dates, adults, "Draft, saved", the match, the trip card (flight, hotel, car) and the day chips.
2. **Given** a plan, **When** Fares picks a day chip, **Then** that day shows its title, date, weather when known, walking distance and its items in time order (TripItemRow).
3. **Given** the first day, **Then** the arrival and the plan's notes show above its items (I2), and any warning shows with them.
4. **Given** the trip card, **When** Fares chooses "Why 91%?", **Then** I3 shows the parts (hotel, flight, car, days), how well the days fit each interest, the cost lines, what isn't included, and how far over or under the budget it is.
5. **Given** a plan with no departure city, **Then** the flight row says to choose one, and the API's note explains the shorter first and last days.
6. **Given** pace Relaxed, Balanced or Packed on Plan your trip, **Then** the built plan uses it, and Pace shows in the trip's preferences summary.

### User Story 2 - Change the hotel, flight or car (Priority: P2)

**Acceptance Scenarios**:

1. **Given** the trip card, **When** Fares chooses Change on the hotel, **Then** the kept hotels show ranked with their match and reason (I4), the current one marked In your plan.
2. **Given** that list, **When** Fares picks another hotel, **Then** the itinerary shows it with the days, total and match rebuilt.
3. **Given** a plan with no car, **When** Fares chooses Add, **Then** the ranked cars show (placeholders while the first search runs); picking one adds it to the total. **When** they choose Remove, **Then** the car is gone from the total.
4. **Given** the swap fails, **Then** the list shows the error with Try again, and the plan is unchanged.
5. **Given** the API's warning that the places couldn't be loaded, **Then** it shows on the itinerary: the days were kept.

### User Story 3 - My plans (Priority: P2)

**Acceptance Scenarios**:

1. **Given** the Plans tab, **Then** My plans (I5) lists every plan, newest change first: picture, status, name, dates, adults, total, match.
2. **Given** the chips, **When** Fares chooses Drafts or Planned, **Then** only those plans show.
3. **Given** a plan's ⋯, **When** Fares chooses Rename, **Then** a dialog takes 1 to 60 characters and the list shows the new name.
4. **Given** a draft, **When** Fares chooses Mark as planned, **Then** it shows as Planned (and the reverse for a planned one).
5. **Given** Delete plan, **When** Fares confirms, **Then** the plan is gone.
6. **Given** no plans, **Then** the empty state says how to build one, with a link to Discover.
7. **Given** 50 plans, **When** Fares builds another, **Then** "You can keep up to 50 plans. Delete one to make room." shows with a link to My plans.

### Edge Cases

- **No places at the destination** (API 422 `no-places`): "No places could be found for Rome right now, so no plan can be made. Try again later." with Back.
- **A refused value** (API 400, e.g. dates in the past): the message names the setting, with a link to Plan your trip.
- **No connection or a server error** while building, opening or swapping: the screen's error with Try again; nothing retries by itself.
- **A plan opened from a link that isn't the traveller's** (API 404): "This plan doesn't exist or isn't yours." with a link to My plans.
- **Unpriced items or other currencies**: the cost says what isn't included, as the API counts it.
- **Old plans**: a plan opens as saved, with the times its prices were checked; nothing is searched again.
- **Phone and wide screens**: every screen works at 390 px; from `kWideLayoutBreakpoint` the itinerary is W4 (day list left, chosen day right), I3 and I4 open as dialogs, and My plans is a 3-column grid.

## Requirements *(mandatory)*

- **FR-001**: Build my plan MUST send `POST /api/v1/plans` with the trip settings, pace included, and open the returned plan.
- **FR-002**: The itinerary MUST show what the API returns: the trip card, every day and item, the total, the match with its parts, the notes and the warnings. The app MUST NOT compute days, totals or matches itself.
- **FR-003**: Change and Add MUST list `GET /plans/{id}/alternatives/{kind}` and swap with `PUT /plans/{id}/{kind}`; Remove MUST call `DELETE /plans/{id}/car`.
- **FR-004**: My plans MUST use `GET /plans`, rename and status `PATCH /plans/{id}`, and delete `DELETE /plans/{id}` after a confirmation.
- **FR-005**: Pace MUST be on Plan your trip and Edit profile, saved with the profile (`PUT /api/v1/me`), and fill the trip settings once after sign-in.
- **FR-006**: The screens MUST follow the approved frames I0–I6 and W4 (W7 for My plans on the web).
- **FR-007**: Every list and plan MUST show placeholders while loading and its error with Try again (constitution V).
- **FR-008**: Plan names, preferences and prices MUST NOT be logged.

## Success Criteria *(mandatory)*

- **SC-001**: From Best for you, a plan shows in under 5 seconds when the searches are stored (live check against the API of `008-itinerary`).
- **SC-002**: A saved plan opens from My plans in under 1 second, on the web and Android.
- **SC-003**: A plan built on the web shows in My plans on Android after signing in there.
- **SC-004**: Every screen of this feature works at 390 px and on the web, with no overflow.

## Assumptions

- PR #20 (`pamplemousse` `008-itinerary`) is merged and deployed with this feature.
- The owner has finished the Firebase setup and checks of spec 006 (done, 2026-11-06).
- The sample data in the frames is illustrative; the app shows the API's wording for notes, warnings and reasons.
