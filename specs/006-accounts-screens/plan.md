# Implementation Plan: Sign-in and profile screens

**Branch**: `006-accounts-screens` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Status**: Approved by the owner on 2026-11-06, with ADR 0020 and constitution 1.1.0

## Summary

Add an `account` feature:
- **Firebase Authentication** (email and password, Google) behind an `AuthRepository`, so tests never touch Firebase;
- **a router guard** that allows only the sign-in screens until the traveller is signed in with a confirmed email;
- **a dio interceptor** that adds the ID token to every request, renews it once on a 401, then signs out;
- **the screens** A1–A5 and W5 (sign-in) and P1–P3 (profile, edit, delete) on `GET`, `PUT` and `DELETE /api/v1/me`.

The profile fills the trip settings once after sign-in. Sign out clears everything held for the traveller.

## Technical Context

**Language/Version**: Flutter 3.47.0, Dart 3.13.0

**Primary Dependencies**:
- Riverpod 3, go_router, dio, as today.
- New: `firebase_core` 5.1.0 and `firebase_auth` 7.0.1 (Google, free). Needed because the app now signs in with
  Firebase (API ADR 0019). They are pinned to a release at least two weeks old when the code starts.

**Storage**: Firebase keeps the sign-in on the device (IndexedDB on the web, the keystore on Android). Nothing else
is stored locally.

**Testing**: `flutter_test` with a `FakeAuthRepository` and a fake account API. No Firebase in tests.

**Target Platform**: Web and Android, at 390 px and wide. iOS later (spec).

**Constraints**: About $0 (Firebase Authentication is free at this size). No secret in the app.

## Constitution Check

| Principle | How the plan meets it | Result |
|---|---|---|
| I Feature-First | New `lib/features/account/` with `data/` (Firebase and `/me`), `application/` (session, profile) and `presentation/`. The interceptor and the router guard are in `lib/core/` and `lib/app/`, since every feature uses them | Pass |
| II Tested | Unit tests for the models, the `/me` repository, the interceptor (token, renew, sign out), the session and the router guard. Widget tests for every state of A1–A5, P1–P3 and W5. Flow tests: sign in → Discover; sign up → check email → in; delete. Checked at 390 px and desktop | Pass |
| III Zero Lint | Normal gate | Pass |
| IV Design First | Figma A1–A5, P1–P3, W5 approved 2026-11-06 | Pass |
| V Never a Blank Screen | Profile shows placeholder rows while loading and its error with Try again; sign-in buttons show progress in place; nothing retries by itself | Pass |
| VI Backend Only | Data only from `/api/v1`. **Firebase Authentication is a direct use of Firebase, which needs an ADR**: ADR 0020 in `pamplemousse` (see Complexity Tracking) | Pass with ADR |
| VII Low Cost | Free tier; no new paid service | Pass |
| VIII Simplicity | Firebase's own Google sign-in, no second package; one interceptor; one guard | Pass |
| Configuration and Security | Firebase settings through `env.dart` and `app.env.example`. **The Firebase API keys are public identifiers, not secrets, but the constitution only allows a Maps key**: amendment 1.1.0 (see Complexity Tracking). No email, name or token in logs | Pass with amendment |

## Design decisions

1. **Settings** (`env.dart`, `app.env.example`):
   - `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_MESSAGING_SENDER_ID`;
   - `FIREBASE_WEB_APP_ID`, `FIREBASE_WEB_API_KEY`;
   - `FIREBASE_ANDROID_APP_ID`, `FIREBASE_ANDROID_API_KEY`.
   
   `firebaseOptions()` picks the platform's set; `null` when any is blank. `main` initialises Firebase only when the
   options exist; otherwise the app runs with a `NotConfiguredAuthRepository` (spec Edge Cases).
