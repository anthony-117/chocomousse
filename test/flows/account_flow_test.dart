import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:chocomousse/features/account/data/profile_models.dart';
import 'package:chocomousse/features/account/presentation/widgets/auth_widgets.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../destination/fakes.dart';
import '../helpers.dart';

/// Sign-in and profile through the real app (router guard, screens, session) with Firebase and the API faked.
Widget _app(FakeAuthRepository auth, [FakeProfileRepository? profiles]) => ProviderScope(
  overrides: [
    ...signedIn(auth: auth, profiles: profiles),
    destinationRepositoryProvider.overrideWithValue(
      FakeDestinationRepository(
        countryOptions: const [
          CountryOption(code: 'LB', name: 'Lebanon', flag: null, currencies: ['LBP']),
          CountryOption(code: 'FR', name: 'France', flag: null, currencies: ['EUR']),
        ],
      ),
    ),
    pingProvider.overrideWith(
      (ref) async => PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
    ),
  ],
  child: const TravelGenieApp(),
);

Future<void> _start(WidgetTester tester, FakeAuthRepository auth, [FakeProfileRepository? profiles]) async {
  usePhoneSize(tester, height: 1800);
  await tester.pumpWidget(_app(auth, profiles));
  await tester.pumpAndSettle();
}

void _go(WidgetTester tester, String location) =>
    ProviderScope.containerOf(tester.element(find.byType(TravelGenieApp))).read(routerProvider).go(location);

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

