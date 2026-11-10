# Tasks: Assistant-first shell (design v1.0, step 1)

**Input**: the design documents in `specs/008-assistant-first-shell/`: [spec.md](spec.md), [plan.md](plan.md),
[research.md](research.md), [data-model.md](data-model.md), [contracts/app-api-usage.md](contracts/app-api-usage.md)
and [quickstart.md](quickstart.md). The API contracts are pamplemousse spec 010's
(`../pamplemousse/specs/010-assistant-v2/contracts/` on branch `010-assistant-v2`).

**Tests**: required by the constitution (principle II). Every model, repository and provider gets unit tests; every
screen and widget gets widget tests for its loading, data, empty and error states at 390 px and 1440 px, in light and
dark. New journeys get flow tests in `test/flows/`. Tests never call the internet: use a fake dio adapter, or the fake
`ChatTransport` (T020).

**Before starting**: chocomousse PR #18 (`007-itinerary-screens`) is merged and this branch is rebased on main
(T001). Gates for every task: `flutter analyze --fatal-infos` and `dart format --set-exit-if-changed lib test` (line
length 120).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the spec's user story (US1–US8)

Story map (spec.md):

| Story | Title | Priority |
|---|---|---|
| US1 | Plan a trip by asking | P1 |
| US2 | Ask for any one thing | P1 |
| US3 | Change the plan by chatting | P2 |
| US4 | Sidebar and drawer | P1 |
| US5 | Come back to a chat | P2 |
| US6 | Save what I like | P3 |
| US7 | Pick a tool on the phone | P2 |
| US8 | Theme v1, light and dark | P1 |

---

## Phase 1: Setup

- [X] T001 Rebase `008-assistant-first-shell` on main after PR #18 merges; check `lib/features/itinerary/` exists, and that `flutter test` passes before any change
- [X] T002 Add `shared_preferences` (latest stable) to `pubspec.yaml` dependencies, with a comment "Appearance choice on the device (spec 008 FR-008, approved 2026-11-10)"; run `flutter pub get`
- [X] T003 [P] Download Newsreader Medium (OFL, Google Fonts) to `assets/fonts/Newsreader-Medium.ttf`; append its OFL notice to `assets/fonts/OFL.txt`; declare family `Newsreader` (weight 500) in `pubspec.yaml`
- [X] T004 [P] Export the 37 icon symbols of Figma "v1 / Icons" (file `s52ShmznT28QgNN6u6Wddu`, node 2301:923) as 24×24 SVG, stroke `currentColor`, to `assets/icons/<name>.svg` (plus, arrow-up, mic, search, new-chat, compass, map, plane, bed, car, landmark, ticket, globe, sliders, sparkles, chevron-down, chevron-right, check, swap, calendar, users, menu, panel-left, paperclip, sun, bookmark, pin, share, x, clock, wallet, more, user, thumbs-up, copy, filter, bookmark-filled); register `assets/icons/` in `pubspec.yaml`

---

## Phase 2: Foundational (blocks every story)

### Theme tokens and text (needed by every widget)

- [X] T005 Create `lib/app/theme/palette.dart`:
  - `AppPalette extends ThemeExtension<AppPalette>` with fields `bgApp`, `bgSidebar`, `bgSurface`, `bgSubtle`, `bgHover`, `borderDefault`, `textPrimary`, `textSecondary`, `textTertiary`, `brandPrimary`, `brandPrimarySoft`, `brandOnPrimary`, `brandAccent`, `brandAccentSoft`, `statusSuccess`, `statusSuccessSoft`, `statusWarning`, `statusWarningSoft`, `statusDanger`, `statusDangerSoft` and `raisedShadow` (`List<BoxShadow>`), with `copyWith` and `lerp`.
  - `static const light`: `#FAF9F6`, `#F2F0EA`, `#FFFFFF`, `#EFEDE6`, `#E8E5DD`, `#E5E2DA`, `#1D1C1A`, `#6F6B63`, `#9A968D`, `#4338CA`, `#ECEBFA`, `#FFFFFF`, `#FF7A59`, `#FFEFE9`, `#1F9D6B`, `#E3F4EC`, `#B7791F`, `#FBF1DE`, danger `#D64545`, danger-soft `#FBE7E7`.
  - `static const dark`: `#1F1E1C`, `#181816`, `#2A2926`, `#33312D`, `#3A3834`, `#3B3935`, `#F3F1EC`, `#A9A59D`, `#7D7973`, `#8E88F2`, `#2D2A50`, `#14132B`, `#FF8F73`, `#45291F`, `#3CC48E`, `#1D3A2E`, `#E8B04B`, `#3F3220`, danger `#F07A7A`, danger-soft `#3D2222`.
  - `raisedShadow`: `#1C1A140F` at 0,4 blur 16 plus `#1C1A140D` at 0,1 blur 2.
  - An extension `context.palette`.
- [X] T006 Create `lib/app/theme/app_text.dart`. `AppText` (const `TextStyle`s, no colour) holds:
  - Newsreader: `serifTitle` (500, 22/28, −0.5) and `greeting` (500, size and line height from Figma W1 node 2305:2, the "Where to next" text).
  - Plus Jakarta Sans: `title` (600, 17/24), `body` (400, 15/24), `bodyStrong` (600, 15/22), `small` (400, 13/18), `smallStrong` (600, 13/18) and `micro` (600, 11/14, letterSpacing 2).
- [X] T007 Rewrite `lib/app/theme/app_theme.dart`:
  - `AppTheme.light()` and `AppTheme.dark()` from `AppPalette.light` and `.dark`. Put the palette in `extensions`, and set `scaffoldBackgroundColor = bgApp`.
  - The `TextTheme` maps `AppText` to the slots: displaySmall=greeting, headlineSmall=serifTitle, titleMedium=title, bodyLarge=body, bodyMedium=body, labelLarge=bodyStrong, bodySmall=small, labelMedium=smallStrong, labelSmall=micro. Colours: textPrimary, and textSecondary for small and micro.
  - Button, input, chip, dialog, bottom-sheet and snack-bar themes use the palette.