2. **`AuthRepository`** (`account/data`). Firebase's types never leave this file.
   - **State**: `Stream<AuthUser?> changes()` and `AuthUser? current`, where `AuthUser` has id, email, name,
     `emailConfirmed` and `provider` (`google` or `password`).
   - **Signing in and out**: `signInWithGoogle()`, `signInWithEmail(email, password)`,
     `signUp(name, email, password)` (then sends the confirmation), `sendPasswordReset(email)`, `signOut()`.
   - **Confirming the email**: `resendConfirmation()`, and `reloadUser()`, which reloads the user and renews the token
     so the API sees the confirmation.
   - **Before a delete**: `reauthenticate({String? password})`, by Google again or by password.
   - **Tokens**: `idToken({bool refresh = false})`.
   - **Errors**: one `AuthFailure` enum mapped from Firebase's codes: `wrongCredentials`, `emailInUse`,
     `weakPassword`, `invalidEmail`, `tooManyRequests`, `network`, `cancelled`, `notConfigured`, `other`.
     `cancelled` (closing the Google window) shows nothing.
   - **Google**: `signInWithPopup` on the web and `signInWithProvider` on Android, both with `GoogleAuthProvider`.
3. **Session** (`account/application`). `authUserProvider` is a `StreamProvider` on `changes()`. A `SessionGate`
   `ChangeNotifier` tells the router when it changes.
4. **Router guard** (`lib/app/router.dart`). Top-level routes `/welcome`, `/sign-in`, `/sign-up`,
   `/forgot-password` and `/check-email`, outside the shell. A `redirect`, re-run by the session gate, sends:
   - signed out, on any other route → `/welcome?from=<where>`;
   - signed in but unconfirmed → `/check-email`;
   - signed in and confirmed, on a sign-in route → `from` (only an in-app path), else `/discover`.
   
   While Firebase is still restoring the sign-in, a plain splash in the theme shows, never Welcome (SC-002).
5. **Interceptor** (`lib/core/network/auth_interceptor.dart`, a `QueuedInterceptor` on the shared dio):
   - Adds `Authorization: Bearer <idToken()>` to every request.
   - On a 401 with `sign-in-required`, renews the token once and retries; a second 401 signs out.
   - On a 403 with `email-not-confirmed`, calls `reloadUser()`, so the guard shows Check your email.
   - On a 401 with `recent-sign-in-required`, passes it to the caller, which is only the delete.
   - `describeApiError` gains messages for 401, 403 and 503 `sign-in-not-configured`.
6. **Profile data** (`account/data/profile_repository.dart`): `get()`, `update(ProfileForm)` and `delete()` on
   `/me`. Models are parsed by hand. A 400 is read into field errors (`displayName`, `passport`, …) for the form.
7. **Profile → trip settings** (FR-005). After sign-in, `ProfileSeeder` reads the profile once and calls the trip
   settings' setters (passport, currency, preferences) and the departure city's (home city). If the read fails, the
   defaults stay and Profile shows the error.
8. **Sign out** (FR-006). `SessionController.signOut()` signs out of Firebase, then invalidates the traveller's
   providers: trip settings, departure city, profile, assistant conversation and the ranked lists. The router goes
   to Welcome with `go` (not `push`), so Back can't return.
9. **Screens**:
   - **A1 Welcome**: logo, headline, the three benefit lines, Continue with Google (`GoogleButton`), Continue with
     email (to Create an account), I already have an account (to Sign in), and the terms line as text.
   - **A2 Sign in / W5**: email, password with show/hide, Sign in, Google, Forgot password, and New here. Errors in
     the A2 banner. On wide screens, W5: the benefits panel on the left and the form on the right.
   - **A3 Create an account**: name, email, password with "At least 8 characters", and the confirmation note.
     "Email in use" shows "This email already has an account." with a Sign in link.
   - **A4 Check your email**: the address, I've confirmed it (`reloadUser`), Resend the email (60 s wait, a countdown
     on the button), and Sign out.
   - **A5 Forgot password**: email, Send link, then the neutral message and Back to sign in.
   - **P1 Profile**: avatar initial, name, email and provider; Travel profile with Edit; Default preferences with
     Edit; Sign out; Delete my account; the Server line at the bottom.
   - **P2 Edit profile**: name, passport and currency (from `/countries`), home city (the existing city search
     field), and the six sliders reused from `PreferencesForm`; Save. Pace is left out (spec).
   - **P3 Delete my account**: a sheet with the text, and Delete my account (danger). On
     `recent-sign-in-required` it asks for the password, or opens Google, then retries.
10. **Shell and Profile tab**: the floating nav and web header are unchanged. The Profile tab shows P1 instead of
    "Guest".

## Project Structure

