# Data Model: Assistant-first shell (spec 008)

These are app models, parsed by hand in `data/` (constitution I) from pamplemousse spec 010's contracts. Unknown enum
values become `other` (or are skipped, for cards and events), never a crash.

## Chats (`features/chat/data/chat_models.dart`)

| Model | Fields | From |
|---|---|---|
| `ChatTrip` | `destinationId?`, `destinationName?`, `from?`, `to?`, `adults?`, `originId?`, `passport?`, `currency?`, `tripBudget?` | `trip` of the request, the chat and the list item |
| `ChatListItem` | `id`, `title?`, `trip?`, `createdAt`, `lastMessageAt`, `messageCount` | `GET /assistant/chats` items, search `chats` |
| `ChatPage` | `items`, `next?` (cursor), `keepDays` | `GET /assistant/chats` |
| `Chat` | `id`, `title?`, `trip?`, `preferences?`, `pace?`, `createdAt`, `lastMessageAt`, `expiresAt`, `busy`, `messages` | `GET /assistant/chats/{id}` |
| `ChatMessage` | `id`, `role` (traveller, assistant), `text`, `about?`, `steps`, `cards`, `suggestions`, `warnings`, `planChanged?`, `at`, and app-only `notSent` | chat messages, and `final` |
| `MessageAbout` | `planId`, `day?`, `itemId?` | `about` |
| `ToolStep` | `tool` (string; the icon falls back to generic), `summary`, `ok`, `total?`, `cards` | `step`, `messages[].steps` |
| `ChatSearchResult` | `chats` (`ChatListItem`), `plans` (`PlanSummary`) | `GET /assistant/chats/search` |
| `ChatRequest` | `text` (1–1,000 after trimming), `trip?`, `preferences?`, `pace?`, `about?` | sent |

### Stream events (`chat_events.dart`)

```text
sealed ChatEvent
├── ChatStarted(chatId, title?, messageId)            # event: chat
├── StepDone(ToolStep)                                # event: step
├── AnswerDone(ChatMessage)                           # event: final (role assistant)
└── AnswerFailed(warning)                             # event: error
```

The controller expects the order `ChatStarted`, then `StepDone*`, then one `AnswerDone` or `AnswerFailed`. A stream
that ends with neither, or goes 30 s without a byte, is treated as `AnswerFailed("The connection was lost. Try
again.")`.

### Refusals (`ChatFailure`, before the stream)

| Failure | API | Shown as |
|---|---|---|
| `ChatBusy` | 409 `chat-busy` | "Still answering on another device…" and a reload |
| `ChatFull` | 409 `chat-full` | the API's message, with New trip chat |
| `ChatNotFound` | 404 | "This chat has expired" (FR edge case), with New trip chat |
| `TooManyMessages(retryAfter)` | 429 | "Too many messages. Wait a minute and try again.", with Try again enabled after `Retry-After` |
| `FieldError(field)` | 400 | the message under the composer |

### Chat screen state (`ChatState`, application)

`chatId?`, `title?`, `messages`, `pending?` (`PendingTurn`: the traveller message, `steps` so far), `status` (idle,
loading, sending, busyElsewhere, failed), `failure?`. The transitions:

```text
idle --send--> sending --chat--> sending(+id) --step*--> sending --final--> idle
sending --error | broken stream | refusal--> failed --Try again--> sending
loading (reopen) --busy:true--> busyElsewhere --poll every 5 s, 60 s max--> idle
```

## Cards (`features/chat/data/cards.dart`)

Every card has an envelope: `kind`, `id`, `lat`, `lng`, `approximate`, `foundAt`.

| Card | `item` parsed with | Extra |
|---|---|---|
| `PlanCard` | `PlanSummary` (007, plus `destinationId`, `adults`, `tripBudget`, `pace`, `lat`, `lng`) | — |
| `FlightCard` | `FlightFare` (spec 001) | `match?` (`Match`, spec 007) |
| `HotelCard` | `HotelOffer` (spec 002) | `match?` |
| `CarCard` | `CarOffer` (spec 004) | `match?` |
| `PlaceCard` | `Place` (destination) | — |
| `EventCard` | `TravelEvent` (destination), plus `location?` | — |
| `FactsCard` | `TravelFacts`, a new model: `destination`, `from`, `to`, `weather?`, `visa?`, `currency?`, `safety?`, `holidays` | — |

`CardGroup` (presentation) is `kind`, `cards` (at most 6) and `total?` (from the step, for "See all N"). The Micro label
comes from the kind and whether the cards are ranked ("BEST FLIGHT FOR YOU", "HOTELS THAT FIT YOU BEST", "TOP SIGHTS",
"WHAT'S ON", "TRAVEL INFO").

## Saved (`features/saved/data/saved_models.dart`)

| Model | Fields |
|---|---|
| `SavedKind` | `hotel`, `place`, `event` |
| `SavedItem` | `kind`, `id`, `destinationId`, `destinationName`, `name`, `imageUrl?`, `lat`, `lng`, `savedAt`, `card?` (the stored `item` parsed back into its card, so it opens in Details) |
| `SavedList` | `items`, `count`, `max` |
| `SavedIds` | `hotel`, `place`, `event` (sets of ids) |

Saving sends the card's envelope fields and its raw `item` JSON, as the contract asks. The raw JSON is kept on each
card at parse time for this purpose only.

## Plan additions (`features/itinerary/data/`, extending 007)

| Model | Change |
|---|---|
| `PlanSummary` | `+ destinationId`, `adults`, `tripBudget?`, `pace`, `lat`, `lng` |
| `Plan` | `+ edits` (`PlanEdit`: `day`, `action` (replace, add, remove), `itemId?`, `newItem?` (`kind`, `id`, `name`)) |
| `DayAlternatives` | `day`, `itemId?`, `kind`, `items` (place or event cards plus `walkKmFromDay`), `message?` |
| `RebuildRequest` | `from?`, `to?`, `adults?`, `originId?`, `preferences?`, `pace?`, `tripBudget?` |

Plan-edit failures: `DayFull` (422 `day-full`), `NoPlaces` (422), `PlanFieldError` (400) and `PlanNotFound` (404).

## Side panel (`features/side_panel/application/`)

`SidePanelState`:

- `open`: whether the panel shows.
- `pane`: `trip`, `plan`, `details`, `map` or `saved`.
- `selected?`: the `AssistantCard` shown in Details.
- `planId?`: the plan shown in the Plan pane.

The state is keyed by the chat id (`home` for `/`) and kept for the session. Opening a card sets `pane = details`
and `selected`; opening a plan card sets `pane = plan` and `planId`.

## Appearance (`lib/app/theme/appearance.dart`)

`ThemeMode` is stored as `system`, `light` or `dark` under the `shared_preferences` key `appearance`. A missing or
unknown value means `system`.
