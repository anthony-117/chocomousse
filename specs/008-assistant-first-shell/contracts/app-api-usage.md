# Contract usage: which screen calls which route

The API contracts belong to pamplemousse spec 010 (`specs/010-assistant-v2/contracts/`) and spec 008 (itinerary).
This file only says how the app uses them. Every call goes through `dioProvider`, with the sign-in token. The web
stream goes through `WebChatTransport`, with the same token (research R-1).

| App place | Route | On failure |
|---|---|---|
| Home: Pick up where you left off | `GET /plans` (first 2) | hidden when empty; a skeleton row, then an error row with Try again |
| Composer chips (defaults) | `GET /me` (preferences, pace), latest `GET /assistant/chats` item's `trip` | chips say "Add trip" / "Add preferences" |
| Send, first message | `POST /assistant/chats` (`Accept: text/event-stream`) | refusals and stream errors: data-model "Refusals" |
| Send, next messages | `POST /assistant/chats/{id}/messages` | same |
| Recents | `GET /assistant/chats?limit=30&before=` | "Couldn't load your chats · Try again"; New trip chat still works |
| Reopen a chat | `GET /assistant/chats/{id}` | 404 → "This chat has expired" |
| Rename, delete a chat | `PATCH`, `DELETE /assistant/chats/{id}` | snack bar; nothing changes |
| Search chats | `GET /assistant/chats/search?q=` (2+ characters, 300 ms debounce) | an inline error with Try again |
| Plan pane | `GET /plans/{id}`; Mark as planned `PATCH /plans/{id}`; Change, as 007 | the 007 states |
| Trip pane: Rebuild plan | `POST /plans/{id}/rebuild` | 400 names the field; 422 `no-places`; the plan is unchanged |
| "+" on a hotel or car card | `PUT /plans/{id}/{hotel or car}` (`offerId`) | 400 `offerId` → "This offer isn't among the plan's choices any more"; otherwise, ask in the chat |
| Swap icon, "Ask to change this day…" | sent as a chat message with `about` | as Send |
| Details: hotel | `GET /hotels/{id}` (existing) | details error with Try again, the card's data stays |
| Details: place (OpenTripMap) | `GET /places/{id}` (existing) | same |
| Details: flight, car, event, facts, Wikidata sight | none: from the card | — |
| Bookmark | `PUT` / `DELETE /saved/{kind}/{id}` | reverts the bookmark, snack bar; 409 `too-many-saved` names the limit |
| Bookmarks shown | `GET /saved/ids` | bookmarks show empty; tapping still works |
| Saved pane | `GET /saved` | skeleton, error with Try again, empty message |
| See all N | the existing list routes (`/discover/destination/{id}/hotels`, …) with the card's search | as those screens |

The spec 003 route `POST /assistant/messages` is no longer called.