- [X] T008 Edit `lib/app/theme/tokens.dart`: remove `AppColors` and `kSoftShadow`. Check `AppSpacing` and `AppRadius` against the v1 Figma dimension variables (node 2301:17), and add any missing radius (e.g. `xl = 16`). Keep `kWideLayoutBreakpoint = 900`.
- [X] T009 [P] Create `lib/app/theme/app_icons.dart`: an enum `AppIcons` with the T004 names and their asset paths, and an `AppIcon(icon, {size = 20, color})` widget using `SvgPicture.asset` with `ColorFilter.mode(color ?? IconTheme.of(context).color, BlendMode.srcIn)`
- [X] T010 [P] Unit tests in `test/app/theme/palette_test.dart`:
  - every light and dark value matches T005;
  - `lerp` at 0 and 1;
  - the contrast of textPrimary, textSecondary and brandPrimary on bgApp and bgSurface is ≥ 4.5:1 in both modes (SC-007).

### Migrate every screen off `AppColors` (research R-3 table)

Each task replaces `AppColors.x` with `context.palette.<token>`:

| `AppColors` | palette token |
|---|---|
| primary | brandPrimary |
| primarySoft | brandPrimarySoft |
| onPrimary | brandOnPrimary |
| accent | brandAccent |
| canvas | bgApp |
| surface | bgSurface |
| text | textPrimary |
| muted | textSecondary |
| border | borderDefault |
| success | statusSuccess |
| warning | statusWarning |
| danger | statusDanger |

`kSoftShadow` becomes `context.palette.raisedShadow`. A `const` that can no longer be const loses `const`. Update the
feature's widget tests to pump with `AppTheme.light()`. Commit one feature per task.

- [X] T011 [P] Migrate `lib/core/widgets/` and `lib/features/account/` and their tests
- [X] T012 [P] Migrate `lib/features/destination/` and `lib/features/discover/` and their tests
- [X] T013 [P] Migrate `lib/features/flights/` and `lib/features/hotels/` and their tests
- [X] T014 [P] Migrate `lib/features/cars/` and `lib/features/ranking/` and their tests
- [X] T015 [P] Migrate `lib/features/itinerary/`, `lib/features/plans/` and `lib/features/system/` and their tests
- [X] T016 Check `grep -rn "AppColors\|kSoftShadow" lib test` returns nothing; run all tests

### Shared test helpers

- [X] T017 Extend `test/helpers.dart`:
  - `pumpApp(tester, widget, {Size size = const Size(390, 844), ThemeMode mode = ThemeMode.light, List<Override> overrides})`, which wraps the widget in `MaterialApp` with both themes;
  - constants `phone = Size(390, 844)` and `desktop = Size(1440, 900)`;
  - `forBothModes(description, body)`, which runs a widget test in light and dark.

### Chat data layer (used by US1, US2, US3, US5, US7)

- [ ] T018 [P] Create `lib/features/chat/data/sse_decoder.dart`:
  - `SseDecoder` is a `StreamTransformer<List<int>, SseEvent>`. It decodes UTF-8 across chunk boundaries, reads `event:` and `data:` lines, joins multi-line data with `\n`, ends an event at a blank line, ignores lines starting with `:`, and accepts `\r\n`.
  - `SseEvent(name, data)`.
- [ ] T019 [P] Unit tests in `test/features/chat/data/sse_decoder_test.dart`:
  - one event per chunk;
  - an event split across 3 chunks;
  - a 2-byte UTF-8 character split across chunks;
  - `: ping` ignored;
  - `\r\n`;
  - multi-line data;
  - a trailing event with no blank line is dropped.
- [ ] T020 Create `lib/features/chat/data/chat_transport.dart`:
  - `abstract interface class ChatTransport { Stream<List<int>> post(String path, Map<String, Object?> body); }`.
  - It throws `ChatRefused(statusCode, Map<String,Object?>? problem, Duration? retryAfter)` when the answer is not `200 text/event-stream`.
  - `chatTransportProvider` picks the implementation through the conditional import `chat_transport_io.dart` / `chat_transport_web.dart`.
  - `test/features/chat/fake_chat_transport.dart` yields scripted SSE text, or throws a scripted refusal.
- [ ] T021 [P] Create `lib/features/chat/data/chat_transport_io.dart`:
  - It uses `ref.read(dioProvider)` with `Options(responseType: ResponseType.stream, receiveTimeout: Duration.zero, headers: {'Accept': 'text/event-stream'})` and yields `response.data.stream`.
  - A non-200 `DioException` becomes `ChatRefused`, reading the Problem Details body and `Retry-After`.
- [ ] T022 [P] Create `lib/features/chat/data/chat_transport_web.dart` with `dart:js_interop` (no `package:web`):
  - Declare `@JS('fetch')` external bindings for `Response.status`, `Response.headers.get`, `Response.body.getReader()` and `ReadableStreamDefaultReader.read()` (`{done, value: Uint8Array}`).
  - POST to `'${Env.apiBaseUrl}/api/v1$path'` with headers `Authorization: Bearer ${await ref.read(apiSessionProvider).token()}`, `Content-Type: application/json` and `Accept: text/event-stream`. On a 401 with `code: sign-in-required`, renew the token once (`token(refresh: true)`) and retry, as `AuthInterceptor` does.
  - Yield each chunk's bytes. A non-200 answer becomes `ChatRefused`, from the JSON body.
  - Cancelling the Dart stream calls `reader.cancel()`.
- [ ] T023 Create `lib/features/chat/data/chat_models.dart` (data-model "Chats"):
  - `ChatTrip`, `ChatListItem`, `ChatPage` (`items`, `next`, `keepDays`), `Chat` (with `busy` and `expiresAt`), `ChatMessage` (role traveller or assistant, `text`, `about`, `steps`, `cards`, `suggestions`, `warnings`, `planChanged`, `at`, and app-only `notSent`), `MessageAbout` (`planId`, `day?`, `itemId?`), `ToolStep` (`tool`, `summary`, `ok`, `total?`, `cards`), `ChatSearchResult` (`chats`, `plans`) and `ChatRequest` (`text`, "1–1,000 characters after trimming", `trip?`, `preferences?`, `pace?`, `about?`, with `toJson` omitting nulls).
  - Every model gets a hand-written `fromJson`.
