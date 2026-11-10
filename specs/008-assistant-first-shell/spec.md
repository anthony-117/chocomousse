# Feature Specification: Assistant-first shell (design v1.0, step 1)

**Feature Branch**: `008-assistant-first-shell`

**Created**: 2026-11-10

**Status**: Approved by the owner on 2026-11-10

**Design**: Figma file `s52ShmznT28QgNN6u6Wddu`, design v1.0 approved by the owner on 2026-11-10 (logged in OneDrive
`04-design/figma/figma-links.md`). Pages "v1.0 — Design system (approved)" (node 2301:17), "v1.0 — Web (approved)"
(2301:18: W1 Home, W2 Conversation + plan panel, W2 Dark) and "v1.0 — Mobile (approved)" (2301:19: M1 Home, M2 Chat
with results, M2 Dark, M3 Plan opened from chat, M4 "+" tools sheet, M5 Drawer). It replaces design v0.2.
**Pending design**: the side panel's Trip, Details, Map and Saved panes (web and mobile, light and dark) are added to
the v1.0 file (drafted by Claude, reviewed and approved by the owner) before the plan (see Clarifications).

**Input**: User description: "Assistant-first shell (design v1.0). First step of the v1.0 redesign: the app becomes an
AI assistant first, modelled on the Claude desktop app. (1) new app shell — sidebar on web and drawer on mobile,
replacing the v0.2 floating nav and plan dock; (2) Theme v1 tokens light and dark, Newsreader serif for the greeting
and headings, Plus Jakarta Sans for the rest; (3) assistant home; (4) answers in the chat: tool-step lines, then
flight, hotel, car, place, event and plan cards with match %, suggested next steps; the plan opens in a side panel on
web and a sheet on mobile, like Claude's artifacts; (5) mobile '+' tools sheet. Chat history saved on the server per
account. Saved (bookmarks) in scope. Mic, location and attachments out. Explore, My plans and Preferences restyles
are later specs. The backend 'assistant v2' spec comes first in pamplemousse; this spec lists what it needs."

## Context

On 2026-11-10 the owner changed the requirements: TravelGenie is now an assistant first, with screens to see and
search second. **Every feature must be reachable through the assistant**: flights, hotels, cars, places, events, travel
info (visa, weather, currency, safety, holidays), preferences, building and changing plans, and saved plans.

Today (spec 003) the assistant answers in text with link cards (overview, places, flights, hotels) that open the
v0.2 screens; it cannot rank by preferences, search cars, or build or change a plan, and the server keeps no chat.
The itinerary API (pamplemousse spec 008) and the ranked lists (pamplemousse spec 007) exist, but only the screens use
them.

