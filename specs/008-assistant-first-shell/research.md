# Research: Assistant-first shell (spec 008)

## R-1 Reading the step stream on the web and on phones

- **Decision**: one `ChatTransport` interface with two implementations, chosen by conditional import.
  - **Android and iOS**: dio with `ResponseType.stream`, through the existing `dioProvider`, so the auth interceptor
    adds the token.
  - **Web**: the browser's `fetch` with `ReadableStream.getReader()`, called through the SDK's `dart:js_interop`.
    The token comes from the same `ApiSession.token()` the interceptor uses. A 401 renews the token once, as the
    interceptor does.
  - Both transports yield raw bytes, decoded by one `SseDecoder`.
  - The stream request has no receive time-out. A watchdog ends it after 30 s with no byte (the server pings every
    10 s).
- **Rationale**: `dio_web_adapter` 2.2.2 (in the lockfile) uses `XMLHttpRequest` with `responseType = 'arraybuffer'`
  and completes only on `onLoad`. Every step would arrive at once with the answer, so FR-015 and SC-005 would fail on
  the web, the main demo platform. `fetch` streams natively. `dart:js_interop` is part of the SDK, so it adds no
  package.
- **Alternatives considered**:
  - `package:web` as a direct dependency (cleaner typed bindings): not approved by the owner on 2026-11-10.
  - `package:http` with `fetch_client`: two new packages.
  - Polling `GET /chats/{id}` while the answer runs: the API has no partial steps in it.
  - Accepting non-live steps on the web: it breaks FR-015.

## R-2 SSE parsing

- **Decision**: a small pure-Dart `SseDecoder`:
  - It turns UTF-8 bytes into events: `event:` and `data:` lines, multi-line `data` joined with `\n`, and a blank line
    ending the event.
  - It ignores comment lines (`: ping`) and handles `\r\n`.
  - `ChatEvent.fromSse(name, json)` maps `chat`, `step`, `final` and `error`. An unknown event name is ignored.
- **Rationale**: the format is small and fixed by the contract. Unit tests cover split chunks (an event cut across
  two reads, a multi-byte character cut in half).
- **Alternatives considered**: an SSE package. It's not needed for four event names, and it would be another
  dependency.

## R-3 Theme v1 tokens and the `AppColors` migration

- **Decision**: an `AppPalette` `ThemeExtension` holding the Figma variables, with const `light` and `dark`
  instances. Every `AppColors.x` use (261 uses in 46 files) moves to a palette token:

  | v0.2 `AppColors` | v1 token |
  |---|---|
  | `primary` | `brandPrimary` |
  | `primarySoft` | `brandPrimarySoft` |
  | `onPrimary` | `brandOnPrimary` |
  | `accent` | `brandAccent` |
  | `canvas` | `bgApp` |
  | `surface` | `bgSurface` |
  | `text` | `textPrimary` |
  | `muted` | `textSecondary` |
  | `border` | `borderDefault` |
  | `success` | `statusSuccess` |
  | `warning` | `statusWarning` |
  | `danger` | `statusDanger` (not in the v1 file: light `#D64545` as in v0.2, dark `#F07A7A`; and `statusDangerSoft`) |

  These v1 tokens have no v0.2 equivalent: `bgSidebar`, `bgSubtle`, `bgHover`, `textTertiary`,
  `brandAccentSoft`, `statusSuccessSoft`, `statusWarningSoft`.
- **Rationale**: the colours must change with the mode, so const statics can't stay. A ThemeExtension is Flutter's
  standard place for design tokens that `ColorScheme` doesn't cover.
- **Owner decision (2026-11-10)**: the v1 file has no danger colour. The app keeps v0.2's red and adds a lighter
  dark-mode red (contrast 4.5:1 on `bgApp`). Both are to be added to the v1 Figma variables as `status/danger` and
  `status/danger-soft`.
- **Alternatives considered**: `ColorScheme` slots only. There aren't enough slots, and the names drift from Figma.

## R-4 Icons

- **Decision**: export the 37 symbols of "v1 / Icons" (node 2301:923) as SVG to `assets/icons/`, and draw them with
  `flutter_svg` (already a dependency) through `AppIcon`, tinted with `ColorFilter`.
- **Rationale**: it matches the approved design exactly, adds no package, and Lucide is ISC-licensed.
- **Alternatives considered**: a Lucide icon-font package (a new dependency, and the stroke differs from the 1.75
  design); Material icons (they don't match the design).

## R-5 Routes after the tabs

- **Decision**: one `ShellRoute` instead of `StatefulShellRoute.indexedStack`. The routes inside it:
  - `/`: the home and a new chat.
  - `/chat/:chatId`: a chat.
  - `/saved`: the home with the Saved pane open.
  - The existing `/discover/...`, `/plans/...` and `/profile/...`, unchanged.

  `/assistant` and the old post-sign-in target `/discover` redirect to `/`. A new chat's address changes from `/` to
  `/chat/{id}` on the `chat` event, with `GoRouter.replace`, so Back doesn't return to an empty home.
- **Rationale**: the v1 shell has no tabs to keep separate stacks for. The sidebar navigates and Back works as a
  stack.
- **Alternatives considered**: keeping the branches. They model four tabs the design no longer has.

## R-6 Side panel layout

- **Decision**:
  - Wide screens (≥ `kWideLayoutBreakpoint` 900 px): `Row(sidebar, chat (flex), panel 520 px)`. When the panel is
    open below 1200 px, the sidebar collapses to its rail so the chat keeps at least 360 px.
  - Below 900 px: a modal `DraggableScrollableSheet` (initial 0.9, min 0.5), with the same `PanelIconBar` and panes.
  - The state lives in `SidePanelController`, keyed by the chat id (`home` for `/`), so each chat reopens on its last
    pane (FR-019).
- **Rationale**: it matches W2 and M3 and the approved side-panel frames, and keeps one pane implementation for both
  layouts.
- **Alternatives considered**: a route per pane. Deep links to panes aren't asked for, and a route would make the
  chat rebuild.

## R-7 Map pane without a map service

- **Decision**: `PinPreview`, a `CustomPaint` drawing:
  - the pins of the current cards, by kind (hotel, place, event, car pick-up, plan day), placed by an equirectangular
    projection of their bounding box with 12 % padding. Cities span a few km, so the distortion is negligible.
  - a scale bar.
  - `approximate` pins hollow, with a legend: "Some places show the city centre".

  A list under the canvas repeats the pins. A tap on a pin or a row opens Details.
- **Rationale**: the owner chose the pin preview on 2026-11-10. ADR 0008 already planned it until a Google Maps key
  exists; it's $0, needs no package and makes no third-party call.
- **Alternatives considered**: OpenStreetMap tiles with `flutter_map` (a new package and a direct third-party call,
  ADR needed); Google Maps (billing card).

## R-8 The AI notice

- **Decision**: the notice under the composer reads "Messages are answered by an AI service and may be used to
  improve it. Don't share personal details."
- **Rationale**: spec 010 makes the provider a setting (Gemini or Groq). A notice naming Gemini could be wrong.
  FR-014 of spec 003 still holds in substance.
- **Alternatives considered**: naming the provider. That needs a route or a setting the app can read, which isn't in
  the contract.
