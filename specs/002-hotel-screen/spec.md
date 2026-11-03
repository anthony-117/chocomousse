# Feature Specification: Hotel screen

**Feature Branch**: `002-hotel-screen`

**Created**: 2026-11-04

**Status**: Approved by the owner on 2026-11-04, with the Figma design (page "Sprint 2 — Hotels", H1–H7 and W1)

**Input**: User description: "TG-07: As a traveller, I want to see hotels for my dates." The API is built on the `002-hotels` branch of `pamplemousse`: [spec](https://github.com/anthony-117/pamplemousse/blob/002-hotels/specs/002-hotels/plan.md) and [contract](https://github.com/anthony-117/pamplemousse/blob/002-hotels/specs/002-hotels/contracts/hotels-api.md).

## Clarifications

### Session 2026-11-04

Confirmed by the owner with the spec.

- Q: The API gives `totalItems` for the pages fetched so far, not how many pages exist, so the app can't show "Page 1 of 12" or know whether Next leads anywhere. → A: Add `totalPages` (the source's page count) to the search response in `pamplemousse`, before `002-hotels` is pushed. The app shows "Page N of M" and offers Next while N < M.
- Q: How many adults? The shared trip settings have none, and the API defaults to 2. → A: Add adults (1–8, default 2) to the shared trip settings, changed from the "2 adults · 1 room" chip. Flights keep using one adult, as their API does.
- Q: The design's card shows a review word ("Fabulous"), but the search response has none; only the details do. → A: The card shows the score and the review count ("8.9 · 3,214 reviews"). The word appears on the details screen. No API change.
- Q: The details give languages as codes (`en-gb`, `it`). → A: Shown as names in English ("English, Italian"); an unknown code is shown as it is.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See hotels for my trip (Priority: P1)

A traveller looking at Rome opens Hotels and sees hotels for the trip's dates and adults, each with its total price for the stay.

**Why this priority**: This is the backlog story. The API exists, but travellers can't see any of it yet.

**Independent Test**: With a fake repository, open the screen for a destination and confirm the hotels appear in the order returned, with every shown field present and missing ones hidden.

**Acceptance Scenarios**:

1. **Given** the overview of a destination, **When** the traveller opens Hotels, **Then** the hotel screen opens for that destination, the trip's dates, adults and currency, and requests hotels at once.
2. **Given** hotels are returned, **When** they are listed, **Then** they keep the API's order.
3. **Given** a hotel, **When** the traveller reads its card, **Then** they see its photo, name, stars, review score and count, distance from the centre, total price, price per night and nights, and "Booking.com".
4. **Given** a hotel without stars, reviews or photo, **When** its card shows, **Then** the missing part is hidden (the photo becomes the placeholder), never shown as 0.
5. **Given** a hotel with `freeCancellation` true, **When** its card shows, **Then** it has the "Free cancellation" tag. False or unknown shows nothing.
6. **Given** a hotel with `nearCity` true, **When** its card shows, **Then** a badge says how far it is from the destination ("14 km from Zahlé").
7. **Given** a list of hotels, **When** the traveller reads the screen, **Then** a note says the prices come from Booking.com, when they were checked, and that the final price is on Booking.com.
8. **Given** the source's city differs from the destination (`sourceName`), **When** the screen shows, **Then** a note says which city was searched.
9. **Given** the traveller changes the dates, adults or currency, **When** the change is made, **Then** the hotels reload for the new values, from page 1.

---

### User Story 2 - Open a hotel and book it (Priority: P1)

The traveller taps a hotel, reads its details, and goes to Booking.com to book.

**Why this priority**: Without it, a price is only information, and booking is how the project earns commission.

**Independent Test**: With a fake repository and a fake link opener, open a hotel and confirm its details show, and that the button opens its `bookingUrl` unchanged.

**Acceptance Scenarios**:

1. **Given** a hotel in the list, **When** the traveller taps it, **Then** its details screen opens with the trip's dates, adults and currency.
2. **Given** the details, **When** they load, **Then** the traveller sees the photos, name, stars, review score with its word and count, address and district, distance to the centre, stay type, free cancellation and breakfast when true, check-in and check-out times, facilities, languages, and the price.
3. **Given** the details have no price for these dates (`price` null), **When** they show, **Then** the price box says to see the price on Booking.com, and the button still works.
4. **Given** the details, **When** the traveller taps "Book on Booking.com", **Then** `bookingUrl` opens outside the app, unchanged.
5. **Given** the link can't be opened, **When** the traveller taps it, **Then** a short message says so and the screen stays as it was.
6. **Given** a hotel opened from a web link, **When** the page loads, **Then** the details show for the trip's current settings.

---

### User Story 3 - Sort and filter (Priority: P2)

The traveller sorts the hotels and narrows them by stars, reviews, price, stay type and free cancellation.

