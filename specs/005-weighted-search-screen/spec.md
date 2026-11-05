# Feature Specification: Weighted search screens

**Feature Branch**: `005-weighted-search-screen`

**Created**: 2026-11-05

**Status**: Draft, waiting for the owner's approval. Design: Figma page "Sprint 3 — Weighted search", S1–S6 and W1, approved 2026-11-05

**Input**: User description: "TG-09: As Fares, I want to weight budget, culture, food and style and get ranked options." The API is merged in `pamplemousse`: [spec](https://github.com/anthony-117/pamplemousse/blob/main/specs/007-weighted-search/spec.md) and [contract](https://github.com/anthony-117/pamplemousse/blob/main/specs/007-weighted-search/contracts/weighted-search-api.md).

## Clarifications

### Session 2026-11-05

Proposed with this draft; confirmed by the owner when the spec is approved.

- Q: The design labels say Low, Medium and High send 20, 50 and 90. The live checks changed Low to 10 (API research R-6). → A: The app sends 10, 50 and 90. The note on the Figma page is updated to match. No frame changes.
- Q: The sliders in the design look continuous. Can Fares pick any number from 0 to 100? → A: No. Each slider has three stops, Low, Medium and High, as the labels show. The API's 0 ("doesn't matter") isn't offered.
- Q: Where does the feature live? S5 shows the Plans tab highlighted, but S1 says "Rome, Italy". → A: Under the destination, like flights, hotels and cars: a "Plan your trip" section on the overview opens S1. The Plans tab keeps its empty state until itineraries (Sprint 4), with its text pointing to a destination's "Plan your trip".
- Q: Where are the preferences and the total budget kept? → A: In the shared trip settings, in memory, like dates, adults and the driver's age. They are the same for every city and are lost when the app restarts, until saved trips exist.
- Q: Each tab is a search. Hotels and cars cost paid requests, and a car search takes 15–30 s. Are all three loaded at once? → A: No. Only the open tab loads. Hotels open first; flights and cars load the first time their tab is opened. Changing a preference reloads only the open tab (no new paid request, since the API ranks its saved search).
- Q: How many offers does each tab show? → A: The API's ranked list, no pages: the 20 hotels already fetched, the 20 best flights, and the first 20 cars. A link under the cars opens the full car list with its own sort and filters.
- Q: Flights need a departure city. → A: S1's "Flying from" is the same departure city the flights screen uses. Without one, the Flights tab asks for it instead of searching.
- Q: S3 has "Open hotel". What do flights and cars open? → A: A flight opens its booking link outside the app, as the flights screen does. A car opens its details screen (C4).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Say what matters and see the best hotels (Priority: P1)

Fares is planning Rome. They open "Plan your trip", set Budget and Culture to High and Nature to Low, and see the hotels ranked for them, each with a match and a short reason.

**Why this priority**: This is the backlog story, and hotels are where all six preferences count.

**Independent Test**: With a fake repository, set the sliders, tap "Find my best plans", and confirm the request carries `sort=match` and the six weights, and that the hotels show in the API's order with their match and reason.

**Acceptance Scenarios**:

1. **Given** a destination's overview, **When** Fares reads it, **Then** a "Plan your trip" section shows the current preferences in one line and a button. Showing it makes no request.
2. **Given** the section, **When** Fares taps it, **Then** S1 opens with the trip's dates, travellers, departure city, total budget and six sliders (Budget, Culture & history, Food, Nature, Nightlife, Comfort), each showing Low, Medium or High.
3. **Given** S1, **When** Fares moves a slider, **Then** it snaps to Low, Medium or High and its label changes. Nothing is sent yet.
4. **Given** a total budget of 0 or less, **When** Fares taps "Find my best plans", **Then** the field says so and nothing is sent. An empty budget is allowed.
5. **Given** S1, **When** Fares taps "Find my best plans", **Then** "Best for you" opens on the Hotels tab (S2), with the preferences in one line, an Edit link, and a note saying how many hotels, from where, for which dates and when they were checked.
6. **Given** ranked hotels, **When** they show, **Then** they keep the API's order. Each card shows the kind and stars, the match percentage, the name, the nights, area and distance from the centre, the reason, and the total price.
7. **Given** the search is running, **When** Fares waits, **Then** placeholder cards show, as on the hotels screen.
8. **Given** Edit, **When** Fares taps it, **Then** S1 opens with the current values, and "Find my best plans" brings them back to the same tab.

---

### User Story 2 - See why an option is ranked where it is (Priority: P1)

Fares wonders why Hotel Artemide is first. They tap its match and see each preference's share, with the fact behind it.

**Why this priority**: A score with no reason isn't trusted. The breakdown is what makes the ranking useful.

**Independent Test**: With a fake repository, tap a card's match and confirm the sheet lists every part the API returned, in its order, with weight label, percentage, bar and detail.

**Acceptance Scenarios**:

1. **Given** a ranked card, **When** Fares taps it, **Then** the "Why" sheet (S3) opens with the name, the match, the price line, and one row per part: the criterion's name, its level (Low, Medium or High), its percentage, a bar and the detail ("12 top sights within 1.5 km").
2. **Given** a part with `known: false`, **When** it shows, **Then** its detail says it wasn't known and counted as average.
3. **Given** the sheet, **When** Fares reads its foot, **Then** a note says each measure is multiplied by how much it matters, then averaged.
4. **Given** a hotel's sheet, **When** Fares taps "Open hotel", **Then** the hotel's details screen opens for the same trip.
5. **Given** a car's sheet, **When** Fares taps "Open car", **Then** the car's details screen (C4) opens. **Given** a flight's sheet, **When** Fares taps "Open flight", **Then** its booking link opens outside the app, unchanged.

---

### User Story 3 - Compare flights and cars the same way (Priority: P2)

Fares switches to Flights, then Cars, and sees each ranked on budget and comfort.

**Why this priority**: Hotels carry the most value; flights and cars complete the trip.

**Independent Test**: With a fake repository, open each tab and confirm one request with `sort=match`, the note that only budget and comfort count, and cards in the API's order.

**Acceptance Scenarios**:

1. **Given** "Best for you", **When** Fares opens the Flights tab (S4), **Then** flights from the departure city load with `sort=match`, with a note that flights are ranked on budget and comfort only (stops, journey time, dates) and that the prices are recent, not live.
2. **Given** a flight card, **When** it shows, **Then** it shows stops ("Direct", "1 stop"), the match, the route and airline, the date, times and journey time or the stop's city when known, the reason, and the price.
3. **Given** no departure city, **When** the Flights tab opens, **Then** it asks for one with the same field as S1 and searches once it is chosen.
4. **Given** the Cars tab (S6), **When** it opens, **Then** cars at the city centre for the trip's driver load with `sort=match`, with a note that cars are ranked on budget and comfort only, and the searching state while waiting (up to 60 s).
5. **Given** a car card, **When** it shows, **Then** it shows the size, the match, the model and company, gearbox, seats and pick-up area, the reason, and the total.
6. **Given** the Cars tab, **When** Fares reaches the end, **Then** a link opens the full car list.

---

### User Story 4 - Keep to my total budget (Priority: P2)

Fares has $1,500 for the trip. Hotels that cost more than that on their own come last, marked "Over your $1,500 budget".

**Why this priority**: A cheap way to stop the best match being one Fares can't afford.

**Independent Test**: With a fake repository, set a total budget and confirm it is sent as `tripBudget` and that an offer with `overBudget` shows its reason in the warning colour.

**Acceptance Scenarios**:

1. **Given** a total budget, **When** a list loads, **Then** it is sent as `tripBudget` in the trip's currency.
2. **Given** an offer with `overBudget: true`, **When** its card shows, **Then** its match badge is grey and its reason, "Over your $1,500 budget", is in the warning colour (S5).
3. **Given** at least one offer over budget, **When** the list shows, **Then** a note under it says offers that cost more than the whole budget come last, whatever their match.

---

### User Story 5 - Tune it on a wide screen (Priority: P3)

On a laptop, Fares moves a slider and the hotel order changes beside it.

**Why this priority**: The wide layout is in the approved design (W1), but the phone flow already covers the story.

**Independent Test**: At a wide size with a fake repository, move a slider and confirm one new request after the slider settles, and that the selected hotel's "Why" panel follows the list.

**Acceptance Scenarios**:

1. **Given** a wide screen, **When** "Best for you" opens, **Then** S1's form, the list and the selected offer's "Why" panel show side by side (W1). The first offer is selected.
2. **Given** W1, **When** Fares moves a slider or changes the budget, **Then** the open tab reloads once the change settles (about half a second), and a note says the ranking updates as sliders move and no new search runs.
3. **Given** W1, **When** Fares selects another card, **Then** it is outlined and the "Why" panel shows it.

---

### Edge Cases

- **Places near hotels couldn't be counted** (the API's warning): a warning note shows above the list (S5). Unknown parts say so in the "Why" sheet.
- **`rankingNote`** (every preference that counts for this kind is at 0): not reachable from the app, since the sliders have no 0. If it comes, the note shows and cards show without a match.
- **An offer without `match`**: its card shows without a badge or reason, and tapping it opens the offer as it would elsewhere.
- **No offers**: the tab's own empty message and the API's `message`, with the source's search link when given.
- **Saved prices or source down** (`isSavedPrice`, `warnings`): a warning note above the list.
- **Backend unreachable, a 5xx, or no answer in time** (60 s for cars, 30 s otherwise): the layout stays with placeholders, the error and Try again, with no automatic retry.
- **400 for a preference or budget**: prevented by the controls; if it happens, the error shows the API's reason.
- **Changing dates, travellers or currency**: lists reload for the new values; the preferences stay.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The destination overview MUST offer "Plan your trip", which MUST NOT make a request until "Best for you" is open.
- **FR-002**: S1 and "Best for you" MUST be routes under the destination, so they work with back navigation and web links. The open tab MUST be part of the link.
- **FR-003**: Preferences MUST have three levels that send 10 (Low), 50 (Medium) and 90 (High). The default is Medium for every one.
- **FR-004**: Preferences and the optional total budget MUST be kept in the shared trip settings, next to dates, travellers and the driver's age.
- **FR-005**: Each tab MUST request its list with `sort=match`, the six weights and `tripBudget` when set, and MUST keep the API's order. The app MUST NOT score, sort or filter offers itself.
- **FR-006**: Only the open tab MUST load. A tab's result MUST be reused when Fares returns to it with the same values.
- **FR-007**: The match, reason, `overBudget`, parts, `warnings`, `message` and `rankingNote` MUST be shown whenever given.
- **FR-008**: The "Why" view MUST show every part the API returned, in its order, and MUST NOT invent parts the API left out.
- **FR-009**: The screens MUST follow the constitution's Never a Blank Screen rules: placeholders while loading, an immediate error with Try again, and no automatic retry.
- **FR-010**: The screens MUST work at phone width and on wide screens, following the approved Figma design.
- **FR-011**: The screens MUST get all their data from `pamplemousse`. No API change is needed.

