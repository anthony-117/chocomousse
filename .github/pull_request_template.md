## Summary
<!-- What changed and why, in a few bullets. Link the approved Figma frame for UI changes. -->

## Tests (required for every feature)
- [ ] Unit tests for new logic (models, repository with a fake Dio adapter, providers)
- [ ] Widget tests for new or changed screens/widgets, including loading, error and empty states
- [ ] Flow test (`test/flows/`) when a new user journey is added
- [ ] Phone (390 px) and desktop layouts checked

## Checks
- [ ] `dart format lib test` leaves nothing to change
- [ ] `flutter analyze --fatal-infos` has no issues
- [ ] `flutter test`: every test passes
- [ ] Design approved in Figma before the code (approval log in the FYP folder)
- [ ] New settings added to `env.dart` **and** `assets/env/app.env.example`