**Why this priority**: Useful but not essential, because the default list already works.

**Independent Test**: With a fake repository, change each control and confirm the next request carries the new values and starts at page 1.

**Acceptance Scenarios**:

1. **Given** the screen opens, **When** nothing has been changed, **Then** the sort is Recommended and no filter is on.
2. **Given** the sort and filter sheet, **When** the traveller chooses options and taps "Show hotels", **Then** the hotels reload with them, from page 1, and the Filters button shows how many filters are on.
3. **Given** a stay type or free cancellation filter is on, **When** the hotels load, **Then** a note says how many of the hotels on the page could be checked (`filtersCheckedOn`).
4. **Given** "Clear all", **When** the traveller taps it, **Then** every filter goes back to its default.
5. **Given** a minimum price above the maximum, **When** the traveller tries to apply it, **Then** the sheet says so and sends nothing.

---

### User Story 4 - More hotels (Priority: P2)

The traveller moves to the next page of hotels.

**Acceptance Scenarios**:

1. **Given** page N of M, **When** N < M, **Then** Next is offered; on page 1, Previous is disabled.
2. **Given** the traveller taps Next or Previous, **When** the page loads, **Then** the list shows that page from its top.

---

### Edge Cases

- **No hotels** (`items` empty with `message`): the layout stays, with the message and a button that opens `searchUrl` (H5).
- **No match for filters**: the message, "Clear filters", and the Booking.com search (H6). Next is still offered when later pages exist.
- **Saved prices or source down** (`isSavedPrice`, `warnings`): a warning note above the list (H4); the rest works.
- **Backend unreachable or a 5xx**: the layout stays with placeholder cards, the error and Try again, shown at once, with no automatic retry.
- **400 for adults or dates**: prevented by the controls; if it happens, the error state shows the API's reason.
- **404 on details** (hotel unknown): the details screen says the hotel can't be found, with Back.
- **Details without `checkInFrom` or `checkOutUntil`**: that tile is hidden.
- **A photo that fails to load**: the gradient placeholder, as for places.
- **Missing `id`, `price` on a list item, or a badly formed date**: treated by parsing as a broken response, so the error state appears.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The destination overview MUST offer a way into Hotels (H7), which MUST NOT make a hotel request until the hotel screen is open.
- **FR-002**: The hotel list and hotel details MUST be their own routes under the destination, so they work with back navigation and web links.
- **FR-003**: The screens MUST use the shared trip settings for dates, adults and currency, and MUST let travellers change them there.
- **FR-004**: Missing stars, reviews, stay type and photos MUST be hidden, never shown as 0 or false.
- **FR-005**: The price note, `warnings`, `message` and `sourceName` note MUST be visible whenever they are given.
- **FR-006**: Booking links and the Booking.com search MUST open outside the app, unchanged.
- **FR-007**: Sort and filters MUST be sent as API parameters. The app MUST NOT filter or sort hotels itself.
- **FR-008**: The screens MUST follow the constitution's Never a Blank Screen rules: placeholder boxes while loading, an immediate error with Try again, and no automatic retry.
- **FR-009**: The screens MUST work at phone width and on wide screens, following the approved Figma design.
- **FR-010**: The screens MUST get all their data from `pamplemousse`. The only API change is adding `totalPages` to the search response.

### Key Entities

- **Hotel search**: destination, dates, adults, currency, sort, filters and page. It identifies one request.
- **Hotel offer**: id, name, optional photo, stars and reviews, distance, near-city flag, optional free cancellation, total and per-night price.
- **Hotel results**: the offers, page and total pages, when prices were checked, whether they are saved, the source's city name, and the optional message, search link, filter check count and warnings.
- **Hotel details**: the offer's fields plus photos, address, district, stay type, breakfast, check-in and check-out times, facilities, languages, review word, optional price and booking link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From a destination's overview, a traveller reaches hotels in 1 tap and a hotel's booking link in 3.
- **SC-002**: 100% of shown hotels in tests carry a name and a price, and no missing value shows as 0.
- **SC-003**: With the backend stopped, the layout and the error appear at once, with no wait for retries.
- **SC-004**: Checked in the running app against the real API at 390 px and desktop widths, for a large city (Rome), a small one with nearby hotels (Zahlé), a filtered search and a hotel's details.

## Assumptions

- Depends on `GET /api/v1/destinations/{id}/hotels` and `GET /api/v1/hotels/{hotelId}` from `pamplemousse`, with `totalPages` added.
- One room; children aren't offered.
- Stay type choices are Hotels, Apartments, Guest houses and Hostels, the names Booking.com uses; the plan checks them against live data.
- Sorting and filters apply to the hotels fetched for the requested page, as the API documents.
- Comparing hotels, saving them, adding them to a plan and weighted ranking (TG-09) are out of scope.
- Live data needs the backend running locally, because the API isn't deployed yet.
