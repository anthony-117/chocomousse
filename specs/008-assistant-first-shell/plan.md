# Implementation Plan: Assistant-first shell (design v1.0, step 1)

**Branch**: `008-assistant-first-shell` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

**Status**: Approved by the owner on 2026-11-10. The owner also confirmed: the web stream through `dart:js_interop`
(R-1), the danger red kept from v0.2 with a dark variant, to be added to the v1 Figma variables (R-3), and the
generic AI notice (R-8)

**Backend**: pamplemousse spec 010 "assistant v2", approved with its plan on 2026-11-10 (PR anthony-117/pamplemousse#23,
commit `def4c72`). The app follows its contracts exactly:
[assistant-v2-api.md](https://github.com/anthony-117/pamplemousse/blob/010-assistant-v2/specs/010-assistant-v2/contracts/assistant-v2-api.md)
(chats, the SSE stream, cards),
[plan-edits-api.md](https://github.com/anthony-117/pamplemousse/blob/010-assistant-v2/specs/010-assistant-v2/contracts/plan-edits-api.md)
(day edits, rebuild) and
[saved-api.md](https://github.com/anthony-117/pamplemousse/blob/010-assistant-v2/specs/010-assistant-v2/contracts/saved-api.md).

## Summary

The work turns the app into an assistant first:

- **Theme v1**: light and dark tokens as a theme extension, Newsreader for the serif styles, Lucide-style SVG icons, and
  Appearance (System, Light, Dark) kept on the device. Every existing screen moves from the fixed `AppColors` to the
  theme.
- **Shell**: one `AppShell` with the W1 sidebar on wide screens and the M1 top bar and M5 drawer on phones. It replaces
  the four-tab shell, the floating nav and the web header. The assistant home becomes `/`.
- **Chats**: a new data layer for the chat routes and the SSE stream. Each step line shows as it arrives, then the
  answer with its cards and suggestions. Chats are listed in Recents and found with Search chats.
- **Cards**: the seven card kinds, parsed with the existing list parsers and drawn with new v1 card widgets.
- **Side panel**: panes Trip, Plan, Details, Map and Saved, beside the chat on wide screens and in a sheet on phones.
  The Plan pane reuses the 007 itinerary views (PR anthony-117/chocomousse#18). The Map pane is a pin preview.
- **Saved**: bookmarks on hotel, place and event cards, the Saved pane, and the Saved entry in the sidebar.
- **Tools sheet**: M4 on phones, a menu on the web.

## Technical Context

**Language/Version**: Flutter 3.47.0, Dart 3.13.0

**Primary Dependencies**: Riverpod 3, go_router, dio, flutter_svg, as today. One new package, approved by the owner on
2026-11-10: `shared_preferences`, for Appearance. On the web, the stream is read with the browser's `fetch` through the
SDK's `dart:js_interop`; this adds no package (see research R-1).

**Storage**: on the device, only the Appearance choice. Chats, saved items and plans live in the API.

**Testing**: `flutter_test` and `mocktail`. The API is a fake dio adapter, as in the other features; the stream is a
fake `ChatTransport` that yields scripted events. Widget tests run at 390 px and 1440 px, in light and dark. Flow
tests in `test/flows/`.

**Target Platform**: Web and Android (iOS builds, not demoed).

**Project Type**: Flutter mobile and web app (`lib/features/...`), against the pamplemousse API.

**Performance Goals**: each step line shows within 100 ms of its event arriving (SC-005 depends on the API's
timing). Recents and Search answer in under 1 s on a normal connection. Scrolling a chat with 30 messages and their
cards stays at 60 fps on a mid-range Android phone.

**Constraints**: $0. No direct third-party calls (constitution VI): the pin preview needs no tiles or keys. The
stream has no receive time-out (the server pings every 10 s); a gap of 30 s without a byte ends it with the error
and Try again. Chat text is never logged (constitution, FR-024a).

**Scale/Scope**: about 12 new screens, panes and sheets, and 7 card widgets. A theme migration across 46 files
(261 uses of `AppColors`). A chat holds up to 200 messages; Recents loads 30 at a time.

## Constitution Check

| Principle | How the plan meets it | Result |
|---|---|---|
| I Feature-First | New `features/chat/` (replaces `features/assistant/`), `features/saved/`, `features/side_panel/`; the shell stays in `features/shell/`; the theme in `lib/app/theme/`; shared card widgets in `lib/core/widgets/cards/`, as Explore will use them too. API calls only in `data/` | Pass |
| II Tested | Unit: SSE parser, every card kind and stream event, chat/saved/plan-edit repositories with each error code, the chat controller (every event order, the error event, a broken stream, 409/429), Appearance. Widget: shell at both widths, home, chat states, each card, each pane, tools sheet, drawer, Recents, Search, Saved, in light and dark. Flows: see quickstart | Pass |
| III Zero Lint | Normal gate. The web transport's `dart:js_interop` code is behind a conditional import and analysed on both platforms | Pass |
| IV Design First | v1.0 Web, Mobile and Design system pages, approved 2026-11-10. Side panel frames: section "Spec 008 · Side panel (approved 2026-11-10)", logged in `figma-links.md`. Loading, empty and error states are built from the layouts and tokens, and the PR says so | Pass |
| V Never a Blank Screen | Skeletons for Recents, Search, Saved, Pick up where you left off, the Plan and Details panes and a reopened chat. Errors keep the layout and offer Try again. The stream's error keeps the steps already shown. No automatic retries (`noRetry`) | Pass |
| VI Backend Only | Only `/api/v1` of pamplemousse: assistant chats, plans, saved, me, and the existing list and details routes. The web stream reader calls the same API with the same token | Pass |
| VII Low Cost | No paid service. The pin preview needs no map key or billing card | Pass |
| VIII Simplicity | One new package, approved. One `ChatController` per chat; one `SidePanelController`; the old `features/assistant` is removed, not kept beside the new one | Pass |

Post-design re-check (after Phase 1): unchanged, all Pass. One item is in Complexity Tracking: two stream transports
behind one interface.

## Design decisions

The reasons are in [research.md](research.md). The entities and their fields are in [data-model.md](data-model.md).
How the app uses each route is in [contracts/app-api-usage.md](contracts/app-api-usage.md).

1. **Theme v1** (`lib/app/theme/`), R-3:
   - `tokens.dart` keeps the spacing and radius scales (checked against the v1 design system) and drops `AppColors`.
   - `palette.dart` defines `AppPalette extends ThemeExtension`, with const `light` and `dark` instances holding the
     21 Figma colour variables. It adds `danger` and `dangerSoft`, which the v1 file lacks (R-3), and the
     `raisedShadow`.
   - `context.palette` reads it.
   - `app_theme.dart` builds `light()` and `dark()` from the palette. The v1 text styles map onto Material slots;
     `AppText` gives them their design names (`serifTitle`, `title`, `body`, `bodyStrong`, `small`, `smallStrong`,
     `micro`) and a `greeting` style (Newsreader, sized from W1).
   - Every `AppColors.x` use is replaced by its palette token, using the table in R-3. This is one mechanical commit
     per feature folder.
2. **Fonts and icons**:
   - Newsreader Medium (OFL) is added to `assets/fonts` and `pubspec.yaml` beside Plus Jakarta Sans.
   - The 37 v1 icons are exported from the design system page as SVGs to `assets/icons/`. `AppIcon(AppIcons.plane)`
     draws them with `flutter_svg`, tinted with the current text colour (R-4).
3. **Appearance**:
   - `appearanceProvider` is a `Notifier<ThemeMode>` that reads and writes `shared_preferences` key `appearance`
     (`system`, `light` or `dark`; default `system`).
   - `MaterialApp.router` gets `theme`, `darkTheme` and `themeMode`.
   - The account menu has a three-way choice.
4. **Routes** (`lib/app/router.dart`), R-5:
   - `StatefulShellRoute` and `AppTab` give way to one `ShellRoute` with `AppShell`.
   - Inside it:
     - `/`: the home and a new chat.
     - `/chat/:chatId`: a chat.
     - `/saved`: opens the home with the Saved pane.
     - `/discover/...` (Explore) and `/plans/...` (My plans): unchanged.
     - `/profile` and `/profile/edit`.
   - Redirects: `/assistant` goes to `/`, and the sign-in redirect goes to `/` instead of `/discover`.
   - Deep links of v0.2 keep working (FR-005).
5. **Shell** (`features/shell/`):
   - `AppShell` switches at `kWideLayoutBreakpoint`.
   - Wide screens: a `Sidebar` of 272 px that collapses to a 64 px rail. Its parts:
     - brand and collapse button
     - New trip chat, Search chats, Explore, My plans and Saved, as `SidebarItem`s
     - Recents
     - the account row
     - The collapsed state is kept for the session.
   - Narrow screens: a `TopBar` (menu, the chat title with chevron, new chat) and a `Drawer` of 312 px with the
     same items and a search field.
   - The account row opens `AccountMenu`: Preferences and account (the profile), Appearance, Sign out.
   - `floating_nav.dart` and `web_header.dart` are deleted.
6. **Chats data** (`features/chat/data/`), R-1 and R-2:
   - `ChatRepository` covers:
     - `list(before)`, `get(id)`, `rename`, `delete`, `search(q)`
     - `send(chatId?, ChatRequest) → Stream<ChatEvent>`
   - `send` refuses before the stream with typed failures: `ChatBusy`, `ChatFull`, `ChatNotFound` (also expired),
     `TooManyMessages(retryAfter)`, `FieldError`.
   - The stream goes through a `ChatTransport` interface:
     - `IoChatTransport`: dio with `ResponseType.stream`.
     - `WebChatTransport`: `fetch` and a `ReadableStream` reader through `dart:js_interop`.
     - A conditional import picks one.
   - Both feed `SseDecoder` (pure Dart, line-based, ignores `: ping` comments) and then `ChatEvent.fromSse`.
7. **Cards** (`features/chat/data/cards.dart`):
   - `sealed class AssistantCard` with `PlanCard`, `FlightCard`, `HotelCard`, `CarCard`, `PlaceCard`, `EventCard`
     and `FactsCard`. Every card keeps the envelope (`id`, `lat`, `lng`, `approximate`, `foundAt`).
   - Items are parsed with the existing parsers (`FlightFare`, `HotelOffer`, `CarOffer`, `Place`, `TravelEvent`,
     `PlanSummary`) plus `Match`. Unknown kinds are skipped, and so are cards that fail to parse; the answer's text
     still shows.
8. **Chat state** (`features/chat/application/`):
   - `chatProvider(chatId)` is a `ChatController` notifier holding `ChatState`: messages, the pending turn (its
     steps so far), status, title and error.
   - `send` appends the traveller's message at once and opens the stream:
     - `chat` sets the id. For a new chat, it replaces `/` with `/chat/{id}` without rebuilding.
     - each `step` is appended to the pending turn.
     - `final` turns the pending turn into a message, sets the title, refreshes Recents and, when `planChanged` is
       set, invalidates `planProvider(planChanged)`.
   - `error`, a broken stream or a 30 s silence keep the steps and mark the message "not sent", with Try again.
   - A reopened chat with `busy: true` shows the working state and reloads every 5 s. The constitution's no-retry
     rule is about failed requests; this is a poll for a known-running answer, and it stops after 60 s.
   - `recentsProvider` (paged), `chatSearchProvider(q)` (300 ms debounce, 2+ characters) and `chatTripProvider`: the
     composer's trip, preferences and pace. The trip starts from the latest chat's trip or plan (FR-013); the
     preferences and pace from the profile.
9. **Chat UI** (`features/chat/presentation/`):
   - `AssistantHome` (W1, M1): greeting, `Composer`, suggestion chips, Pick up where you left off, footer line.
   - `ChatScreen` (W2, M2): message list with `UserBubble`, `ToolStepLine` (expandable to its cards),
     `AnswerText`, `CardGroup`s with Micro labels and "See all N", `SuggestionChips`.
   - `Composer`: the trip and preferences chips, which open `TripEditorSheet` and `PreferencesSheet`. Both reuse the
     ranking feature's controls.
   - The AI notice of spec 003 FR-014 stays under the composer. Its wording is generic, because the provider is now a
     setting (R-8).
   - "See all N" opens the existing list route with the card's search (city, dates, preferences).
10. **Card widgets** (`lib/core/widgets/cards/`): `MatchBadge`, `MediaCard` (hotel, place, event), `ResultRow`
    (flight, car), `PlanCardTile`, `FactsRows`, `DayItemTile`, `ChipButton`. They are drawn from the v1 component
    symbols. A card shows no badge when `match` is null.
11. **Side panel** (`features/side_panel/`), R-6:
    - `SidePanelController` keeps per chat (and for the home): open or closed, the pane, the selected card and the
      plan id.
    - Wide screens: the panel sits beside the chat in a `Row`, 520 px (W2), with the `PanelIconBar`.
    - Narrow screens, and web below the breakpoint: a modal `DraggableScrollableSheet` with the same icon bar.
    - The panes:
      - **Trip**: editable trip, preferences, pace and budget (the composer's state), Rebuild plan
        (`POST /plans/{id}/rebuild`), and this chat's outputs, from the cards of its messages.
      - **Plan**: the 007 itinerary as an embeddable `ItineraryView` (a refactor of `ItineraryScreen`, which keeps
        its route). Tabs Days, Hotel, Flight, Car, Map and Costs. The day items' swap icon sends an `about` message
        (FR-022a). The bar "Ask to change this day…" and Mark as planned.
      - **Details**: per kind:
        - hotels: `HotelDetailsView`, refactored out of the screen.
        - cars: `CarDetailsView` from the card's `CarOffer`.
        - OpenTripMap places: `PlaceDetailsView`.
        - flights, events and Wikidata sights: new compact views from the card's data.
        - every kind gets the match and reason; hotels, places and events get the bookmark; there is Add to plan /
          Swap into plan.
        - a card older than its search shows "Found on …" and Search again.
      - **Map**: `PinPreview` places the cards' pins by kind on a plain canvas fitted to their bounds, with a list
        under it. A tap opens Details. `approximate` pins are hollow. The Plan pane's Map tab reuses it.
      - **Saved**: see 12.
12. **Saved** (`features/saved/`):
    - `SavedRepository`: `save(card)`, `remove(kind, id)`, `list(kind?, destinationId?)` and `ids()`.
    - `savedIdsProvider` drives every bookmark. A tap changes it at once and reverts with a snack bar if the call
      fails.
    - `savedProvider` drives the pane: Hotels, Places, Events, newest first. Empty: "Tap the bookmark on a hotel,
      place or event to keep it here."
13. **Plan edits** (`features/itinerary/data/`, extending 007):
    - The repository gains `dayAlternatives`, `addOrReplaceItem`, `removeItem` and `rebuild`.
    - `Plan` gains `edits`, and `PlanSummary` gains the six fields of spec 010.
    - The app does not call these routes directly. The swap icon asks the assistant (FR-022a), and the panel only
      calls rebuild. They are there for the API and the tests, and for direct controls later.
    - "+" on a hotel or car card swaps it into the open plan (`PUT /plans/{id}/{kind}`). Without an open plan, it
      sends "Build a plan with this hotel" (FR-021).
14. **Tools sheet** (`features/chat/presentation/tools_sheet.dart`):
    - M4's eight tools and two rows. Each tool fills the composer with a starter built from the trip
      (`ToolStarter`), and never sends.
    - "Set trip dates and travellers" opens `TripEditorSheet`; "Open a saved plan" lists the latest plans; My
      preferences opens `PreferencesSheet`.
    - On the web, "+" opens the same entries as a `MenuAnchor`.
15. **Removed**: `features/assistant/`, along with its route, models, `card_opener.dart`, and the spec 003 endpoint
    calls. Its tests move or are rewritten for the chat feature.

## Delivery order

All on this branch, in one PR, so that main never shows half a shell. Each step keeps the app working and its tests
green.

1. Theme v1, fonts, icons and Appearance, with the `AppColors` migration. Screens look v1, and the layout is
   unchanged.
2. Shell and routes: sidebar, drawer, top bar and account menu. The home is a placeholder until step 3.
3. Chat data and the stream (both transports), then the home and chat screens with step lines and all card widgets.
4. Side panel: Plan and Details first, then Trip, Map and Saved.
5. Saved bookmarks.
6. The tools sheet and menu.
7. Flow tests, then a check in the running app at 390 px and 1440 px in light and dark, against a local pamplemousse
   on `010-assistant-v2`.

**Merge order**: chocomousse PR #18 (007) first; this branch is then rebased on main. Live checks need pamplemousse
spec 010 deployed. Before that, everything runs against fakes.

## Project Structure

### Documentation (this feature)

```text
specs/008-assistant-first-shell/
├── spec.md
├── plan.md               # this file
├── research.md           # R-1 … R-8
├── data-model.md         # app models of the v2 contracts
├── quickstart.md         # how to check it works
├── contracts/
│   └── app-api-usage.md  # which route each screen uses, and how failures show
└── checklists/requirements.md
```

### Source Code (repository root)

```text
lib/
├── app/
│   ├── router.dart                    # ShellRoute, / and /chat/:id, redirects
│   └── theme/
│       ├── tokens.dart                # spacing, radii, breakpoint (AppColors removed)
│       ├── palette.dart               # AppPalette light/dark (ThemeExtension), context.palette
│       ├── app_text.dart              # v1 text styles
│       ├── app_icons.dart             # AppIcon + AppIcons (SVG)
│       ├── appearance.dart            # ThemeMode provider (shared_preferences)
│       └── app_theme.dart             # light() and dark()
├── core/widgets/cards/                # MatchBadge, MediaCard, ResultRow, PlanCardTile, FactsRows, DayItemTile, PinPreview
├── features/
│   ├── shell/                         # AppShell, Sidebar, Drawer, TopBar, AccountMenu, Recents, SearchChats
│   ├── chat/
│   │   ├── data/                      # chat_models, cards, chat_events, sse_decoder, chat_transport{,_io,_web}, chat_repository
│   │   ├── application/               # chat_controller, recents, chat_search, chat_trip, tool_starters
│   │   └── presentation/              # assistant_home, chat_screen, composer, tool_step_line, card_group, tools_sheet, trip_editor_sheet, preferences_sheet
│   ├── side_panel/
│   │   ├── application/               # side_panel_controller
│   │   └── presentation/              # side_panel, panel_icon_bar, trip_pane, plan_pane, details_pane, map_pane, saved_pane
│   ├── saved/                         # data/, application/ (saved, savedIds), presentation/ (bookmark_button, saved_list)
│   ├── itinerary/                     # from 007: + day edits, rebuild, ItineraryView
│   └── hotels, cars, destination/     # details screens split into *DetailsView + screen
assets/
├── fonts/Newsreader-Medium.ttf (+ OFL)
└── icons/*.svg                        # 37 v1 icons

test/
├── app/theme/                         # palette, appearance
├── features/chat/ … side_panel/ … saved/ … shell/
└── flows/                             # assistant_first_flow, recents_search_flow, saved_flow, explore_from_shell_flow
```

**Structure Decision**: a feature-first Flutter app, as today (constitution I). `chat` replaces `assistant`
because the feature is now chats, not one screen. The side panel is its own feature, as both the chat and the home
open it.

## Complexity Tracking

| Item | Why needed | Simpler alternative rejected because |
|---|---|---|
| Two stream transports (dio on Android/iOS, `fetch` through `dart:js_interop` on the web) behind `ChatTransport` | dio's web adapter delivers the body only when the whole response has loaded (`dio_web_adapter` 2.2.2, `onLoad`), so the steps would not be live on the web, the main demo platform | One dio transport: no live steps on the web, which breaks FR-015 there. `package:web` as a direct dependency: not approved by the owner on 2026-11-10 |
