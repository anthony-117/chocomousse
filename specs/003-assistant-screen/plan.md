# Implementation Plan: Assistant screen

**Branch**: `003-assistant-screen` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Status**: Approved by the owner on 2026-11-04

## Summary

Replace the placeholder Assistant tab with a chat screen built from Figma 09 / W6. A repository posts the conversation to
`/assistant/messages`; a session-wide Riverpod notifier holds the messages, the chat's trip and the sending state; the
screen renders bubbles, ActionCards, suggestions and the input. Cards update `tripSettingsProvider` (and
`departureCityProvider` for flights) and push the matching route. The overview gets an "Ask the assistant" entry.

## Technical Context

**Language/Version**: Dart 3.13 / Flutter 3.47.0 · **Dependencies**: none new (dio, Riverpod, go_router)
**Testing**: unit (models, repository with a fake Dio adapter, notifier), widget (screen states, card taps), flow (overview → assistant → card → hotels)
**Constraints**: no automatic retries; never log chat text; 120-column format; `--fatal-infos`

## Constitution Check

| Principle | How | Result |
|---|---|---|
| I. Feature-First | `features/assistant/{data,application,presentation}`; dio only in `data/`; hand-parsed models | Pass |
| II. Tested | Unit, widget and flow tests listed above, with failure states | Pass |
| III. Zero Lint | Normal gate | Pass |
| IV. Design First | Figma 09 and W6 approved 2026-10-27; plan-editing parts and the conversation list are left out (spec clarifications); states without frames are noted in the PR | Pass |
| V. Never a Blank Screen | Empty state with suggestions; typing bubble; failures keep the chat with Try again; no auto-retry | Pass |
| VI. Backend Only | Only `/api/v1/assistant/messages` | Pass |
| VII/VIII. Cost, Simplicity | No new package, no storage | Pass |

## Project Structure

```text
lib/features/assistant/
├── data/assistant_models.dart          # ChatMessage, ChatRole, AssistantCard, CardKind, AssistantReply, ChatTrip (fromJson/toJson)
├── data/assistant_repository.dart      # POST /assistant/messages, 45 s receive time-out
├── application/chat_controller.dart    # Notifier<ChatState>: messages, trip, sending, failed; send, retry, newChat, startFor(trip)
└── presentation/
    ├── assistant_screen.dart           # layout for phone and wide
    └── widgets/
        ├── chat_bubble.dart            # traveller / assistant / typing / failed
        ├── action_card.dart            # one card, tap → open
        ├── suggestion_chips.dart
        └── chat_input.dart
lib/features/destination/presentation/overview_screen.dart   # + "Ask the assistant" entry
test/assistant/  (fakes.dart, assistant_data_test.dart, chat_controller_test.dart, assistant_screen_test.dart)
test/flows/assistant_flow_test.dart
```

Card → route: `overview` → `/discover/destination/:id` · `places` → `…/places?category=` · `flights` → `…/flights` ·
`hotels` → `…/hotels`. Opening a card switches to the Discover branch and pushes that route.
