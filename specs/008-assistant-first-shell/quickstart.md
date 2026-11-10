# Quickstart: checking spec 008

## Prerequisites

- chocomousse PR #18 (007 itinerary screens) merged, and this branch rebased on main.
- For live checks: pamplemousse on `010-assistant-v2` (or main once it's merged), running locally with a chat model
  key, Firestore and sign-in configured as its quickstart says. `assets/env/app.env` has `API_BASE_URL` pointing at it.
- A test account (spec 006), created in this session's local setup.

## Automated

```bash
flutter analyze --fatal-infos
```

```bash
dart format --set-exit-if-changed lib test
```

```bash
flutter test
```

```bash
flutter build web --release
```

The flow tests in `test/flows/`, all against fakes:

| Flow | Proves |
|---|---|
| `assistant_first_flow_test` | sign in → home (greeting, chips, suggestions) → send → the steps appear one by one → the answer with plan, flight and hotel cards → Open plan opens the Plan pane → "+" on a hotel swaps it → the panel shows the new hotel |
| `chat_recents_search_flow_test` | Recents lists chats → open one → continue it → search "jazz" finds it → rename → delete |
| `saved_flow_test` | bookmark a hotel and a place → Saved pane groups them → open one in Details → remove it |
| `side_panel_flow_test` | the Trip, Plan, Details, Map and Saved panes from the icon bar; the panel at 1440 px and the sheet at 390 px |
| `tools_sheet_flow_test` | "+" → each tool fills the composer and doesn't send; Set trip dates updates the chip |
| `explore_from_shell_flow_test` | Explore → Discover → a city → hotels; My plans; the profile from the account menu; a v0.2 deep link still opens |
| `appearance_flow_test` | Appearance Dark → the dark tokens; a restart with the stored choice keeps it |

## In the running app (constitution II)

At 390 px and 1440 px, in light and in dark:

1. Home shows the greeting with the first name, the composer with both chips, and the suggestions for the eight
   features.
2. "Plan 5 days in Rome for two, from Beirut, under $1,200":
   - the step lines appear one at a time (on the web too);
   - the plan card opens the Plan pane beside the chat (1440) or as a sheet (390).
3. "Rent a car in Lisbon", "Top sights in Paris", "What's on this weekend in Paris" and "Visa and weather for
   Istanbul" each show their card kind. "See all N" opens the list.
4. From the Plan pane:
   - swap a day item, which shows the alternatives in the chat;
   - pick one, and the day is rebuilt;
   - Rebuild plan from the Trip pane with a new pace.
5. Bookmark a hotel and check Saved. Reload the app and check the bookmark is still filled.
6. Open the same account in a second browser and check that the chat is in Recents.
7. Stop the API mid-answer: the steps stay, and the error offers Try again.
8. Compare each screen with its Figma frame (SC-006) and check contrast in dark (SC-007).
