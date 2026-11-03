# Feature Specification: Flight screen

**Feature Branch**: `001-flight-screen`

**Created**: 2026-11-02

**Status**: Approved by the owner on 2026-11-02, with the Figma design

**Input**: User description: "TG-06: As Fares, I want to see flights for my dates." The API is already delivered: [pamplemousse spec 001-flights](https://github.com/anthony-117/pamplemousse/blob/main/specs/001-flights/spec.md) and its [contract](https://github.com/anthony-117/pamplemousse/blob/main/specs/001-flights/contracts/flights-api.md).

## Clarifications

### Session 2026-11-02

- Q: The source's airline field is wrong for about a third of sampled fares (34 of 98). Show it? → A: No. The screen hides airline and flight number; the booking site shows the real ones.
- Q: Which flight source does the screen use? → A: Only `pamplemousse`, which uses Travelpayouts (ADR 0014). Duffel test data is not shown to travellers.
- Q: The backend can warn that the partner marker is missing, which means nothing to a traveller. Show it? → A: No. The backend stops sending it to the app and logs it instead, in the same delivery.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See flight prices for my trip (Priority: P1)

Fares is looking at Rome. They open Flights, choose their departure city once, and see fares for the trip's dates, cheapest first, each clearly marked as a recent price.

**Why this priority**: This is the backlog story. The API exists, but travellers can't see any of it yet.

**Independent Test**: With a fake repository, open the screen for a destination, choose a departure city, and confirm the fares appear in the order returned, with every shown field present.

**Acceptance Scenarios**:

1. **Given** the overview of a destination, **When** Fares opens Flights, **Then** the flight screen opens for that destination and the trip's dates.
2. **Given** no departure city has been chosen, **When** the screen opens, **Then** it asks for one and requests nothing yet.
3. **Given** a departure city was chosen earlier in this session, **When** Fares opens Flights for another destination, **Then** that city is already selected and they can change it.
4. **Given** a departure city, **When** the fares load, **Then** they are listed in the API's order, cheapest first.
5. **Given** a fare, **When** Fares reads it, **Then** they see its price, departure and arrival airports, outbound and return dates and times, direct or number of stops, and duration when known. They do not see an airline or flight number.
6. **Given** a list of fares, **When** Fares reads the screen, **Then** the API's `priceNote` is visible, saying these are recent prices and the live price is on the booking site.
7. **Given** fares that are not on the exact dates, **When** Fares reads them, **Then** each shows its actual dates and a label: "Nearby dates", "Same month" or "Different return", and the API's `message` is visible.
8. **Given** Fares changes the trip's dates or currency, **When** the change is made, **Then** the fares reload for the new values.

---

### User Story 2 - Open a fare to book it (Priority: P1)

Fares taps a fare and goes to the booking site to see the live price and buy.

**Why this priority**: Without it, a price is only information, and it is how the project earns commission.

**Independent Test**: With a fake repository and a fake link opener, tap a fare and confirm the link opened is that fare's `bookingUrl`, unchanged.

**Acceptance Scenarios**:

1. **Given** a fare, **When** Fares taps it or its button, **Then** its `bookingUrl` opens outside the app, unchanged.
2. **Given** the link can't be opened, **When** Fares taps it, **Then** a short message says so and the screen stays as it was.

---

### User Story 3 - Change what I'm searching for (Priority: P2)

Fares switches between round trip and one way, and asks for direct flights only.

**Why this priority**: Useful but not essential, because the default search already works.

**Independent Test**: With a fake repository, change each control and confirm the next request carries the new value.

**Acceptance Scenarios**:

1. **Given** the screen opens, **When** nothing has been changed, **Then** the search is a round trip, and not limited to direct flights.
2. **Given** Fares chooses one way, **When** the fares load, **Then** no return is shown, and the price is labelled one way.
3. **Given** Fares turns on direct only, **When** the fares load, **Then** the request asks for direct flights only.

---

### Edge Cases

- **No fares at any level**: the layout stays, with the API's `message` and a button that opens `searchUrl`, the booking site's own search.
- **Source down or not configured**: the API still succeeds with an empty list, so the screen shows its `warnings`, and the rest of the screen keeps working.
- **Backend unreachable or a 5xx**: the layout stays with placeholder boxes, with the error and Try again, shown at once.
- **Departure city is the same flight city as the destination (400)**: a short message asks for a different city, and the city stays changeable.
- **A city without its own airport** (`isNearby`): a note says which city is used and how far away it is.
- **Missing duration**: left out of the fare, with no empty gap.
- **Missing `bookingUrl` or a badly formed date**: treated by parsing as a broken response, so the error state appears and no fare shows a dead button.
- **Trips over 30 days or dates in the past**: already prevented by the date picker in the trip chips.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The destination overview MUST offer a way into Flights, which MUST NOT make a flight request until the flight screen is open.
- **FR-002**: The flight screen MUST be its own route under the destination, so it works with back navigation and web links.
- **FR-003**: Travellers MUST choose the departure city from the existing city search. The app MUST NOT guess it.
- **FR-004**: The app MUST remember the chosen departure city for the session and across destinations. Saving it between visits is out of scope.
- **FR-005**: The screen MUST use the shared trip settings for dates and currency, and MUST let travellers change them there.
- **FR-006**: Each fare MUST show price, airports, actual dates and times, stops for each direction, and duration when known.
- **FR-007**: The screen MUST NOT show airline or flight number. The app's model MUST NOT parse them, so they can't appear by accident.
- **FR-008**: Every fare not on the exact dates MUST carry a visible label, and the API's `message` MUST be visible.
- **FR-009**: The API's `priceNote` MUST be visible whenever fares are shown.
- **FR-010**: Booking links MUST open outside the app, unchanged.
- **FR-011**: The screen MUST follow the constitution's Never a Blank Screen rules: placeholder boxes while loading, an immediate error with Try again, and no automatic retry.
- **FR-012**: The screen MUST work at phone width and on wide screens, following the approved Figma design.
- **FR-013**: The screen MUST get all its data from `pamplemousse`. The only API change is that the missing-marker warning is logged by the backend instead of being returned.

### Key Entities

- **Flight search**: destination, departure city, dates, currency, trip type, direct only. It identifies one request.
- **Flight fare**: price, airports, departure and return times, stops, optional duration, booking link, and how closely it matches the requested dates.
- **Flight results**: the fares, plus the cities used, the price note, an optional message, an optional search link and warnings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From a destination's overview, a traveller who has chosen a departure city reaches fares in 2 taps.
- **SC-002**: 100% of shown fares in tests carry a price, a working link and, when not exact, a date label.
- **SC-003**: No airline or flight number appears anywhere on the screen.
- **SC-004**: With the backend stopped, the layout and the error appear at once, with no wait for retries.
- **SC-005**: Checked in the running app against the real API at 390 px and desktop widths, for at least one exact, one non-exact and one empty route.

## Assumptions

- Depends on the existing `GET /api/v1/destinations/{id}/flights`. The backend's `airline` and `flightNumber` fields stay in the API, because later features may use them; only this screen hides them.
- One adult, economy, as in the API. Passenger count and cabin aren't offered.
- Sorting and filtering beyond the API's options, weighted ranking (TG-09) and adding a fare to a plan are out of scope.
- A new package for opening links (`url_launcher`) is expected, unless the planning step finds one already present. It is justified in the pull request.
- Live data needs the backend running locally, because the API isn't deployed yet. Deployment is parked.