```text
specs/006-accounts-screens/                  spec.md, plan.md
lib/env.dart                                  Firebase settings
lib/main.dart                                 Firebase.initializeApp when configured
lib/app/router.dart                           sign-in routes, guard, splash
lib/core/network/api_client.dart              interceptor added; describeApiError messages
lib/core/network/auth_interceptor.dart        new
lib/features/account/
├── data/auth_repository.dart                 AuthRepository, FirebaseAuthRepository, NotConfiguredAuthRepository, AuthUser, AuthFailure
├── data/firebase_settings.dart               options from Env
├── data/profile_models.dart                  Profile, ProfileForm, field errors
├── data/profile_repository.dart              /me
├── application/session.dart                  authUserProvider, SessionGate, SessionController, ProfileSeeder
├── application/profile_providers.dart
└── presentation/
    ├── welcome_screen.dart                   A1
    ├── sign_in_screen.dart                   A2, W5
    ├── sign_up_screen.dart                   A3
    ├── check_email_screen.dart               A4
    ├── forgot_password_screen.dart           A5
    ├── profile_screen.dart                   P1 (replaces features/profile)
    ├── edit_profile_screen.dart              P2
    └── widgets/ google_button.dart · auth_frame.dart (phone and W5 layout) · delete_account_sheet.dart (P3) · reauth_dialog.dart
test/account/                                 fakes.dart, models, repository, interceptor, session, guard, every screen state
test/flows/account_flow_test.dart             sign in → Discover; sign up → check email → in; edit profile → trip settings; delete → Welcome
```

## Delivery order

1. **ADR 0020 and the constitution amendment**, for the owner's OK with this plan.
2. **Settings and `AuthRepository`**, with the not-configured path.
3. **Session, router guard and interceptor**. Every existing test signs in a fake traveller through one helper.
4. **A1–A5 and W5**, with tests.
5. **P1–P3** and the profile → trip settings seeding, with tests.
6. **Live check** against the local API of `009-accounts`, on the web at 390 px and desktop, and on the Android
   emulator:
   - sign up, confirm the email and get in;
   - Google sign-in;
   - wrong password;
   - reset the password;
   - edit the profile on the web and see it on Android;
   - sign out;
   - delete a test account.
   
   The owner does the Google and real-inbox steps; I do the rest.
7. **Docs**: README (settings, routes), the sprint 4 log in `pamplemousse`.

The pull request is merged together with `pamplemousse`'s `009-accounts`, and the two are released together.

## Owner actions before the live check

- **Firebase console, Authentication**:
  - turn Anonymous off;
  - check `localhost` and `travelgenie-1fdd1.web.app` are authorized domains;
  - set the confirmation and reset email templates.
- **Firebase console, Project settings**:
  - register the Android app `com.travelgenie.chocomousse`, if not already done;
  - add its debug SHA-1 (`cd android && ./gradlew signingReport`);
  - copy the web and Android settings into `assets/env/app.env`.
- **Approve ADR 0020 and constitution 1.1.0** with this plan.

## Risks

| Risk | Effect | Response |
|---|---|---|
| Google sign-in on Android fails without the right SHA-1 | Google button errors on Android | Email sign-in still works; the live check catches it; the owner adds the fingerprint |
| Pop-ups blocked on the web | Google sign-in seems to do nothing | The `popup-blocked` code shows "Allow pop-ups for this site, then try again." |
| `firebase_auth` 7 is new (15 Oct) | Unknown bugs | Pin the version; fall back to 6.7.1 if the live check shows a problem |
| Every existing test now needs a signed-in traveller | Many test edits | One test helper signs in a fake traveller in the shared `ProviderScope` |
| The token isn't renewed after confirming the email | Stuck on Check your email | `reloadUser()` forces a renewal; tested |

## Complexity Tracking

| Item | Why it's needed | Simpler option rejected because |
|---|---|---|
| ADR 0020 "The app signs in with Firebase Authentication" (constitution VI) | The owner decided sign-in is required (API spec 009); Firebase Auth is the chosen provider (ADR 0019) | A sign-in through our own API would mean storing passwords ourselves |
| Constitution 1.1.0: allow Firebase's public app settings in `app.env` | Firebase needs its API key in the client; Google documents it as an identifier, not a secret, protected by authorized domains and app fingerprints | Fetching them from our API at start adds a request and a failure point for no security gain |
