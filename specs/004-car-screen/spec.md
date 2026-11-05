# Feature Specification: Car rental screen

**Feature Branch**: `004-car-screen`

**Created**: 2026-11-05

**Status**: Draft, waiting for the owner's approval. Design: Figma page "Sprint 2 — Cars", C1–C7, approved 2026-11-05

**Input**: User description: "TG-08: As Fares, I want to see car rental options." The API is merged in `pamplemousse`: [spec](https://github.com/anthony-117/pamplemousse/blob/main/specs/004-cars/spec.md) and [contract](https://github.com/anthony-117/pamplemousse/blob/main/specs/004-cars/contracts/cars-api.md).

## Clarifications

### Session 2026-11-05

Proposed with the spec, for the owner to confirm.

- Q: A car search takes 15–30 s at the source, but the app gives up on any answer after 30 s. → A: Car searches get their own 60 s limit. Other requests keep 30 s. While waiting, the screen shows the searching state (C5).
- Q: There is no API for one car's details. Where does the details screen (C4) get its data? → A: From the car the traveller tapped in the list. Opening a car's web link with no list loaded (a reload, or a pasted link) goes back to the list for the same trip, which comes from the cache at once.
- Q: Where are the driver's age and the pick-up place kept? → A: The age goes into the shared trip settings (18–99, default 30), so it stays the same across cities, like adults. The pick-up place belongs to one city and goes back to the city centre whenever another city's cars are opened.
- Q: No wide-screen frame was drawn for cars. → A: The same wide layout as hotels: sort and filters in a side panel next to the list, and the details in one column of readable width.
- Q: The design's details screen says "3 big bags". The API only knows checked bags. → A: The details screen says "3 checked bags".

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See rental cars for my trip (Priority: P1)

Fares is looking at Rome. They open Car rental from the overview and see cars to pick up in the city centre for the trip's dates, each with its total price for the rental.

**Why this priority**: This is the backlog story. The API exists, but travellers can't see any of it yet.

**Independent Test**: With a fake repository, open the screen for a destination and confirm the cars appear in the order returned, with every shown field present and missing ones hidden.

**Acceptance Scenarios**:

1. **Given** a destination's overview, **When** Fares reads it, **Then** a Car rental section (C7) shows the dates, the pick-up place, the driver's age, and that the search takes up to 30 seconds. Showing it makes no car request.
2. **Given** the section, **When** Fares taps it, **Then** the car screen opens for that destination with the trip's dates, currency and driver's age, at the city centre, and searches at once.
3. **Given** the search is running, **When** Fares waits, **Then** the searching state (C5) shows the trip chips, a note that the search takes up to 30 seconds and that results are kept for a day, a progress bar and placeholder cards.
4. **Given** cars are returned, **When** they are listed, **Then** they keep the API's order.
5. **Given** a car, **When** Fares reads its card, **Then** they see the photo, model and "or similar", size, gearbox, seats, checked bags, the company with its logo and rating, the pick-up place with its type and distance from the centre, the total price, the price per day and number of days, "Free cancellation" when true, "Ad" when sponsored, and "Booking.com".
6. **Given** a car without a photo, logo, rating, seats or bags, **When** its card shows, **Then** the missing part is hidden (the photo becomes the placeholder), never shown as 0.
7. **Given** a list of cars, **When** Fares reads the screen, **Then** a note says the prices come from Booking.com, when they were checked, that pick-up and return are at 10:00, and that the final price is on Booking.com.
8. **Given** `mayHaveMore` is true, **When** the list shows, **Then** a note says Booking.com has more cars than shown, with a link to its search.
9. **Given** Fares changes the dates or currency, **When** the change is made, **Then** the cars reload for the new values, from page 1, with the searching state.

---

### User Story 2 - Choose the pick-up place and the driver's age (Priority: P2)

Fares lands at Fiumicino and is 23. They tap the pick-up chip, choose the airport and set their age, and the list updates.

**Why this priority**: The centre and age 30 suit most trips. This makes the prices right for the rest.

**Independent Test**: With a fake repository, choose an airport and an age in the sheet and confirm the next request carries `place` and `driverAge`, and that the young-driver note shows.

**Acceptance Scenarios**:

1. **Given** the car screen, **When** Fares taps the pick-up or driver chip, **Then** the "Pick-up and driver" sheet (C3) opens with the city centre and the city's airports ("Fiumicino Airport · FCO"), and the age.
2. **Given** the places can't be loaded, or the city has no airport, **When** the sheet opens, **Then** only the city centre is offered, with the API's warning when there is one.
3. **Given** an age under 25 or over 70 is typed, **When** the sheet shows it, **Then** the matching note shows under the field. An age outside 18–99 can't be applied.
4. **Given** Fares applies a new place or age, **When** the sheet closes, **Then** the cars reload for them from page 1, and the chips show the new place and age.
5. **Given** the API gives a `driverNote`, **When** the list shows, **Then** the note shows above the cars.

---

### User Story 3 - Open a car and go to Booking.com (Priority: P1)

Fares taps a car, reads what's included, and goes to Booking.com to book it.

**Why this priority**: Without it, a price is only information.

**Independent Test**: With a fake repository and a fake link opener, open a car and confirm its details show, and that the button opens its `bookingUrl` unchanged.

**Acceptance Scenarios**:

1. **Given** a car in the list, **When** Fares taps it, **Then** its details screen (C4) opens.
2. **Given** the details, **When** they show, **Then** Fares sees the photo, model, the company with its rating and review count, the pick-up address, type and distance, the size, free cancellation, mileage, the pick-up and return day and time, gearbox, seats, doors, checked bags and air-con, and "Good to know": deposit and damage excess in their own currency, the fuel policy, and whether to pay now or at pick-up.
3. **Given** the details, **When** Fares reads the price box, **Then** it shows the total, the number of days, and that Booking.com opens its car search for the same dates and driver, where they look for this model from this company at this desk.
4. **Given** the details, **When** Fares taps the button, **Then** `bookingUrl` opens outside the app, unchanged.
5. **Given** the link can't be opened, **When** Fares taps it, **Then** a short message says so and the screen stays as it was.

---

### User Story 4 - Sort, filter and page (Priority: P2)

Fares sorts the cars and narrows them by size, gearbox, seats, bags, price, pick-up type, company and free cancellation, and moves between pages.

**Why this priority**: Useful but not essential, because the default list already works. Each change answers at once, since the API filters its saved search.

**Independent Test**: With a fake repository, change each control and confirm the next request carries the new values and starts at page 1.

**Acceptance Scenarios**:

1. **Given** the screen opens, **When** nothing has been changed, **Then** the sort is Recommended and no filter is on.
2. **Given** the sort and filter sheet (C2), **When** Fares chooses options and taps the button, **Then** the cars reload with them from page 1, and the Filters chip shows how many filters are on.
3. **Given** the sheet, **When** it lists sizes, pick-up types and companies, **Then** it offers only the values in `filterOptions`, in the API's order, with all companies reachable.
4. **Given** "Clear all", **When** Fares taps it, **Then** every filter goes back to its default.
5. **Given** a maximum total of 0 or less, **When** Fares tries to apply it, **Then** the sheet says so and sends nothing.
6. **Given** page N of M, **When** N < M, **Then** Next is offered; on page 1, Previous is disabled. A new page shows from its top.

---

### Edge Cases

- **No cars** (`items` empty, no filter on): the layout stays, with "No rental cars here for these dates", the API's message and a button that opens `searchUrl` (C6).
- **No match for the filters**: the message, "Clear filters", and the Booking.com search.
- **Saved prices or source down** (`isSavedPrice`, `warnings`): a warning note above the list; the rest works.
- **Backend unreachable, a 5xx, or no answer within 60 s**: the layout stays with placeholder cards, the error and Try again, with no automatic retry.
- **400 for dates, age or place**: prevented by the controls; if it happens, the error state shows the API's reason.
- **Deposit or damage excess missing**: left out of "Good to know". When both are missing, so is their line.
- **A photo or logo that fails to load**: the gradient placeholder for the photo; the company name alone for the logo.
- **Missing `id`, `price` or `bookingUrl` on an item, or a badly formed date**: treated as a broken response, so the error state appears.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The destination overview MUST offer a way into Car rental (C7), which MUST NOT make a car request until the car screen is open.
- **FR-002**: The car list and car details MUST be their own routes under the destination, so they work with back navigation and web links.
- **FR-003**: The screens MUST use the shared trip settings for dates, currency and the driver's age, and MUST let travellers change them there. The pick-up place MUST start at the city centre for each city.
- **FR-004**: Car search requests MUST wait up to 60 s for an answer; other requests keep their limit.
- **FR-005**: While a search runs, the screen MUST show the searching state (C5), not a blank screen or a spinner alone.
- **FR-006**: Missing values MUST be hidden, never shown as 0 or false.
- **FR-007**: The price note, `driverNote`, `warnings`, `message` and the `mayHaveMore` note MUST be visible whenever they are given.
- **FR-008**: The Booking.com links MUST open outside the app, unchanged.
- **FR-009**: Sort and filters MUST be sent as API parameters. The app MUST NOT filter or sort cars itself.
- **FR-010**: The screens MUST follow the constitution's Never a Blank Screen rules: placeholders while loading, an immediate error with Try again, and no automatic retry.
- **FR-011**: The screens MUST work at phone width and on wide screens, following the approved Figma design.
- **FR-012**: The screens MUST get all their data from `pamplemousse`. No API change is needed.

### Key Entities

- **Car search**: destination, dates, pick-up place, driver's age, currency, sort, filters and page. It identifies one request.
- **Pick-up place**: id, kind (centre or airport), name and airport code.
- **Car offer**: id, model, size, optional photo, gearbox, seats, doors, bags, air-con, mileage, fuel policy, company (name, optional logo and rating), pick-up point (name, type, address, distance), price (total, per day, currency, pay now), optional free cancellation, deposit and damage excess, sponsored flag and booking link.
- **Car results**: the offers, page and total pages, when prices were checked, whether they are saved, whether more cars exist, the filter options with their counts, and the optional driver note, message, search link and warnings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From a destination's overview, a traveller reaches cars in 1 tap and a car's Booking.com search in 3.
- **SC-002**: 100% of shown cars in tests carry a model and a price, and no missing value shows as 0.
- **SC-003**: With the backend stopped, the layout and the error appear at once, with no wait for retries.
- **SC-004**: Checked in the running app against the real API at 390 px and desktop widths: Rome at the centre, Rome at Fiumicino with a 23-year-old driver, a filtered search, a car's details, and Zahlé.

## Assumptions

- Depends on `GET /api/v1/destinations/{id}/car-places` and `GET /api/v1/destinations/{id}/cars` from `pamplemousse`, merged on 5 Nov 2026.
- One car, picked up and returned at the same place at 10:00. One-way rentals, extras and insurance are out of scope.
- Comparing cars, saving them, adding them to a plan and weighted ranking (TG-09) are out of scope.
- The assistant can't suggest cars yet, so it opens no car screen.
- Live data needs the backend running locally, because the API isn't deployed yet.
