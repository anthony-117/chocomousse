# Feature Specification: Sign-in and profile screens

**Feature Branch**: `006-accounts-screens`

**Created**: 2026-11-06

**Status**: Approved by the owner on 2026-11-06. Design: Figma page "Sprint 4 — Accounts & itinerary", A1–A5, P1–P3 and W5, approved 2026-11-06

**Input**: User description: "TG-17: As Fares, I want to sign in with email or Google so my plans and travel profile are mine on every device." The API is built in `pamplemousse` on `009-accounts`: [spec](https://github.com/anthony-117/pamplemousse/blob/009-accounts/specs/009-accounts/spec.md), [contract](https://github.com/anthony-117/pamplemousse/blob/009-accounts/specs/009-accounts/contracts/accounts-api.md) and ADR 0019.

The rules are the API spec's (FR-001 to FR-017, Edge Cases). This spec says how the app meets them.

## Clarifications

### Session 2026-11-06

Confirmed by the owner with the spec on 2026-11-06.

- Q: How does the app sign in with Google? → A: Through Firebase Authentication alone: a pop-up on the web, and Firebase's own Google sign-in page on Android. No separate Google sign-in package. Android needs the app's SHA-1 fingerprint in the Firebase console (owner).
- Q: Where do the Firebase settings come from? → A: From `assets/env/app.env`, read through `lib/env.dart`: the project id, the web and Android app ids, their API keys, the sender id and the auth domain. These identify the project and are public by design (Firebase's documentation), but the constitution only allows a Maps key in the app, so it needs a small amendment. Without them, the welcome screen says sign-in isn't set up, naming the setting, and nothing crashes.
- Q: Which screens are reachable signed out? → A: Welcome (A1), Sign in (A2 / W5), Create an account (A3) and Forgot password (A5). Signed in with an unconfirmed email: only Check your email (A4). Any other link opens Welcome and, once signed in, goes where it pointed.
- Q: What do new trips start from? → A: The profile: passport, home currency, departure city (home city) and the six preferences fill the trip settings once after sign-in. Changing a trip doesn't change the profile.
- Q: Pace in Edit profile (P2)? → A: It comes with the itinerary (TG-10), when the API adds it. This feature leaves it out.
- Q: "By continuing you agree to the Terms and the Privacy Policy" (A1)? → A: Shown as plain text until the owner provides the two documents; then they become links. Google Play needs a privacy policy before the Android app is published.
- Q: The Backend status card on Profile? → A: It moves to the bottom of Profile as a small "Server" line, so the end-to-end check stays.
- Q: iOS? → A: Not in this feature (API spec: Sign in with Apple needs a paid account).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sign in to use the app (Priority: P1)

Fares opens TravelGenie for the first time and sees Welcome. They choose Continue with Google and land on
Discover. Next time, they are still signed in.

**Independent Test**: Open the app signed out and confirm only the sign-in screens are reachable, by tapping or by
typing a web address; sign in with Google and with a confirmed email; reopen the app and land on Discover.

**Acceptance Scenarios**:

1. **Given** Fares is signed out, **When** they open any app address, **Then** they see Welcome, and after signing in they land where the address pointed (or Discover).
2. **Given** Welcome, **When** Fares chooses Continue with Google and picks an account, **Then** they are signed in. **When** they close the Google window, **Then** they stay on Welcome with no error.
3. **Given** Sign in, **When** Fares enters a confirmed email and the right password, **Then** they are signed in; with a wrong one, **Then** "Email or password is wrong." shows under the fields (A2).
4. **Given** Fares signed in before, **When** they reopen the app, **Then** they reach Discover without Welcome, in under 3 seconds on the web.
5. **Given** Profile, **When** Fares chooses Sign out, **Then** Welcome shows, Back can't reach their screens, and their trip settings and assistant chat are cleared.
6. **Given** the API answers 401 `sign-in-required`, **Then** the app renews the sign-in once and retries; if it still fails, it signs out to Welcome.

### User Story 2 - Create an account with email (Priority: P1)

**Acceptance Scenarios**:

1. **Given** Create an account, **When** Maya enters a name, an email and a password of at least 8 characters, **Then** the account is made, the confirmation email is sent and Check your email (A4) shows her address.
2. **Given** Check your email, **When** she chooses I've confirmed it before opening the link, **Then** "Not confirmed yet. Open the link in the email first." shows; after opening it, **Then** she is let in.
3. **Given** Check your email, **When** she chooses Resend the email, **Then** it is sent again and the button waits 60 seconds before it can be used again.
4. **Given** an email that already has an account, **Then** she is told to sign in instead, with a link to Sign in.
5. **Given** Forgot password, **When** she enters an email, **Then** A5's message shows whether or not the email has an account.
6. **Given** a bad email or a short password, **Then** the field says so before anything is sent.

### User Story 3 - Keep my travel profile (Priority: P2)

**Acceptance Scenarios**:

1. **Given** Profile (P1), **Then** it shows the name, email, how they signed in, passport, home currency, home city and the six default preferences.
2. **Given** Edit profile (P2), **When** Fares changes any field and saves, **Then** Profile shows it, and it is kept on every device.
3. **Given** a saved profile, **When** Fares signs in, **Then** new trips start with its passport, currency, departure city and preferences.
4. **Given** the profile can't be loaded, **Then** Profile shows the error with Try again, and trips use the app's defaults.
5. **Given** a field the API refuses, **Then** the message shows on that field.

### User Story 4 - Delete my account (Priority: P2)

**Acceptance Scenarios**:

1. **Given** Profile, **When** Fares chooses Delete my account, **Then** the sheet (P3) says what is removed and asks to confirm.
2. **Given** they confirm, **Then** the account is deleted and Welcome shows.
3. **Given** a sign-in older than 5 minutes, **Then** they are asked to sign in again (Google, or their password) and the delete continues.
4. **Given** the delete fails, **Then** the sheet shows the error with Try again, and they stay signed in.

### Edge Cases

- **No connection or Firebase unreachable** while signing in: "Sign-in isn't possible right now." with Try again.
- **Firebase settings missing** in `app.env`: Welcome says sign-in isn't set up, naming the setting; the buttons are off.
- **Too many attempts**: Firebase's message, in plain words ("Too many tries. Wait a few minutes.").
- **Email confirmed on another device**: I've confirmed it, or reopening the app, lets Maya in.
- **API 403 `email-not-confirmed`** while in the app: the app renews its sign-in and shows Check your email if still unconfirmed.
- **API 503 `sign-in-not-configured`**: the screen's error says the server's sign-in isn't set up.
- **Phone and wide screens**: every screen works at 390 px and on the web from `kWideLayoutBreakpoint` (W5 layout).

## Requirements *(mandatory)*

- **FR-001**: The app MUST use Firebase Authentication (email and password, Google) on web and Android, configured from `app.env`.
- **FR-002**: Every API request MUST carry the signed-in traveller's ID token; a 401 MUST renew it once and retry, then sign out.
- **FR-003**: The router MUST allow only the sign-in screens while signed out, and only Check your email while unconfirmed.
- **FR-004**: The screens MUST follow the approved frames A1–A5, P1–P3 and W5.
- **FR-005**: The profile MUST fill the trip settings once after sign-in (passport, currency, departure city, preferences).
- **FR-006**: Sign out MUST clear the sign-in and every traveller-specific value the app holds.
- **FR-007**: Delete my account MUST confirm, sign in again when the API asks, call `DELETE /api/v1/me`, then sign out locally.
- **FR-008**: Emails, names, tokens and profile values MUST NOT be logged or shown in error reports.
- **FR-009**: Messages MUST NOT say whether an email has an account (sign-in errors, forgot password).

## Success Criteria *(mandatory)*

- **SC-001**: Signed out, no screen other than the sign-in screens can be reached, by tapping or by address (web and Android).
- **SC-002**: A returning traveller reaches Discover in under 3 seconds on the web.
- **SC-003**: Every existing screen still loads its data once signed in (live check against the API of `009-accounts`).
- **SC-004**: A profile edited on the web shows on Android after signing in there.

## Assumptions

- The owner has done, or does before the live check, in the Firebase console: Anonymous off; the web app and Android app registered; the Android SHA-1; `localhost` and the hosting domain authorized; the email templates.
- The owner copies the Firebase web and Android settings into `assets/env/app.env` (the plan lists them).
- The API of `009-accounts` is merged and deployed together with this feature.