This spec is the app side of step 1. The backend side is a new pamplemousse spec ("assistant v2", see
[Backend dependencies](#backend-dependencies)), which comes first under the constitution's two-repo rule.

### Scope decisions (owner, 2026-11-10)

- In: the shell (sidebar and drawer), Theme v1 light and dark, the assistant home, rich answers with the side panel (Trip, Plan, Details, Map, Saved),
  the mobile "+" tools sheet, chat history saved on the server (Recents and Search chats), Saved (bookmarks), and a
  dark-mode switch.
- Out, later specs: Explore (W3, M6), My plans restyle (W4), Preferences restyle (W5), voice input (mic), "Use my
  location", "Attach a photo or booking". Until their specs, the sidebar's Explore and My plans open today's screens,
  and the mic and the two out-of-scope tools-sheet rows are not shown.
- Backend first: the assistant v2 spec in pamplemousse is written and approved before this one is planned.

## Clarifications

### Session 2026-11-10

- Q: What does "change the plan by chatting" cover in this step? → A: Swapping the hotel, flight or car, removing the car, and changing a day's own items (replace, add or remove a place, restaurant or event). The assistant v2 backend spec adds a day-editing route and tool.
- Q: Do tool steps show live or with the whole reply? → A: Live: each step line appears as its tool finishes; the text and cards follow when the answer is done (the text itself is not streamed word by word). The assistant v2 backend spec adds the stream.
- Q: How long does the server keep a traveller's chats? → A: 90 days after the chat's last message, then it is deleted automatically; the traveller can delete one before. Chat text is never logged.
- Q: Where do a card's details open? → A: In a right-hand **side panel** with an icon bar on top, one icon per pane, modelled on the Claude Code desktop side panel. Panes: **Trip** (the chat's trip, preferences, pace and budget, each editable, and the chat's outputs: plans built, items found, items saved), **Plan** (W2's plan panel), **Details** (the tapped hotel, flight, car, place or event, with Add to plan and bookmark), **Map** (everything found in this chat and the plan's days) and **Saved** (the account's saved items). On narrow screens the same panes open in a sheet. The chat stays visible on web.
- Q: The approved v1.0 Figma only has the Plan pane (W2, M3); who designs the other panes? → A: Claude drafts the side panel's frames (Trip, Details, Map, Saved; web and mobile; light and dark) in the v1.0 Figma file; the owner reviews and approves them before this spec's plan (constitution IV).
- Q: What can be saved? → A: Hotels, places and events. Flights and cars are not saved (their prices change by the hour); they are kept in plans.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Plan a trip by asking (Priority: P1)

Fares opens TravelGenie and lands on the assistant (W1/M1): "Where to next, Fares?" and a composer showing their trip
(Rome · 10–14 Apr · 2 adults) and preferences (Culture · Food · Balanced). They type "Plan 5 days in Rome for two,
from Beirut, under $1,200". While the assistant works they see what it is doing ("Searched flights Beirut → Rome · 23
fares", "Searched hotels in Rome · 48 found, ranked for you"…). The answer explains the plan in a few sentences and
shows the plan card (Rome, 5 days · 91 % match · $939 of $1,200 · Draft), the best flight for them and the hotels that
fit them best, each with its match. They open the plan, which slides in beside the chat on web (W2) or as a sheet on
the phone (M3), with its days, hotel, flight, car, map and costs.

**Why this priority**: This is the new product: the assistant does the work the v0.2 screens made the traveller do.

**Independent Test**: With a fake assistant that answers with tool steps, a plan card, a flight card and two hotel
cards, send a message at 390 px and at desktop width; check the steps, the cards, their match, and that Open plan
shows the plan in the panel or sheet without leaving the chat.

**Acceptance Scenarios**:

1. **Given** a signed-in traveller, **When** they open the app, **Then** the assistant home shows the greeting with their first name, the composer with the trip and preferences chips, the suggestions, and "Pick up where you left off" with their latest plans.
2. **Given** they sent a message, **When** the assistant is working, **Then** their message shows at once and each tool step shows as a line with its icon and a short result (W2: "Searched hotels in Rome · 48 found, ranked for you").
3. **Given** a tool step line, **When** they tap its chevron, **Then** it expands to the items that search found, ranked, as cards.
4. **Given** the answer has a plan, **When** it arrives, **Then** a plan card shows the plan's photo, name, "Itinerary · match · total of budget · status" and Open plan.
5. **Given** a plan card, **When** they choose Open plan, **Then** on web the side panel opens to the right of the chat on its Plan pane (W2), and on a phone in a sheet over it (M3); the chat stays where it was.
9. **Given** the side panel is open, **When** they switch to Trip, Details, Map or Saved with the icon bar, **Then** that pane shows and the chat stays as it was.
6. **Given** the Plan pane, **Then** it shows the name, status, dates, adults and departure city, the match (with its hotel, flight and days parts), the total against the budget, the pace, and the tabs Days, Hotel, Flight, Car, Map and Costs, as the itinerary screens of spec 007 do.
7. **Given** the panel, **When** they choose Mark as planned, Share or close, **Then** the plan is marked planned, shared, or the panel closes.
8. **Given** the answer, **Then** up to three suggested next steps show as chips above the composer (M2); tapping one sends it.

---

### User Story 2 - Ask for any one thing (Priority: P1)

Fares asks "Cheap flights from Beirut in May", "Hotels near the centre", "Rent a car in Lisbon", "Top sights in
Paris", "What's on this weekend" or "Visa and weather for Istanbul". Each answer shows the matching cards: a flight
row, hotel or place photo cards, a car row, event cards, or travel facts, with their match % when the item is
ranked by their preferences.

**Why this priority**: The owner's rule: every feature must be reachable through the assistant, not only plans.

**Independent Test**: For each of the six kinds, a fake reply with that card kind renders as the design shows, opens
its details, and shows "See all" into the existing list screen with the same search.

**Acceptance Scenarios**:

1. **Given** a flights answer, **Then** each flight shows as a ResultRow: route and airline, date, times, stops, duration, price and match badge.
2. **Given** a hotels answer, **Then** hotels show as MediaCards: photo, match badge, bookmark, name, rating, area and distance, price per night, and "+" (add to plan).
3. **Given** a cars answer, **Then** each car shows as a ResultRow: car, supplier, pick-up and return, price and match.
4. **Given** a places answer, **Then** places show as MediaCards: photo, name, kind (sight, restaurant, park, nightlife), rating or price level, bookmark.
5. **Given** an events answer, **Then** events show as MediaCards: photo, name, date and time, venue, price when known, bookmark.
6. **Given** a travel-info answer, **Then** the facts show as short rows (weather, visa, currency, safety, holidays) under the text.
7. **Given** any card, **When** they tap it, **Then** its details open in the side panel's Details pane (a sheet on phones) and the chat stays; **When** they choose "See all N", **Then** the existing list opens with the same city, dates and preferences.
8. **Given** an item with no match computed, **Then** no badge shows rather than "0 %".

---

### User Story 3 - Change the plan by chatting (Priority: P2)

From the Plan pane Fares types "Ask to change this day…" ("swap the Palatine for something outdoors") or, in the
chat, "pick a cheaper hotel". The assistant changes the plan and the panel shows the new version. A "+" on a hotel or
car card adds or swaps it into the open plan; the swap icon on a day item asks the assistant for alternatives.

**Why this priority**: Building is P1; changing is what makes the plan the traveller's own, and it was TG-11's goal.

**Independent Test**: With a fake assistant that answers a change with an updated plan, ask from the panel; check the
panel shows the new days, total and match, and the chat shows the change as a tool step and a plan card.

**Acceptance Scenarios**:

1. **Given** an open plan, **When** they ask to change a day from the panel, **Then** the message goes to the chat with that plan and day as its subject, and the panel refreshes when the answer changes the plan.
2. **Given** a hotel or car card and an open plan, **When** they tap "+", **Then** that offer is swapped into (or added to) the plan, the panel shows it, and the chat says so.
3. **Given** a day item's swap icon, **When** they tap it, **Then** the chat asks the assistant for alternatives to that item; choosing one replaces it, and the day's times and walking distance are rebuilt.
4. **Given** "Ask to change this day…", **When** they ask to add or remove a place ("add a gelato stop", "drop the museum"), **Then** the day shows the change with its times rebuilt.
5. **Given** a change failed, **Then** the plan is unchanged and the chat explains why.

---

### User Story 4 - Find my way around: sidebar and drawer (Priority: P1)

On the web a sidebar (W1/W2) holds New trip chat, Search chats, Explore, My plans, Saved, the Recents list and the
account row. It can collapse. On a phone the same items are in a drawer opened from the top bar's menu (M5), and the
top bar shows the chat's title and a new-chat button.

**Why this priority**: It replaces the v0.2 floating nav; without it nothing else is reachable.

**Independent Test**: At desktop width the sidebar shows every item and collapses; at 390 px the drawer opens from
the menu, each item goes where it should, and the drawer closes after a choice.

**Acceptance Scenarios**:

1. **Given** the web layout, **Then** the sidebar shows the brand, New trip chat, Search chats, Explore, My plans, Saved, RECENTS with the latest chats, and the account row (name and pace) at the bottom; the current chat is highlighted.
2. **Given** the sidebar, **When** they press the panel button, **Then** it collapses to a slim rail and back.
3. **Given** a phone, **When** they tap the menu, **Then** the drawer (M5) opens with a "Search chats and plans" field, the same items, and the account row.
4. **Given** New trip chat (or the phone's new-chat icon), **Then** an empty assistant home opens and the previous chat stays in Recents.
5. **Given** Explore or My plans, **Then** the existing Discover and My plans screens open inside the new shell, until their v1.0 specs.
6. **Given** the account row, **Then** a menu offers Preferences and account (the existing profile screen), Appearance (System, Light, Dark) and Sign out.
7. **Given** the v1.0 shell, **Then** the floating nav, the web header and the plan dock of v0.2 are gone.

---

### User Story 5 - Come back to a chat (Priority: P2)

Fares planned Rome on their laptop. On their phone the next day, Recents shows "Rome in April for two"; opening it
shows the whole conversation with its cards, and they carry on. Search chats finds it by "Rome" or "jazz".

**Why this priority**: The design's sidebar is built around past chats; the owner chose to keep them on the server.

**Independent Test**: With a fake chats store, open a chat from Recents, check its messages and cards load, search
for a word in it, rename and delete a chat.

**Acceptance Scenarios**:

1. **Given** a signed-in traveller with past chats, **Then** Recents shows them, latest first, by title.
2. **Given** a new chat, **When** the first answer arrives, **Then** the chat gets a short title (e.g. "Rome in April for two") and appears in Recents.
3. **Given** a chat in Recents, **When** they open it, **Then** its messages and cards show as they were sent, and they can continue it.
4. **Given** Search chats, **When** they type a word, **Then** chats whose title or messages contain it show, and plans whose name contains it show in a second group.
5. **Given** a chat's ⋯ menu, **Then** they can rename or delete it; a deleted chat leaves Recents and is not found by search.
6. **Given** the same account on another device, **Then** the same Recents show.

---

### User Story 6 - Save what I like (Priority: P3)

Fares bookmarks a hotel, a place and an event from the chat. "Saved" in the sidebar lists them, grouped by kind,
and each opens its details. Asking "what did I save in Rome?" answers from the same list.

**Why this priority**: It is in the approved design and owner-approved for this step, but trips work without it.

**Independent Test**: Bookmark and un-bookmark a hotel card, open Saved, check it shows and opens; reload and check it
stays.

**Acceptance Scenarios**:

1. **Given** a hotel, place or event card, **When** they tap the bookmark, **Then** it fills and the item is in Saved; tapping again removes it.
2. **Given** Saved, **Then** the items show grouped by kind (Hotels, Places, Events) with their photo, name and city, newest first, and each opens its details.
3. **Given** nothing saved, **Then** Saved says how to save something.

---

### User Story 7 - Pick a tool on the phone (Priority: P2)

On a phone, the composer's "+" opens the tools sheet (M4): "What can I help with?" with Plan a trip, Flights, Hotels,
Car rental, Places, Events, Travel info and My preferences, plus "Set trip dates and travellers" and "Open a saved
plan".

**Why this priority**: It shows on a small screen everything the assistant can do.

**Independent Test**: At 390 px open the sheet, choose each tool and check it starts the right message or screen.

**Acceptance Scenarios**:

1. **Given** the sheet, **When** they choose a tool, **Then** the composer is filled with a starter for it (e.g. Flights → "Find flights from Beirut to Rome on 10 Apr") ready to edit and send, using the trip chip's values.
2. **Given** "Set trip dates and travellers", **Then** the trip editor opens and its result updates the trip chip.
3. **Given** "Open a saved plan", **Then** the latest plans show and choosing one opens it in the plan sheet.
4. **Given** "My preferences", **Then** the preferences editor opens; saved changes update the preferences chip.
5. **Given** the web composer's "+", **Then** the same tools show as a menu.

---

### User Story 8 - Theme v1, light and dark (Priority: P1)

Every screen of the app uses the v1.0 look: warm off-white background, sidebar tone, indigo primary, coral accent,
green match badges, the Newsreader serif for the greeting and headings, and Plus Jakarta Sans elsewhere. The app
follows the device's light or dark setting unless the traveller picks one.

**Why this priority**: The shell and cards are built from these tokens; screens not yet redesigned must not look broken
next to them.

**Independent Test**: Golden or widget checks of the shell, home, a chat with cards and each side-panel pane in light and
dark; switch Appearance and check it is kept after a restart.

**Acceptance Scenarios**:

1. **Given** the device in dark mode and Appearance on System, **Then** the app shows the dark tokens (W2 Dark, M2 Dark).
2. **Given** Appearance set to Light or Dark, **Then** that choice wins over the device and is kept on this device.
3. **Given** a v0.2 screen not yet redesigned (e.g. Discover), **Then** it uses the v1 colours and fonts and stays readable in both modes.

### Edge Cases

- **Assistant busy, not configured or rate-limited** (spec 003 FR-007, FR-008, FR-015): the warning shows in the chat with Try again; the shell keeps working.
- **A tool step failed** (a source down, no key, hotels quota used): its line says so ("Hotels unavailable right now") and the rest of the answer still shows.
- **Long answer with many cards**: hotel and place cards scroll sideways in one row; at most 3 of a kind show, then "See all N".
- **Side panel on a narrow web window**: under the wide breakpoint the panel's panes open in a sheet, as on phones.
- **Details of an item that is gone** (a hotel no longer offered, an event over): the Details pane shows what was found then, says it may no longer be available, and offers to search again.
- **Plan deleted elsewhere**: a plan card whose plan is gone says "This plan was deleted" and Open plan is disabled.
- **Plan changed elsewhere**: the panel always shows the latest saved version, not the one in the old message.
- **Reopened chat with old prices**: cards show what was found then, with "Found on 9 Nov"; tapping a card or See all searches again.
- **Signed out**: the shell is not shown; the sign-in screens of spec 006 are. Recents and Saved belong to the account.
- **No chats yet**: Recents is hidden; Search chats says there is nothing to search yet.
- **No plans yet**: "Pick up where you left off" is hidden.
- **Card kind the app doesn't know** (newer API): skipped, the text still shows (as spec 003).
- **Old chats**: a chat with no new message for 90 days is deleted by the server; it leaves Recents and search. A chat opened from an old link after that shows "This chat has expired" and New trip chat. Plans built in it are not deleted.
- **Offline or API down when loading Recents**: the sidebar shows its items and "Couldn't load your chats · Try again"; New trip chat still works.

## Requirements *(mandatory)*

### Functional Requirements

**Shell**

- **FR-001**: On wide screens (from the existing wide-layout breakpoint) the app MUST show the W1/W2 sidebar: brand, collapse button, New trip chat, Search chats, Explore, My plans, Saved, RECENTS, and the account row. The sidebar MUST collapse to a rail and expand again.
- **FR-002**: On narrow screens the app MUST show the M1/M2 top bar (menu, chat title with a chevron, new chat) and the M5 drawer with the same items and a "Search chats and plans" field.
- **FR-003**: The assistant MUST be the app's first screen after sign-in, replacing Discover.
- **FR-004**: The v0.2 floating nav, web header and plan dock MUST be removed. Every existing screen MUST stay reachable: Explore opens Discover (and from it the destination, places, flights, hotels, cars and Plan your trip screens); My plans opens My plans; the account menu opens the profile.
- **FR-005**: Existing deep links (`/discover/...`, `/plans/...`, `/profile`) MUST keep working inside the new shell.

**Theme**

- **FR-006**: The app MUST use the v1.0 tokens for light and dark exactly as the Figma variables define them (bg/app, bg/sidebar, bg/surface, bg/subtle, bg/hover, border/default, text primary/secondary/tertiary, brand primary/primary-soft/on-primary/accent/accent-soft, status success/success-soft/warning/warning-soft), and the "Shadow raised" effect.
- **FR-007**: The app MUST use the v1 text styles: Serif title (Newsreader Medium 22/28, −0.5) for the greeting, chat and plan titles; Title, Body, Body strong, Small, Small strong and Micro in Plus Jakarta Sans. Both fonts MUST be bundled with the app, not fetched at run time.
- **FR-008**: The app MUST follow the device's light or dark setting and offer Appearance (System, Light, Dark) in the account menu; the choice MUST be kept on the device.
- **FR-009**: Screens not redesigned in this step MUST use the v1 tokens so they read correctly in both modes.

**Assistant home and composer**

- **FR-010**: The home MUST show the assistant mark, "Where to next, {first name}?", the composer, suggestions, "Pick up where you left off" (the two latest plans with Open plan, and All plans), and the line "TravelGenie checks prices with live sources. Prices can change before you book."
- **FR-011**: The suggestions MUST cover every feature: plan a trip, flights, hotels, car rental, places, events and travel info (W1 shows seven chips; M1 four cards that scroll).
- **FR-012**: The composer MUST show a trip chip (city · dates · adults) and a preferences chip (top two interests · pace). Tapping a chip MUST open its editor; the values MUST be sent with each message as the trip context and preferences. A chip with no value MUST say "Add trip" or "Add preferences".
- **FR-013**: The trip chip MUST start from the traveller's latest plan or last chat trip, and the preferences chip from their saved profile preferences and pace (pamplemousse spec 009).
- **FR-014**: The Gemini notice of spec 003 FR-014 MUST stay visible near the composer.

**Answers**

- **FR-015**: While the assistant works, the chat MUST show each tool it runs as a ToolStep line (icon, what it did, a short result), in order, as each tool finishes, with a working indicator after the last one. The text and cards MUST show when the answer is complete; the text is not streamed word by word. If the stream breaks, the steps already shown MUST stay and the error MUST show with Try again.
- **FR-016**: The reply MUST render, in order: tool steps, the text, then cards grouped by kind with a Micro label ("BEST FLIGHT FOR YOU", "HOTELS THAT FIT YOU BEST"), then the next-step chips.
- **FR-017**: The app MUST render these card kinds from the data in the reply, without another request: plan (PlanCard), flight (ResultRow), hotel (MediaCard), car (ResultRow), place (MediaCard), event (MediaCard), travel facts (rows). Each ranked item MUST show its match badge ("92% match"); its reason MUST show on tap or hover.
- **FR-018**: Each card MUST open its details in the side panel's Details pane (FR-019); each group MUST offer "See all N" into the existing list screen with the same search.
- **FR-019**: The app MUST have a side panel to the right of the chat on wide screens, and the same content in a sheet over the chat on narrow screens (and on web below the wide breakpoint). An icon bar at its top MUST switch between five panes, with close; the chat MUST stay visible and scrollable beside it on wide screens. The panel opens on the pane the traveller asked for (a card → Details, a plan card → Plan) and remembers the last pane per chat.
  - **Trip**: the chat's trip (city, dates, adults, departure city), preferences, pace and trip budget, each editable in place (the same values as the composer chips, FR-012); below them, this chat's outputs: plans built, items found by kind with their counts, and items saved, each opening its pane.
  - **Plan**: the plan as spec 007's itinerary shows it and as W2 draws it (summary tiles, Days/Hotel/Flight/Car/Map/Costs tabs, day chips, day items with their swap icon), with Share, ⋯, "Ask to change this day…" and Mark as planned.
  - **Details**: the tapped hotel, flight, car, place or event, with the content of today's details screens, its match and reason, the bookmark (hotels, places and events only, FR-027), and "Add to plan" (or "Swap into plan").
  - **Map**: everything found in this chat and the open plan's days, as pins by kind; tapping a pin opens it in Details.
  - **Saved**: the account's saved items (FR-028).
- **FR-020**: The app MUST show the assistant's next-step suggestions as chips above the composer; tapping one MUST send it.
- **FR-021**: A "+" on a hotel or car card MUST add it to or swap it into the plan open in the panel, or the chat's latest plan; with no plan it MUST ask to build one.
- **FR-022**: "Ask to change this day…" MUST send the message to the chat with the plan and day it is about; when the reply changes the plan, the panel MUST show the new version.
- **FR-022a**: The swap icon on a day item MUST ask the assistant for alternatives to that item. Through the chat, the traveller MUST be able to replace, add or remove a day's place, restaurant or event; the days, total and match MUST then be rebuilt by the API.

**Chats (server-side)**

- **FR-023**: Every chat of a signed-in traveller MUST be saved on the server with its messages, cards and tool steps, and MUST be listed in Recents, latest first.
- **FR-024**: A chat MUST get a short title from its first exchange; the traveller MUST be able to rename and delete it.
- **FR-024a**: The server MUST delete a chat 90 days after its last message, and MUST NOT log chat text. Recents MUST say once, in its footer, "Chats are kept for 90 days."
- **FR-025**: Search chats MUST find chats by words in their title or messages, and plans by name.
- **FR-026**: Opening a chat MUST show it as it was and let the traveller continue it; the assistant MUST answer with that chat's history.

**Saved**

- **FR-027**: Hotel, place and event cards MUST have a bookmark that saves or removes the item for the account.
- **FR-028**: Saved (from the sidebar, or the panel's Saved pane) MUST list the saved items grouped by kind, newest first, each opening in the Details pane; the assistant MUST be able to answer from them.

**Tools sheet**

- **FR-029**: On narrow screens the composer's "+" MUST open the M4 tools sheet with Plan a trip, Flights, Hotels, Car rental, Places, Events, Travel info, My preferences, "Set trip dates and travellers" and "Open a saved plan". On wide screens "+" MUST open the same items as a menu. "Attach a photo or booking" and "Use my location" MUST NOT show.
- **FR-030**: A tool MUST fill the composer with an editable starter message for it, built from the trip chip; it MUST NOT send by itself.

**States** (constitution V)

- **FR-031**: Recents, Saved, "Pick up where you left off" and every side-panel pane MUST show placeholder boxes while loading, the error with Try again on failure, and a short message when empty.

### Key Entities

- **Chat**: belongs to one traveller; title, created and last-message times, its trip context, its messages. Saved on the server.
- **Message**: role, text, the tool steps and cards of an assistant reply, the next-step suggestions, warnings, time.
- **Tool step**: which tool ran, a one-line summary, whether it worked, and the cards it produced.
- **Card**: a kind (plan, flight, hotel, car, place, event, travel facts) and the item's own data as the list endpoints return it, with its match when ranked; for plan, the plan summary of `GET /plans` and its id.
- **Saved item**: kind (hotel, place, event), the item's id, name, city, photo, and when it was saved.
- **Trip context and preferences**: city, dates, adults, departure city, passport, currency; the six preferences, pace and trip budget (pamplemousse specs 007–009).

## Backend dependencies

This spec needs a pamplemousse "assistant v2" spec, approved before this spec's plan. What each card needs:

| App card / feature | Assistant tool it needs | Data in the reply | Exists today? |
|---|---|---|---|
| Flight ResultRow | `search_flights` ranked by preferences | flight list item of spec 001 with `match` (spec 007) | Tool exists, unranked; reply has a link card only |
| Hotel MediaCard | `search_hotels` ranked | hotel list item with photo, rating, area, distance, price per night, `match` | Tool exists, unranked; link card only |
| Car ResultRow | `search_cars` ranked | car list item (spec 004) with `match` | **No tool** |
| Place MediaCard | `list_places` (attraction, restaurant, nature, nightlife) | place item with photo, kind, rating/price level | Tool exists; link card only |
| Event MediaCard | `list_events` | event item with photo, date, venue, price, url | Tool exists; returned as an `overview` card only |
| Travel facts rows | `get_overview` | weather, visa, currency, safety, holidays summary | Tool exists; link card only |
| Plan card and panel | `build_plan`, `list_plans`, `get_plan` | plan summary (`GET /plans` item) and plan id | **No tool** (routes exist, spec 008) |
| Change by chat, "+" on a card | `swap_offer` (hotel, flight, car), `remove_car` | updated plan summary | Swap routes exist; **no tools** |
| Day edits (swap icon, "Ask to change this day…") | `suggest_day_alternatives`, `change_day_item` (replace, add, remove) | alternatives as place/event cards; updated plan | **No route and no tool** |
| Mark as planned, rename | `update_plan` | plan summary | Route exists; **no tool** |
| Preferences chip, "I care more about food" | `get_preferences`, `update_preferences` | the six preferences and pace | `/me` exists; **no tool** |
| Saved | `list_saved`; save/remove routes | saved hotels, places and events | **Nothing** |
| Map pane | — | latitude and longitude on every hotel, place, event and car pick-up card | Partly: plan items have them; check each list item |
| ToolStep lines | — | per tool: name, summary, ok/failed, cards; streamed as they happen | **Not in the reply**; no streaming |
| Next-step chips | — | 0–3 suggestions | **Not in the reply** |
| Recents, Search chats, reopen | — | chats stored per account: create, list, get, rename, delete, search; the reply takes a chat id instead of resending 20 messages | **Nothing**: server stores no chat (spec 003 FR-010) |

Also for the backend spec to settle: whether chat text may now be stored (spec 003 FR-010 and the constitution's
personal-data rule; the owner chose a 90-day retention after the last message), the assistant rate limits per account rather
than per IP, and the hotels quota when many chats search hotels.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each of the 8 features (plan a trip, flights, hotels, cars, places, events, travel info, preferences) can be reached from the assistant home in one message or one tool from the "+" sheet, and its answer shows its own card kind (8 of 8).
- **SC-002**: A traveller can go from the home to an open plan in the panel with one message and one tap.
- **SC-003**: Every existing screen of v0.2 is still reachable from the new shell in at most 2 taps (Explore, My plans, account).
- **SC-004**: A chat started on one device appears in Recents on another device of the same account within 5 seconds of opening the sidebar.
- **SC-005**: When the assistant uses a tool, its first step line shows within 3 seconds of sending, and no more than 5 seconds pass without a new step or the answer.
- **SC-006**: The shell, home, chat with every card kind, side panel and tools sheet match the approved frames at 390 px and 1440 px, in light and dark, as checked by the owner.
- **SC-007**: Text and badges meet a 4.5:1 contrast ratio in both modes.

## Assumptions

- The traveller is signed in (spec 006); the shell, chats and Saved are per account.
- The Plan and Details panes reuse the itinerary screens of spec 007 (branch `007-itinerary-screens`), which merges before this is built, and the details screens of specs 001–005.
- The assistant v2 backend spec is written next and approved before this spec's plan; the reply contract is defined there, and this spec only says what the app shows.
- Newsreader is bundled like Plus Jakarta Sans (both open-source, no cost).
- Icons follow the design's Lucide-style set; the exact icon source is a plan decision.
- English only, as today.
- The Explore, My plans and Preferences screens are restyled with tokens only in this step; their v1.0 layouts come in their own specs.