/// Taps without waiting to settle: a spinner keeps animating while a dialog waits for an answer.
Future<void> _tapAndPump(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('signed out', () {
    testWidgets('A1: opens on Welcome, whatever the address', (tester) async {
      await _start(tester, FakeAuthRepository());

      expect(find.text(headline), findsOneWidget);
      for (final (_, line) in benefits) {
        expect(find.text(line), findsOneWidget);
      }
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
      expect(find.byTooltip('Open menu'), findsNothing);

      _go(tester, '/plans');
      await tester.pumpAndSettle();
      expect(find.text(headline), findsOneWidget);
    });

    testWidgets('A1: says which setting is missing when sign-in is not set up', (tester) async {
      await _start(tester, FakeAuthRepository(missingSetting: 'FIREBASE_PROJECT_ID'));
      expect(find.textContaining('Missing setting: FIREBASE_PROJECT_ID'), findsOneWidget);
    });

    testWidgets('Google: signs in and lands on the home; a closed window says nothing', (tester) async {
      final auth = FakeAuthRepository()..failWith = AuthFailure.cancelled;
      await _start(tester, auth);

      await _tap(tester, 'Continue with Google');
      expect(find.text(headline), findsOneWidget);
      expect(find.byType(NoticeBox), findsNothing);

      await _tap(tester, 'Continue with Google');
      expect(auth.calls, ['google', 'google']);
      expect(find.byTooltip('Open menu'), findsOneWidget);
    });

    testWidgets('A2: a wrong password shows the error; the right one goes where the traveller was going', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await _start(tester, auth);
      _go(tester, '/plans');
      await tester.pumpAndSettle();

      await _tap(tester, 'I already have an account');
      expect(find.text('Welcome back. Your plans are waiting.'), findsOneWidget);

      await _tap(tester, 'Sign in');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('email')), 'sam@example.com');
      await tester.enterText(find.byKey(const Key('password')), 'wrong-one');
      auth.failWith = AuthFailure.wrongCredentials;
      await _tap(tester, 'Sign in');
      expect(find.text('Email or password is wrong.'), findsOneWidget);

      await _tap(tester, 'Sign in');
      expect(auth.calls.last, 'email:sam@example.com');
      expect(find.text('My plans'), findsWidgets);
    });

    testWidgets('A3 → A4: create an account, confirm the email, then the home', (tester) async {
      final auth = FakeAuthRepository();
      await _start(tester, auth);

      await _tap(tester, 'Continue with email');
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('At least 8 characters.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('name')), 'Rana');
      await tester.enterText(find.byKey(const Key('email')), 'rana@example.com');
      await tester.enterText(find.byKey(const Key('password')), 'short');
      await _tap(tester, 'Create account');
      expect(find.text('Use at least 8 characters.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('password')), 'long-enough');
      await _tap(tester, 'Create account');
      expect(auth.calls, contains('signUp:Rana:rana@example.com'));
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('We sent a link to rana@example.com.'), findsOneWidget);

      await _tap(tester, "I've confirmed");
      expect(find.text('Not confirmed yet. Open the link in the email first.'), findsOneWidget);

      await tester.tap(find.text('Resend email'));
      await tester.pump();
      expect(find.text('Resend email in 60s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      expect(find.text('Resend email'), findsOneWidget);

      auth.onReload = () => const AuthUser(
        id: 'u2',
        email: 'rana@example.com',
        name: 'Rana',
        emailConfirmed: true,
        method: SignInMethod.password,
      );
      await _tap(tester, "I've confirmed");
      expect(find.byTooltip('Open menu'), findsOneWidget);
    });

    testWidgets('A3: an email that has an account offers Sign in', (tester) async {
      final auth = FakeAuthRepository();
      await _start(tester, auth);
      await _tap(tester, 'Continue with email');

      await tester.enterText(find.byKey(const Key('name')), 'Rana');
      await tester.enterText(find.byKey(const Key('email')), 'rana@example.com');
      await tester.enterText(find.byKey(const Key('password')), 'long-enough');
      auth.failWith = AuthFailure.emailInUse;
      await _tap(tester, 'Create account');

      expect(find.text('This email already has an account.'), findsOneWidget);
      await _tap(tester, 'Sign in');
      expect(find.text('Welcome back. Your plans are waiting.'), findsOneWidget);
    });

    testWidgets('A4: an unconfirmed traveller can sign out', (tester) async {
      final auth = FakeAuthRepository(
        user: const AuthUser(
          id: 'u2',
          email: 'rana@example.com',
          name: 'Rana',
          emailConfirmed: false,
          method: SignInMethod.password,
        ),
      );
      await _start(tester, auth);
      expect(find.text('Check your email'), findsOneWidget);
      expect(auth.calls, contains('reload'));

      _go(tester, '/discover');
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsOneWidget);

      await _tap(tester, 'Sign out');
      expect(find.text(headline), findsOneWidget);
    });

    testWidgets('A5: sends the reset link and says the same thing either way', (tester) async {
      final auth = FakeAuthRepository();
      await _start(tester, auth);
      await _tap(tester, 'I already have an account');
      await _tap(tester, 'Forgot password?');
      expect(find.text('Enter the email you sign in with.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('email')), 'sam@example.com');
      await _tap(tester, 'Send link');
      expect(auth.calls.last, 'reset:sam@example.com');
      expect(
        find.text("If an account exists for sam@example.com, we've sent a link to reset its password."),
        findsOneWidget,
      );

      await _tap(tester, 'Back to sign in');
      expect(find.text('Welcome back. Your plans are waiting.'), findsOneWidget);
    });

    testWidgets('W5: wide screens show the brand panel beside the form', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 1024)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(FakeAuthRepository()));
      await tester.pumpAndSettle();
      _go(tester, '/sign-in');
      await tester.pumpAndSettle();

      expect(find.byType(BrandPanel), findsOneWidget);
      expect(find.text(headline), findsOneWidget);
      expect(find.text('Welcome back. Your plans are waiting.'), findsOneWidget);
    });
  });

  group('signed in', () {
    Future<void> openProfile(WidgetTester tester, FakeAuthRepository auth, FakeProfileRepository profiles) async {
      await _start(tester, auth, profiles);
      await openProfileFromMenu(tester);
    }

    testWidgets('P1: shows the traveller and their travel profile', (tester) async {
      final profiles = FakeProfileRepository(defaultProfile(passport: 'LB', currency: 'USD'));
      await openProfile(tester, FakeAuthRepository(user: confirmedUser), profiles);

      expect(find.text('Sam Haddad'), findsOneWidget);
      expect(find.text('sam@example.com'), findsOneWidget);
      expect(find.text('Signed in with email'), findsOneWidget);
      expect(find.text('Lebanon'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
      expect(find.text("New trips start with these. Changing a trip doesn't change them."), findsOneWidget);
      expect(find.text('Default preferences'), findsOneWidget);
    });

    testWidgets('P1: a profile that fails to load offers Try again', (tester) async {
      final profiles = FakeProfileRepository()..getError = apiRefusal(503, 'service-unavailable');
      await openProfile(tester, FakeAuthRepository(user: confirmedUser), profiles);

      expect(find.text("The server can't do this right now. Try again in a moment."), findsOneWidget);
      profiles.getError = null;
      await _tap(tester, 'Try again');
      expect(find.text('Travel profile'), findsOneWidget);
    });

    testWidgets('P2: edits the name and passport; a refused field shows under it', (tester) async {
      final profiles = FakeProfileRepository();
      await openProfile(tester, FakeAuthRepository(user: confirmedUser), profiles);

      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text("Your email is how you sign in, so it can't be changed here."), findsOneWidget);

      await tester.enterText(find.byKey(const Key('name')), 'Sam H.');
      await _tap(tester, 'Passport');
      await _tap(tester, 'France');

      profiles.updateError = const ProfileFieldErrors({'passport': 'Pick a country.'});
      await _tap(tester, 'Save');
      expect(find.text('Pick a country.'), findsOneWidget);

      profiles.updateError = null;
      await _tap(tester, 'Save');
      expect(profiles.saved?.passport, 'FR');
      expect(find.text('Sam H.'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
    });

    testWidgets('signing out goes back to Welcome', (tester) async {
      final auth = FakeAuthRepository(user: confirmedUser);
      await openProfile(tester, auth, FakeProfileRepository());

      await _tap(tester, 'Sign out');
      expect(auth.calls, contains('signOut'));
      expect(find.text(headline), findsOneWidget);
    });

    testWidgets('P3: delete asks for the password when the sign-in is old, then signs out', (tester) async {
      final auth = FakeAuthRepository(user: confirmedUser);
      final profiles = FakeProfileRepository();
      profiles.deleteErrors.add(apiRefusal(401, 'recent-sign-in-required'));
      await openProfile(tester, auth, profiles);

      await _tap(tester, 'Delete my account');
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(
        find.text("This removes your sign-in, your travel profile and your saved plans. It can't be undone."),
        findsOneWidget,
      );

      await _tapAndPump(tester, 'Delete my account');
      expect(find.text('Sign in again'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('reauth-password')), 'secret-pw');
      await _tap(tester, 'Continue');

      expect(auth.calls, contains('reauth:secret-pw'));
      expect(profiles.deletes, 2);
      expect(find.text(headline), findsOneWidget);
    });

    testWidgets('P3: cancelling the sign-in again deletes nothing', (tester) async {
      final auth = FakeAuthRepository(user: confirmedUser);
      final profiles = FakeProfileRepository();
      profiles.deleteErrors.add(apiRefusal(401, 'recent-sign-in-required'));
      await openProfile(tester, auth, profiles);

      await _tap(tester, 'Delete my account');
      await _tapAndPump(tester, 'Delete my account');
      await _tap(tester, 'Cancel');

      expect(profiles.deletes, 1);
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(auth.calls, isNot(contains('signOut')));
    });
  });
}