### Key Entities

- **Preferences**: six levels (Low, Medium, High) and an optional total budget.
- **Match**: percentage, reason, over-budget flag and parts.
- **Match part**: criterion, weight, percentage, known flag and detail.
- **Ranked results**: the existing hotel, flight and car results, each offer with its optional match, plus the weights used, the total budget and an optional ranking note.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From a destination's overview, Fares reaches ranked hotels in 2 taps and a hotel's "Why" in 3.
- **SC-002**: In tests, every part the API returns appears in the "Why" view, and no missing value shows as 0.
- **SC-003**: With the backend stopped, the layout and the error appear at once, with no wait for retries.
- **SC-004**: Changing a preference makes no new paid request: checked in the backend's log during the live check.
- **SC-005**: Checked in the running app against the real API at 390 px and desktop widths: Rome hotels with Budget High, the "Why" sheet, flights from Beirut or Paris, cars, a total budget that puts some hotels over, and the wide layout's slider updates.

## Assumptions

- Depends on the weighted search parameters of `GET /destinations/{id}/hotels`, `/flights` and `/cars` in `pamplemousse`, merged on 5 Nov 2026.
- Saving a plan, building an itinerary and the assistant using preferences are out of scope (Sprint 4 and later).
- Only the city centre is used for cars here. Another pick-up place is chosen on the car screen.
- Live data needs the backend running locally, because the API isn't deployed yet.
