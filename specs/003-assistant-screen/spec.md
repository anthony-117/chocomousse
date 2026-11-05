# Feature Specification: Assistant screen

**Feature Branch**: `003-assistant-screen`

**Created**: 2026-11-04

**Status**: Approved by the owner on 2026-11-04. Design: Figma v0.2 mobile 09 and web W6, approved 2026-10-27

**Input**: User description: "Work now on the assistant sprint. I am using Gemini and I already added its API key." The API is
specified on the `003-assistant` branch of `pamplemousse`: [spec](https://github.com/anthony-117/pamplemousse/blob/003-assistant/specs/003-assistant/spec.md)
and [contract](https://github.com/anthony-117/pamplemousse/blob/003-assistant/specs/003-assistant/contracts/assistant-api.md).

## Clarifications

### Session 2026-11-04

- Q: The designs show plan editing ("Editing · Rome Complete", "PLAN UPDATED" card). → A: No plan exists yet (Sprint 4). The header says which trip the chat is about ("About Rome · 10 – 15 Apr"), or "Ask about any city" with no trip. The ActionCard style is used for links into screens ("Hotels in Rome · 10 – 15 Apr · 2 adults").
- Q: W6 has a conversation list on the left. → A: Left out: there are no accounts, so there is one conversation per session. W6's chat column is built; "New chat" sits in the header.
- Q: Where is the conversation kept? → A: In memory for the app session (a Riverpod notifier that is not auto-disposed), so leaving the tab keeps it; reloading the web app clears it.
- Q: How does a city's trip reach the assistant? → A: An "Ask the assistant" entry on the overview sets the chat's trip to that city and the shared trip settings, then opens the Assistant tab.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Chat with the assistant (Priority: P1)

Fares opens the Assistant tab, taps a suggestion or types a question, sees their message at once, a typing indicator,
then the reply.

**Independent Test**: With a fake assistant repository, send a message and check the user bubble, typing state and reply bubble
at 390 px and desktop width.

**Acceptance Scenarios**:

1. **Given** an empty chat, **When** the tab opens, **Then** a greeting, the Gemini notice and suggestion chips show; tapping a chip sends it.
2. **Given** a message is sent, **When** waiting, **Then** the traveller's bubble shows on the right, the input is disabled, and a typing bubble shows on the left.
3. **Given** a reply arrives, **When** it has text, **Then** it shows in an assistant bubble on the left; warnings show in a small note under it.
4. **Given** a reply with only warnings (not configured or busy), **When** it arrives, **Then** the warning shows as the assistant's message with Try again.

### User Story 2 - Open what the assistant found (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a reply with cards, **When** it shows, **Then** each card shows in the ActionCard style under the reply (kind label, title, subtitle).
2. **Given** a hotels, flights, places or overview card, **When** Fares taps it, **Then** the shared trip settings take the card's dates and adults (and departure city for flights), and the matching screen opens for that city.

### User Story 3 - Ask about the city I'm looking at (Priority: P2)

**Acceptance Scenarios**:

1. **Given** the overview of Rome, **When** Fares taps "Ask the assistant", **Then** the Assistant tab opens with the header "About Rome · dates", and messages carry that trip as context.
2. **Given** a chat about Rome, **When** Fares taps "New chat", **Then** the conversation and its trip are cleared.

### Edge Cases

- Request fails (server down, time-out, 5xx): the traveller's message stays, marked "Not sent", with Try again; no automatic retry.
- Message longer than 1,000 characters: the input stops at 1,000.
- More than 20 messages: only the last 20 are sent.
- Long replies: bubbles wrap; the list scrolls to the newest message.
- Empty input: send is disabled.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Assistant tab MUST follow Figma 09 (phone) and the chat column of W6 (web): logo + title header, bubbles (traveller right in indigo, assistant left in white), ActionCards, suggestion chips, input with send button, above the floating nav on phones.
- **FR-002**: The app MUST call only `POST /api/v1/assistant/messages`, through a repository in `data/`.
- **FR-003**: The conversation MUST live in a session-wide notifier; "New chat" clears it.
- **FR-004**: Cards MUST open existing routes after updating the shared trip settings.
- **FR-005**: The overview MUST offer "Ask the assistant" with that city as context.
- **FR-006**: The screen MUST show the notice "Answers come from Google Gemini using TravelGenie's data. Don't share personal details."
- **FR-007**: Loading, error and empty states follow the screen's layout without their own Figma frames (constitution IV); the PR says so.
- **FR-008**: Chat text MUST NOT be logged.
- **FR-009**: When the API answers `429` (pamplemousse spec 003, FR-015: too many messages), the message is marked "Not sent. Too many messages. Wait a minute and try again." with Try again. Added 2026-11-05, approved by the owner.

## Success Criteria *(mandatory)*

- **SC-001**: Widget tests cover empty, sending, reply, reply with cards, warning-only and failed states; a flow test covers overview → Ask the assistant → reply → card → hotels screen.
- **SC-002**: Checked live against the API with Gemini at 390 px and desktop width.

## Assumptions

- The receive time-out for this one call is 45 s (the server's Gemini limit is 30 s plus tool calls).
- Plan editing, saved conversations and streaming come later.