- [ ] T024 Create `lib/features/chat/data/cards.dart`:
  - `sealed class AssistantCard` with the envelope fields (`id`, `lat`, `lng`, `approximate`, `foundAt`) and `raw` (the card's JSON, kept for saving).
  - Subclasses: `PlanCard(PlanSummary)`, `FlightCard(FlightFare, Match?)`, `HotelCard(HotelOffer, Match?)`, `CarCard(CarOffer, Match?)`, `PlaceCard(Place)`, `EventCard(TravelEvent, location?)` and `FactsCard(TravelFacts)`.
  - `static AssistantCard? fromJson`. It returns null for an unknown `kind`, or when the item fails to parse (catch the `TypeError` and `FormatException` only).
  - Create `TravelFacts` with `destination`, `from`, `to`, `weather?`, `visa?`, `currency?`, `safety?` and `holidays`, reusing the destination feature's `ExchangeRate`, `VisaRequirement`, `TravelAdvisory` and `Holiday` where their fields match the contract, else small new classes in the same file.
  - Add `PlanSummary`'s new fields (`destinationId`, `adults`, `tripBudget?`, `pace`, `lat`, `lng`) in `lib/features/itinerary/data/plan_models.dart`.
- [ ] T025 Create `lib/features/chat/data/chat_events.dart`: `sealed ChatEvent` with `ChatStarted(chatId, title?, messageId)`, `StepDone(ToolStep)`, `AnswerDone(ChatMessage)` and `AnswerFailed(warning)`. `ChatEvent? fromSse(SseEvent)` returns null for an unknown name.
- [ ] T026 Create `lib/features/chat/data/chat_repository.dart` (`chatRepositoryProvider`):
  - `list({String? before, int limit = 30})` (limit 1–100), `get(id)`, `rename(id, title)` (title "1–40 characters after trimming"), `delete(id)`, `search(q)` ("q is 2–100 characters"), and `send({String? chatId, required ChatRequest request}) → Stream<ChatEvent>`. `send` posts `/assistant/chats` without an id, and `/assistant/chats/{id}/messages` with one.
  - It maps refusals to `ChatFailure` subclasses: `ChatBusy` (409 `chat-busy`), `ChatFull` (409 `chat-full`, with the API's message), `ChatNotFound` (404), `TooManyMessages(retryAfter)` (429) and `FieldError(field)` (400).
  - A 30 s watchdog with no byte ends the stream with `AnswerFailed('The connection was lost. Try again.')`. So does a stream that ends without `final` or `error`.
- [ ] T027 [P] Unit tests in `test/features/chat/data/chat_models_test.dart` and `cards_test.dart`:
  - every field of every model and card kind, using the contract's examples;
  - an unknown `kind` and a broken item are skipped;
  - a null `match` stays null;
  - `approximate` is read.
- [ ] T028 [P] Unit tests in `test/features/chat/data/chat_repository_test.dart`:
  - each route's path and body;
  - each failure code;
  - the event order chat → steps → final;
  - an `error` event;
  - a stream ending early;
  - the 30 s watchdog (fake async).

### Chat state and the side panel skeleton (used by US1, US2, US3, US5, US6)

- [ ] T029 Create `lib/features/chat/application/chat_controller.dart`:
  - `chatProvider` is a `NotifierProvider.family<ChatController, ChatState, String?>`, keyed by chat id (null for a new chat). `ChatState` holds `chatId`, `title`, `messages`, `pending` (`PendingTurn(message, steps)`), `status` (idle, loading, sending, busyElsewhere, failed) and `failure`.
  - `load()` for an existing id: `get`. A `busy` chat is polled every 5 s for at most 60 s.
  - `send(text, {about})`: append the traveller's message at once, then run the stream.
    - `ChatStarted` sets the id and calls an `onChatCreated(id)` callback (the screen replaces the route).
    - `StepDone` appends to `pending.steps`.
    - `AnswerDone` moves the pending turn into `messages`, sets `title`, invalidates `recentsProvider`, and invalidates `planProvider(planChanged)` when it is set.
    - `AnswerFailed` and refusals set `failed`, mark the message `notSent` and keep the steps.
  - `retry()` resends the last unsent message as a new message.
  - Use `retry: noRetry`.
- [ ] T030 Create `lib/features/chat/application/chat_trip.dart`:
  - `chatTripProvider` is a `Notifier` holding the composer's `ChatTrip`, preferences (six values 0–100) and `Pace`. It starts from the latest `recentsProvider` item's trip, else the latest plan (`plansProvider`), else empty. The preferences and pace start from the profile (`profileProvider`).
  - Setters `setTrip`, `setPreferences` and `setPace`.
  - `toRequestParts()` for `ChatRequest`.
- [ ] T031 Create `lib/features/side_panel/application/side_panel_controller.dart`:
  - `sidePanelProvider` is a `NotifierProvider.family<SidePanelController, SidePanelState, String>`, keyed by chat id or `'home'`. `SidePanelState` holds `open`, `pane` (trip, plan, details, map, saved), `selected?` (`AssistantCard`) and `planId?`.
  - Methods `openCard(card)` (a `PlanCard` → pane plan with planId; others → details), `openPane(pane)`, `openPlan(id)` and `close()`.
- [ ] T032 [P] Unit tests in `test/features/chat/application/chat_controller_test.dart` (fake transport):
  - send in a new chat: the id is set and the callback fires;
  - steps append in order;
  - `final` moves them into a message;
  - `planChanged` invalidates the plan;
  - an `error` keeps the steps and marks the message not sent;
  - retry;
  - each refusal type;
  - load a chat; busy polling stops after 60 s.

  Also `chat_trip_test.dart` (each start source) and `side_panel_controller_test.dart` (each method).
- [ ] T033 Create `lib/features/side_panel/presentation/side_panel.dart`:
  - `SidePanel(chatKey)` with `PanelIconBar` (Trip, Plan, Details, Map and Saved icons, the active one highlighted, and close) and an `IndexedStack` of pane placeholders. Each story fills its pane.
  - `showSidePanelSheet(context, chatKey)` shows the same panel in a modal `DraggableScrollableSheet` (initial 0.9, min 0.5).
  - Layout rule (research R-6): from 900 px the panel sits in the row at 520 px; when the window is under 1200 px with the panel open, the sidebar collapses to its rail.

**Checkpoint**: the app looks v1 everywhere, all old tests pass, and the chat data layer is tested.

---

## Phase 3: User Story 8 - Theme v1, light and dark (P1)

**Goal**: the app follows the device mode, and Appearance overrides it, kept on the device.
**Independent test**: switch Appearance to Dark, check the dark tokens, restart with the stored value, and check
it's kept.

- [ ] T034 [P] [US8] Create `lib/app/theme/appearance.dart`: `appearanceProvider` (`Notifier<ThemeMode>`) reads `SharedPreferences` key `appearance` (`system`, `light` or `dark`; missing or unknown → `system`). `set(mode)` writes it. Wrap every read and write in try/catch: a failure keeps the in-memory value.
- [ ] T035 [US8] Edit `lib/app/app.dart`: `MaterialApp.router(theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ref.watch(appearanceProvider))`
- [ ] T036 [P] [US8] Tests:
  - `test/app/theme/appearance_test.dart` (`SharedPreferences.setMockInitialValues`): default, each value, unknown, write;
  - `test/flows/appearance_flow_test.dart`: Dark shows `AppPalette.dark.bgApp` on the scaffold; a rebuilt app keeps it.

---

## Phase 4: User Story 4 - Sidebar and drawer (P1)

**Goal**: the v1 shell replaces the four tabs; every v0.2 screen is still reachable.
**Independent test**: at 1440 px the sidebar shows every item and collapses; at 390 px the drawer opens from the
menu; Explore, My plans and the profile open; a v0.2 deep link works.

- [ ] T037 [US4] Rewrite the routes in `lib/app/router.dart` (research R-5):
  - Remove `AppTab` and `StatefulShellRoute`. Add one `ShellRoute(builder: AppShell)`, with these routes inside it:
    - `/` → `AssistantHome` (placeholder `Scaffold` until T051);
    - `/chat/:chatId` → `ChatScreen` (placeholder until T052);
    - `/saved` → `AssistantHome(openSaved: true)`;
    - the existing `/discover/...`, `/plans/...` and `/profile/...` routes, unchanged.
  - Redirect `/assistant` to `/`. Set `initialLocation: '/'`.
  - In `lib/app/auth_guard.dart`, change the post-sign-in default from `/discover` to `/`, and allow `/` as before.
- [ ] T038 [P] [US4] Create `lib/features/shell/widgets/sidebar_item.dart`: `SidebarItem(icon, label, {active, onTap, trailing})`, 36 px high, as the v1 component (Default and Active states, Figma 2302:40), with the hover colour `bgHover`
- [ ] T039 [US4] Create `lib/features/shell/sidebar.dart` (W1):
  - Width 272, `bgSidebar`. From the top: brand (`AppLogo` and "TravelGenie"), the panel-left collapse button, New trip chat (→ `/`), Search chats (opens `SearchChatsDialog`, T070), Explore (→ `/discover`), My plans (→ `/plans`), Saved (→ `/saved`), the RECENTS label with `RecentsList` (T069; an empty `SizedBox` until then), and `AccountRow` at the bottom.
  - Collapsed, it is a 64 px rail of icons. The collapsed state is a session `StateProvider`.
  - The active item comes from the current location.
- [ ] T040 [US4] Create `lib/features/shell/mobile_top_bar.dart` (M1, M2): menu (opens the drawer), centred title ("TravelGenie" on `/`, the chat title with chevron-down on a chat, the screen's own title elsewhere), and the new-chat icon (→ `/`)
- [ ] T041 [US4] Create `lib/features/shell/app_drawer.dart` (M5): width 312, the "Search chats and plans" field (opens `SearchChatsDialog`), the same items as the sidebar, RECENTS and `AccountRow`. It closes after a choice.
- [ ] T042 [US4] Create `lib/features/shell/account_row.dart` and `account_menu.dart`:
  - The row shows the avatar initial, the name and "{Pace} pace" (from `profileProvider`), and chevron.
  - The menu (a `MenuAnchor` on wide screens, a bottom sheet on phones) holds:
    - Preferences and account (→ `/profile`);
    - Appearance, a System, Light and Dark segmented choice (→ `appearanceProvider.set`);
    - Sign out (the existing sign-out action).
- [ ] T043 [US4] Rewrite `lib/features/shell/app_shell.dart`:
  - From `kWideLayoutBreakpoint`: `Row(Sidebar, Expanded(child))`.
  - Below it: `Scaffold(drawer: AppDrawer, appBar: MobileTopBar, body: child)`. Screens with their own app bar (Discover, list and details screens) hide `MobileTopBar` and get a leading menu button through `ShellScope.of(context).openDrawer`.
  - Delete `lib/features/shell/floating_nav.dart` and `web_header.dart`, and every import and use of them.
- [ ] T044 [P] [US4] Widget tests:
  - `test/features/shell/sidebar_test.dart`: every item, active state, collapse to rail, navigation targets, both modes;
  - `app_drawer_test.dart`;
  - `mobile_top_bar_test.dart`;
  - `account_menu_test.dart`: each entry; Appearance writes;
  - rewrite `test/app_shell_test.dart` for both widths.
- [ ] T045 [US4] Flow test `test/flows/explore_from_shell_flow_test.dart`:
  - sign in → `/`;
  - Explore → Discover → a city → its hotels;
  - My plans;
  - account menu → profile;
  - `/discover/destination/3169070/hotels` opened directly still renders inside the shell.

  Update the existing flows in `test/flows/` (app, ranking, hotels, flights, cars, account) that tapped the floating nav, so they navigate through the sidebar or the drawer.

---

## Phase 5: User Story 1 - Plan a trip by asking (P1) 🎯 MVP

**Goal**: one message builds a plan. The steps appear live; the answer shows the plan, flight and hotel cards;
Open plan opens the Plan pane.
**Independent test**: with a fake transport scripted with three steps and a `final` carrying plan, flight and hotel
cards, at 390 px and 1440 px.

### Card widgets (shared; US2 adds the rest)

- [ ] T046 [P] [US1] Create `lib/core/widgets/cards/match_badge.dart`: `MatchBadge(Match?)`: nothing when null; otherwise a sparkles icon and "{percent}% match" on `statusSuccessSoft` / `statusSuccess` (Figma 2302:24). A tap or hover shows `match.reason` in a tooltip.
- [ ] T047 [P] [US1] Create `lib/core/widgets/cards/plan_card_tile.dart` (Figma 2304:143):
  - photo, name, "Itinerary · {matchPercent}% match · ${total} of ${tripBudget} · {Draft|Planned}" (without "of …" when there's no budget), and an Open plan button;
  - the border `brandPrimary` when it is the plan open in the panel;
  - "This plan was deleted", with the button disabled, when `planProvider` answers 404.
- [ ] T048 [P] [US1] Create `lib/core/widgets/cards/result_row.dart` (Figma 2304:114): a leading icon tile, title, subtitle, a trailing price and `MatchBadge`. Used for flights here and for cars in US2. Add `FlightCard.toRow()` text: "Beirut → Rome · ITA Airways" and "Thu 10 Apr · 08:40 → 11:15 · Direct · 3 h 35".
- [ ] T049 [P] [US1] Create `lib/core/widgets/cards/media_card.dart` (Figma 2304:92): 232×248, a photo with `MatchBadge` top-left and a bookmark slot top-right, then title, subtitle, a price line and a "+" slot. It's used for hotels here (`HotelCard`: "★ 4.7 · area · 0.9 km to centre", "$132 / night").

### Chat UI

- [ ] T050 [US1] Create the widgets in `lib/features/chat/presentation/widgets/`:
  - `user_bubble.dart` (Figma 2302:51);
  - `tool_step_line.dart` (Figma 2302:41): the tool icon (`toolIcon(String tool)`, a map of the contract's tool names with `sparkles` as fallback), the summary, a chevron that expands to the step's cards when it has any, and a failed style in `statusWarning` when `ok` is false;
  - `working_indicator.dart`: shown after the last step while `sending`;
  - `card_group.dart`: a Micro label, at most 6 cards (MediaCards in a horizontal scroll; rows and plan cards stacked), and "See all {total}" when `total` > the shown count;
  - `suggestion_chips.dart` (Figma 2302:20);
  - `answer_view.dart`: steps, then text, then the card groups in the order plan, flight, hotel, car, place, event, facts.
- [ ] T051 [US1] Create `lib/features/chat/presentation/composer.dart` (Figma 2302:111, Web and Mobile variants):
  - a multiline field (1–1,000 characters, Enter sends on the web and Shift+Enter makes a new line);
  - "+", the trip chip ("Rome · 10–14 Apr · 2 adults", or "Add trip") and the preferences chip (the top two interests by weight, then the pace, e.g. "Culture · Food · Balanced", or "Add preferences");
  - send (disabled while empty or sending). No mic.
  - The trip chip opens `TripEditorSheet`, which reuses the ranking feature's city, date and adults controls and writes `chatTripProvider.setTrip`. The preferences chip opens `PreferencesSheet`, which reuses the six sliders and the pace choice.
  - Under it, the notice (research R-8): "Messages are answered by an AI service and may be used to improve it. Don't share personal details."
- [ ] T052 [US1] Create `lib/features/chat/presentation/assistant_home.dart` (W1, M1):
  - centred `AppIcon`-mark, `greeting` "Where to next, {first name}?" (just "Where to next?" without a name), and on phones the line "Plan a trip, find flights, hotels and cars, or ask anything about where you're going.";
  - `Composer`;
  - the suggestions: seven chips on wide screens, four cards that scroll sideways on phones. Each sends its text.
    - Plan 5 days in Rome
    - Cheap flights from Beirut
    - Hotels near the centre
    - Rent a car in Lisbon
    - Top sights in Paris
    - What's on this weekend
    - Visa & weather for Istanbul
  - "Pick up where you left off": the first two `plansProvider` items as `PlanCardTile`s, with "All plans" (→ `/plans`). Hidden when there are none; a skeleton while loading; an error row with Try again;
  - the footer "TravelGenie checks prices with live sources. Prices can change before you book.";
  - the top-right "My preferences" button on wide screens, which opens `PreferencesSheet`.
  - Sending creates `chatProvider(null)` with `onChatCreated: (id) => context.replace('/chat/$id')`.
  - `openSaved: true` opens the side panel on Saved.
- [ ] T053 [US1] Create `lib/features/chat/presentation/chat_screen.dart` (W2, M2):
  - a header (wide screens: the title with chevron menu and share; phones: `MobileTopBar` shows the title);
  - the message list: `UserBubble`s, `AnswerView` for assistant messages, and for the pending turn its steps and `WorkingIndicator`;
  - the last answer's `SuggestionChips` above `Composer`;
  - the failure row under the unsent message (the warning and Try again → `retry()`);
  - from 900 px, `Row(chat (flex), SidePanel)` when the panel is open; on phones, `showSidePanelSheet` on open;
  - auto-scroll to the newest step or answer unless the user scrolled up.
- [ ] T054 [US1] Fill the Plan pane in `lib/features/side_panel/presentation/plan_pane.dart`:
  - Refactor `lib/features/itinerary/presentation/itinerary_screen.dart` into `ItineraryView(planId, {embedded})` plus the screen that wraps it. The `/plans/:id` route is unchanged.
  - The pane shows `ItineraryView(embedded: true)`: the header (name, status pill, dates · adults · from, share, ⋯), the three summary tiles (match with its parts, total of budget, pace with places a day), the tabs Days, Hotel, Flight, Car, Map (the T064 `PinPreview` of the plan's items; a placeholder until US2) and Costs (the 007 cost lines), and the day chips and `DayItemTile`s.
  - The bottom bar has "Ask to change this day…" (wired in US3) and Mark as planned (`PATCH /plans/{id}` `{status: planned}`; the button reads "Mark as draft" when planned).
- [ ] T055 [US1] Wire the plan card: `PlanCardTile` Open plan → `sidePanelProvider(chatKey).openCard(card)`. Open the sheet on phones.
- [ ] T056 [P] [US1] Widget tests:
  - `test/features/chat/presentation/assistant_home_test.dart`: greeting with and without a name; chips; suggestions at both widths; Pick up where you left off (loading, data, empty, error);
  - `composer_test.dart`: limits, Enter vs Shift+Enter, chips open their sheets, the notice;
  - `chat_screen_test.dart`: steps appear one by one, the working indicator, the answer's groups and order, suggestion chips send, the failure row and retry, refusal messages for each `ChatFailure`;
  - `tool_step_line_test.dart`;
  - `plan_pane_test.dart`: tiles, tabs, Mark as planned, 404 → deleted;
  - `match_badge_test.dart`;
  - `plan_card_tile_test.dart`.

  All at `phone` and `desktop`, with `forBothModes`.
- [ ] T057 [US1] Flow test `test/flows/assistant_first_flow_test.dart`:
  - sign in → home;
  - type the Rome message → the three step lines appear in order before the answer;
  - the plan, flight and hotel cards show;
  - Open plan → the Plan pane beside the chat (1440) or the sheet (390);
  - the address is `/chat/{id}`.

**Checkpoint**: MVP. Plan a trip by asking works end to end against fakes.

---

## Phase 6: User Story 2 - Ask for any one thing (P1)

**Goal**: flights, hotels, cars, places, events and travel facts each show their card. Each opens in Details;
"See all N" opens the list.
**Independent test**: one fake answer per card kind; tap each card → Details; See all → the list route.

- [ ] T058 [P] [US2] Card bodies:
  - In `media_card.dart`, add `PlaceCard` (photo, name, kind label "Sight", "Restaurant", "Nature" or "Nightlife", rating or price level when known) and `EventCard` (photo, name, "Sat 12 Apr · 21:30", venue, price when known).
  - In `result_row.dart`, add `CarCard` ("Fiat 500 · Hertz", "Pick-up Lisbon airport · 10–14 Apr", total price, match).
- [ ] T059 [P] [US2] Create `lib/core/widgets/cards/facts_rows.dart`: rows with icons for weather ("22° / 12° · Sunny most days"), visa ("Visa needed · Schengen · Lebanese passport"), currency ("1 USD = 0.92 EUR"), safety (the level label) and holidays (the first one with "+n more"). A null part is left out.
- [ ] T060 [US2] "See all N" in `card_group.dart`: build the existing list route from the card's destination and the chat's trip:
  - hotels → `/discover/destination/{id}/hotels`;
  - flights → `.../flights`;
  - cars → `.../cars`;
  - places → `.../places?category=attraction|restaurant` (by the cards' kind);
  - events → `.../` overview.

  Set the trip settings (dates, adults, preferences) the list screens read before navigating. Reuse the setters the ranking feature already uses.
- [ ] T061 [US2] Split the details screens into embeddable views, keeping the screens and routes:
  - `HotelDetailsView(hotelId, {offer})` from `lib/features/hotels/presentation/hotel_details_screen.dart`;
  - `CarDetailsView(args)` from `lib/features/cars/presentation/car_details_screen.dart`;
  - `PlaceDetailsView(placeId)` from `lib/features/destination/presentation/place_details_screen.dart`.

  Update their tests to cover both the screen and the view.
- [ ] T062 [US2] Fill the Details pane in `lib/features/side_panel/presentation/details_pane.dart`, by `selected` card kind:
  - Hotel → `HotelDetailsView`.
  - Car → `CarDetailsView` from the card's `CarOffer`.
  - Place with an `otm:` id → `PlaceDetailsView`; any other place → a compact view from the card (photo, name, kind, coordinates, "Open link" when `url`).
  - Flight → a compact view (route, airline, times, stops, duration, price, "Prices are recent, not live").
  - Event → a compact view (photo, name, date, venue, price, "Get tickets" through `LinkOpener`).
  - Facts → `FactsRows` in full.

  Each view shows `MatchBadge` and its reason at the top when ranked, and a footer slot for the bookmark (US6) and Add to plan (US3). When `foundAt` is over 24 h old, it shows "Found on {date}" and Search again (it sends "Search again for …" as a message). A card with no `selected` shows "Tap a card in the chat to see it here."
- [ ] T063 [US2] Wire every card's tap to `sidePanelProvider(chatKey).openCard(card)`, which opens the sheet on phones
- [ ] T064 [P] [US2] Create `lib/core/widgets/cards/pin_preview.dart` (research R-7):
  - `PinPreview(List<MapPin>)`, with `MapPin(id, lat, lng, kind, label, approximate)`.
  - A `CustomPaint`: an equirectangular projection of the pins' bounding box with 12 % padding (a minimum span of 0.01°), pins coloured by kind (hotel brandPrimary, place statusSuccess, event brandAccent, car textSecondary, plan day textPrimary with its number), approximate pins hollow, and a scale bar.
  - A list under the canvas. A tap on a pin or a row calls `onSelect(id)`. The legend "Some places show the city centre" appears when any pin is approximate.
- [ ] T065 [US2] Fill the Map pane in `lib/features/side_panel/presentation/map_pane.dart`:
  - the pins of every card in this chat's messages, plus the open plan's day items when a plan is open;
  - a tap opens the card in Details;
  - empty: "Pins show here when the assistant finds hotels, places or events."

  Use `PinPreview` in the Plan pane's Map tab too.
- [ ] T066 [P] [US2] Widget tests:
  - `test/core/widgets/cards/`: media_card for each kind, result_row for flight and car, facts_rows with null parts, pin_preview (projection of known points, hollow pins, tap);
  - `test/features/side_panel/presentation/details_pane_test.dart`: each kind, old `foundAt`, loading and error of the hotel and place views;
  - `map_pane_test.dart`;
  - `card_group_test.dart`: See all targets.

  At both widths and in both modes.
- [ ] T067 [US2] Flow test `test/flows/any_one_thing_flow_test.dart`: six fake answers (flights, hotels, cars, places, events, facts) → each shows its card kind → tap → Details shows it → See all on hotels opens the hotels list with the chat's city and dates

---

## Phase 7: User Story 5 - Come back to a chat (P2)

**Goal**: Recents, reopening, continuing, Search chats, rename and delete.
**Independent test**: with the fake API, list, open, continue, search "jazz", rename, delete.

- [ ] T068 [P] [US5] Create `lib/features/chat/application/recents.dart`:
  - `recentsProvider` is an `AsyncNotifier<RecentsState>` (items, `next`, `keepDays`, `loadingMore`). It loads 30, `loadMore()` follows `next`, and `rename(id, title)` and `delete(id)` update the list after the API answers.
  - `chatSearchProvider(q)` debounces 300 ms; q under 2 characters gives an empty result.
- [ ] T069 [US5] Create `lib/features/shell/recents_list.dart`:
  - `SidebarItem`s by title (no title shows "New chat"), the current chat active, a ⋯ on hover or long-press with Rename (a dialog, "1–40 characters") and Delete (confirm: "Delete this chat? Plans built in it stay.");
  - "Show more" when `next` is set;
  - the footer "Chats are kept for {keepDays} days." (FR-024a);
  - loading: three skeleton rows; error: "Couldn't load your chats · Try again"; empty: hidden.
  - Deleting the open chat goes to `/`.
- [ ] T070 [US5] Create `lib/features/shell/search_chats_dialog.dart`:
  - a dialog on wide screens, a full-screen sheet on phones;
  - a field (autofocus) with two groups: Chats (open `/chat/{id}`) and Plans (open the plan in the Plan pane of a new home, through `/` with the panel's `openPlan`);
  - "Type at least 2 letters", "Nothing found for '{q}'", and an error with Try again;
  - before any chat exists, it says "Nothing to search yet."
- [ ] T071 [US5] Reopening in `chat_screen.dart`:
  - `chatProvider(id).load()` with a skeleton of three message blocks;
  - 404 → "This chat has expired" with New trip chat;
  - `busy` → the working state with "Still answering on another device…";
  - the composer continues the chat; the trip chips take the chat's stored trip, preferences and pace.
- [ ] T072 [US5] Use `RecentsList` in `sidebar.dart` and `app_drawer.dart`, and wire Search chats to `SearchChatsDialog`
- [ ] T073 [P] [US5] Tests:
  - `test/features/chat/application/recents_test.dart`: paging, rename and delete, search debounce, short q;
  - `test/features/shell/recents_list_test.dart`: all states, rename and delete dialogs, the footer;
  - `search_chats_dialog_test.dart`;
  - `chat_screen_reopen_test.dart`: load, 404, busy.
- [ ] T074 [US5] Flow test `test/flows/chat_recents_search_flow_test.dart`: Recents shows two chats → open one → its messages and cards show → send → the answer appends → Search "jazz" → open the result → rename → delete → Recents updates

---

## Phase 8: User Story 3 - Change the plan by chatting (P2)

**Goal**: day-item swap, "Ask to change this day…", "+" on hotel and car cards, Rebuild plan, all reflected in the
Plan pane.
**Independent test**: a fake answer with `planChanged`; the Plan pane reloads and shows the new plan.

- [ ] T075 [P] [US3] Extend `lib/features/itinerary/data/plan_repository.dart` and `plan_models.dart` (data-model "Plan additions"):
  - `Plan.edits` (`PlanEdit` with action replace, add or remove);
  - `dayAlternatives(planId, day, {itemId, kind})`;
  - `addOrReplaceItem(planId, day, {kind, id, replaces})`;
  - `removeItem(planId, day, itemId)`;
  - `rebuild(planId, RebuildRequest)`.

  Map the failures: `DayFull` (422 `day-full`, the API's message), `NoPlaces` (422 `no-places`), `PlanFieldError` (400) and `PlanNotFound` (404).
- [ ] T076 [P] [US3] Unit tests in `test/features/itinerary/data/plan_edits_test.dart`: each new route's path and body, each failure, `edits` parsing
- [ ] T077 [US3] In `ItineraryView` (embedded), wire:
  - the day-item swap icon: send "Show me alternatives to {item name} on day {n}" with `about: {planId, day, itemId}` to the panel's chat;
  - "Ask to change this day…": a field whose message is sent with `about: {planId, day}` (the day shown).

  Both go through `chatProvider(chatKey).send`. On `/`, the home creates the chat first.
- [ ] T078 [US3] "+" on hotel and car cards (`media_card.dart`, `result_row.dart`):
  - with a plan open in the panel (or the chat's latest `PlanCard`), call `PUT /plans/{id}/{hotel|car}` (`offerId` = card id) through the existing 007 `PlanActions.swap`, then open the Plan pane and append a local note "Swapped in {name}";
  - a 400 on `offerId` sends "Swap {name} into my plan" to the assistant instead;
  - without a plan, send "Build a plan with {name}".

  In the Details pane, the same action reads "Add to plan" or "Swap into plan".
- [ ] T079 [US3] Fill the Trip pane in `lib/features/side_panel/presentation/trip_pane.dart`:
  - editable rows for city, dates, adults, departure city, preferences (the six sliders), pace and trip budget, all bound to `chatTripProvider`;
  - "Rebuild plan" (enabled when a plan is open): `rebuild(planId, values)`, with a progress state; the plan is unchanged on failure, with the error shown;
  - "This chat": plans built (plan cards), found by kind with counts (e.g. "Hotels · 48"), and saved items from this chat. Each opens its pane.
- [ ] T080 [US3] `planChanged` handling: after `AnswerDone`, when the panel shows that plan, reload it (T029 invalidates `planProvider`). The pane shows a short "Plan updated" highlight.
- [ ] T081 [P] [US3] Widget tests:
  - `test/features/side_panel/presentation/trip_pane_test.dart`: edits, Rebuild success and failure, outputs;
  - `plan_pane_edits_test.dart`: the swap icon sends with `about`, the change field, reload on `planChanged`;
  - `card_plus_test.dart`: swap path, the 400 fallback, the no-plan message.
- [ ] T082 [US3] Flow test `test/flows/change_plan_by_chat_flow_test.dart`: open a plan → swap icon on a day item → a fake answer with place cards → "Use Villa Borghese" → a fake answer with `planChanged` → the Plan pane shows the new item; "+" on a hotel card swaps the hotel

---

## Phase 9: User Story 7 - Pick a tool on the phone (P2)

**Goal**: the M4 tools sheet on phones and the same menu on the web.
**Independent test**: at 390 px, each tool fills the composer and doesn't send; trip dates update the chip.

- [ ] T083 [P] [US7] Create `lib/features/chat/application/tool_starters.dart`: `toolStarter(Tool, ChatTrip)` returns a message. Unknown values are left as "…". The tools and their starters:

  | Tool | Starter |
  |---|---|
  | planTrip | "Plan {n} days in {city} for {adults}" |
  | flights | "Find flights from {origin} to {city} on {from}" |
  | hotels | "Find hotels in {city} for {from}–{to}" |
  | carRental | "Rent a car in {city} from {from} to {to}" |
  | places | "Top sights in {city}" |
  | events | "What's on in {city} {from}–{to}" |
  | travelInfo | "Visa and weather for {city}" |
  | preferences | "Show my travel preferences" |

- [ ] T084 [US7] Create `lib/features/chat/presentation/tools_sheet.dart` (M4):
  - the title "What can I help with?" and the line "Pick one, or just type — I'll use the right tool.";
  - a 2-column grid of the eight tools with their icons and second lines:
    - Plan a trip: Day by day
    - Flights: Best fares
    - Hotels: Ranked for you
    - Car rental: Pick-up & return
    - Places: Sights & food
    - Events: Shows & games
    - Travel info: Visa & weather
    - My preferences: Budget & pace
  - the rows "Set trip dates and travellers" (→ `TripEditorSheet`) and "Open a saved plan" (the latest 5 plans → `openPlan`). No attach and no location rows;
  - a tool sets the composer text (via a `TextEditingController` the composer exposes) and closes the sheet; My preferences opens `PreferencesSheet`.
  - On the web, the composer's "+" opens the same entries in a `MenuAnchor`.
- [ ] T085 [P] [US7] Tests:
  - `test/features/chat/application/tool_starters_test.dart`: each tool, with a full trip and an empty one;
  - `test/features/chat/presentation/tools_sheet_test.dart`: the grid, rows, no attach or location, nothing sent;
  - flow `test/flows/tools_sheet_flow_test.dart`: 390 px "+" → Hotels → the composer has the starter → Set trip dates → the chip updates.

---

## Phase 10: User Story 6 - Save what I like (P3)

**Goal**: bookmarks on hotel, place and event cards; Saved in the sidebar and as a pane.
**Independent test**: bookmark a hotel and a place, open Saved, open one in Details, remove it, reload and check
it's kept.

- [ ] T086 [P] [US6] Create `lib/features/saved/data/saved_models.dart` and `saved_repository.dart`:
  - `SavedKind` (hotel, place, event), `SavedItem` (`kind`, `id`, `destinationId`, `destinationName`, `name`, `imageUrl?`, `lat`, `lng`, `savedAt`, `card?` parsed from `item`), `SavedList` (`items`, `count`, `max`) and `SavedIds`.
  - `save(AssistantCard)`: `PUT /saved/{kind}/{id}` with `destinationId`, `name` ("1–200 characters"), `imageUrl`, `lat`, `lng` and `item` (the card's raw item, "at most 20 KB packed": leave `item` out when bigger).
  - `remove(kind, id)`, `list({kind, destinationId})` and `ids()`.
  - Failures: `TooManySaved` (409 `too-many-saved`) and `FieldError`.
- [ ] T087 [US6] Create `lib/features/saved/application/saved_providers.dart`:
  - `savedIdsProvider` (`AsyncNotifier<SavedIds>`) with `toggle(card)`. It updates at once, calls the API, and on failure reverts and returns the failure, so the UI shows a snack bar ("Couldn't save. Try again." or the limit message).
  - `savedProvider` (`GET /saved`), invalidated after a toggle.
- [ ] T088 [US6] Create `lib/features/saved/presentation/bookmark_button.dart` (filled or outlined `bookmark` icon from `savedIdsProvider`). Put it in the MediaCard slot for hotels, places and events, and in the Details pane footer for those kinds only.
- [ ] T089 [US6] Fill the Saved pane in `lib/features/side_panel/presentation/saved_pane.dart`:
  - groups Hotels, Places and Events, newest first, each item a row (photo, name, city) that opens its `card` in Details;
  - skeleton rows, an error with Try again, and the empty text "Tap the bookmark on a hotel, place or event to keep it here.";
  - the sidebar's and drawer's Saved go to `/saved`, which opens this pane.
- [ ] T090 [P] [US6] Tests:
  - `test/features/saved/data/saved_repository_test.dart`: each route and body, the 20 KB rule, 409;
  - `saved_providers_test.dart`: optimistic toggle and revert;
  - `test/features/saved/presentation/bookmark_button_test.dart`;
  - `saved_pane_test.dart`: all states;
  - flow `test/flows/saved_flow_test.dart`: bookmark a hotel and a place → Saved shows both grouped → open the hotel in Details → remove it → a rebuilt app still shows the place.

---

## Phase 11: Polish and cross-cutting

- [ ] T091 Remove `lib/features/assistant/` (screen, widgets, `card_opener.dart`, models, repository) and `test/features/assistant/` and `test/flows/assistant_flow_test.dart`; make sure nothing imports them (`grep -rn "features/assistant" lib test`)
- [ ] T092 [P] Side-panel flow `test/flows/side_panel_flow_test.dart`:
  - at 1440 px: open each pane from the icon bar; the chat stays visible; the panel remembers its pane when switching chats and back;
  - at 1100 px with the panel open, the sidebar collapses to its rail;
  - at 390 px the panel is a sheet with the same icon bar.
- [ ] T093 [P] Accessibility pass:
  - every icon-only button has a `tooltip` or `Semantics(label)`;
  - card taps have semantics labels ("Hotel Artemide, 92% match, $132 a night");
  - check the minimum 48×48 tap targets on phones.
- [ ] T094 [P] Check no chat text, trip or preferences are logged: `grep -rn "print(\|debugPrint(\|log(" lib/features/chat lib/features/saved lib/features/side_panel` returns nothing new (constitution, FR-024a)
- [ ] T095 Run the gates: `flutter analyze --fatal-infos`, `dart format --set-exit-if-changed lib test`, `flutter test` and `flutter build web --release`
- [ ] T096 The check in the running app ([quickstart.md](quickstart.md) "In the running app" steps 1–8), at 390 px and 1440 px in light and dark, against a local pamplemousse on `010-assistant-v2`. Check the step lines arrive live on the web (R-1). Note in the PR which states were built without their own Figma frame (constitution IV).
- [ ] T097 [P] Docs:
  - update `README.md` (or the app docs folder) for the new shell, the routes `/` and `/chat/:id`, and Appearance;
  - add the `shared_preferences` justification and the `dart:js_interop` transport to the PR description;
  - ask the owner to add `status/danger` and `status/danger-soft` to the v1 Figma variables (R-3).

---

## Dependencies and execution order

```text
Setup (T001–T004)
  └─ Foundational (T005–T033)        # theme + migration + chat data + chat state + panel skeleton
       ├─ US8 Theme/Appearance (T034–T036)
       ├─ US4 Shell (T037–T045)      # needs T005–T016
       │    └─ US1 Plan by asking (T046–T057)  🎯 MVP   # needs US4's routes, T018–T033
       │         ├─ US2 Any one thing (T058–T067)       # card widgets and panel from US1
       │         │    ├─ US3 Change by chat (T075–T082) # Details "Add to plan", Map from US2
       │         │    └─ US6 Saved (T086–T090)          # MediaCard slots, Details footer
       │         ├─ US5 Recents/Search (T068–T074)      # chat screen from US1
       │         └─ US7 Tools sheet (T083–T085)         # composer from US1
       └─ Polish (T091–T097) after all stories
```

- US8 and US4 can run side by side after Foundational.
- US5 and US7 can run side by side after US1. US3 and US6 can run side by side after US2.
- Inside a story, models and repositories come before providers, then widgets, then the flow test.

## Parallel examples

- **Foundational**: T011–T015 (the migration, one folder each), then T018 and T019 with T021 and T022 (the transports), and T027 and T028 (data tests), all on different files.
- **US1**: T046–T049 (the four card widgets) together, then T050–T053 in order, with T056 written beside each widget.
- **US2**: T058, T059 and T064 together; T061 (the views split) beside them.
- **US6**: T086 beside T088's widget test; T090's tests in parallel.

## Implementation strategy

1. **MVP = Phases 1–5**: setup, foundational, theme, shell, plan by asking. It's demoable: the v1 look, the
   sidebar and drawer, one message builds a plan, steps live, the Plan pane.
2. **Then US2**, so every feature is reachable through the assistant (the owner's rule), then US5 and US7, then US3
   and US6.
3. **Polish**, then the live check against pamplemousse spec 010.
4. One PR for the whole feature (plan "Delivery order"), with commits per task group so review can follow the
   phases.
