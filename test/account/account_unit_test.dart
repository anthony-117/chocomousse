import 'dart:convert';
import 'dart:typed_data';

import 'package:chocomousse/app/auth_guard.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/network/auth_interceptor.dart';
import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:chocomousse/features/account/data/firebase_settings.dart';
import 'package:chocomousse/features/account/data/profile_models.dart';
import 'package:chocomousse/features/account/data/profile_repository.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Answers each request with the next queued reply and records what was sent.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.replies);

  final List<(int, Object?)> replies;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(options);
    final (status, data) = replies.removeAt(0);
    return ResponseBody.fromString(
      data == null ? '' : jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Session implements ApiSession {
  _Session({this.first = 't1', this.renewed = 't2'});

  final String? first;
  final String? renewed;
  final calls = <String>[];

  @override
  Future<String?> token({bool refresh = false}) async {
    calls.add(refresh ? 'refresh' : 'token');
    return refresh ? renewed : first;
  }

  @override
  Future<void> signInRejected() async => calls.add('rejected');

  @override
  Future<void> emailNotConfirmed() async => calls.add('reload');
}

(Dio, _Adapter) _dio(ApiSession session, List<(int, Object?)> replies) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'));
  final adapter = _Adapter(replies);
  dio
    ..httpClientAdapter = adapter
    ..interceptors.add(AuthInterceptor(session, dio));
  return (dio, adapter);
}

const _unconfirmed = AuthUser(
  id: 'u2',
  email: 'new@example.com',
  name: 'New',
  emailConfirmed: false,
  method: SignInMethod.password,
);

Map<String, Object?> _profileJson({Map<String, Object?>? city, Map<String, Object?>? weights}) => {
  'displayName': 'Sam',
  'email': 'sam@example.com',
  'passport': 'LB',
  'homeCurrency': 'USD',
  'homeCity': city,
  'preferences': weights ?? {'budget': 90, 'culture': 10, 'food': 50, 'nature': 50, 'nightlife': 50, 'comfort': 50},
};

void main() {
  group('authRedirect', () {
    const signedOut = AsyncValue<AuthUser?>.data(null);
    const confirmed = AsyncValue<AuthUser?>.data(confirmedUser);
    const unconfirmed = AsyncValue<AuthUser?>.data(_unconfirmed);

    test('waits on the splash while the saved sign-in is restored, keeping the address', () {
      expect(authRedirect(const AsyncValue.loading(), Uri.parse('/plans')), '/starting?from=%2Fplans');
      expect(authRedirect(const AsyncValue.loading(), Uri.parse('/starting')), isNull);
    });

    test('sends a signed-out traveller to Welcome and lets them use the sign-in screens', () {
      expect(authRedirect(signedOut, Uri.parse('/discover')), '/welcome');
      expect(
        authRedirect(signedOut, Uri.parse('/discover/destination/x')),
        '/welcome?from=%2Fdiscover%2Fdestination%2Fx',
      );
      for (final path in AuthPaths.signedOut) {
        expect(authRedirect(signedOut, Uri.parse(path)), isNull, reason: path);
      }
      expect(authRedirect(signedOut, Uri.parse('/check-email')), '/welcome');
    });

    test('a failed restore counts as signed out', () {
      expect(
        authRedirect(AsyncValue.error(Exception(), StackTrace.empty), Uri.parse('/plans')),
        '/welcome?from=%2Fplans',
      );
    });

    test('keeps an unconfirmed traveller on Check your email', () {
      expect(authRedirect(unconfirmed, Uri.parse('/discover')), '/check-email');
      expect(authRedirect(unconfirmed, Uri.parse('/check-email')), isNull);
    });

    test('takes a confirmed traveller away from the sign-in screens, back where they were going', () {
      expect(authRedirect(confirmed, Uri.parse('/sign-in')), '/discover');
      expect(authRedirect(confirmed, Uri.parse('/welcome?from=%2Fplans')), '/plans');
      expect(authRedirect(confirmed, Uri.parse('/plans')), isNull);
    });

    test('never follows a from that leaves the app', () {
      for (final from in ['https://evil.test', '//evil.test/x', 'evil', '/sign-in']) {
        final uri = Uri(path: '/sign-in', queryParameters: {'from': from});
        expect(authRedirect(confirmed, uri), '/discover', reason: from);
        expect(authRedirect(signedOut, Uri(path: '/plans', queryParameters: {'from': from})), '/welcome');
      }
    });
  });

  group('AuthInterceptor', () {
    test('adds the ID token', () async {
      final (dio, adapter) = _dio(_Session(), [(200, <String, Object?>{})]);
      await dio.get<void>('/countries');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer t1');
    });

    test('sends no header without a token', () async {
      final (dio, adapter) = _dio(_Session(first: null), [(200, <String, Object?>{})]);
      await dio.get<void>('/countries');
      expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('on sign-in-required renews once and retries with the new token', () async {
      final session = _Session();
      final (dio, adapter) = _dio(session, [
        (401, {'code': 'sign-in-required'}),
        (200, {'ok': true}),
      ]);
      final response = await dio.get<Map<String, dynamic>>('/me');
      expect(response.data, {'ok': true});
      expect(adapter.requests.last.headers['Authorization'], 'Bearer t2');
      expect(session.calls, ['token', 'refresh']);
    });

    test('signs out when the renewed token is refused too', () async {
      final session = _Session();
      final (dio, _) = _dio(session, [
        (401, {'code': 'sign-in-required'}),
        (401, {'code': 'sign-in-required'}),
      ]);
      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
      expect(session.calls, contains('rejected'));
    });

    test('signs out when no token can be renewed', () async {
      final session = _Session(renewed: null);
      final (dio, _) = _dio(session, [
        (401, {'code': 'sign-in-required'}),
      ]);
      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
      expect(session.calls, ['token', 'refresh', 'rejected']);
    });

    test('reloads the traveller on email-not-confirmed and passes the error on', () async {
      final session = _Session();
      final (dio, _) = _dio(session, [
        (403, {'code': 'email-not-confirmed'}),
      ]);
      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
      expect(session.calls, ['token', 'reload']);
    });

    test('leaves other refusals alone', () async {
      final session = _Session();
      final (dio, _) = _dio(session, [
        (401, {'code': 'recent-sign-in-required'}),
      ]);
      await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
      expect(session.calls, ['token']);
    });

    test('describes the sign-in refusals', () {
      expect(describeApiError(apiRefusal(503, 'sign-in-not-configured')), "The server's sign-in isn't set up.");
      expect(describeApiError(apiRefusal(401, 'sign-in-required')), 'Sign in again to continue.');
      expect(describeApiError(apiRefusal(403, 'email-not-confirmed')), 'Confirm your email first.');
    });
  });

  group('profile data', () {
    test('reads weights as levels; an unknown weight reads as Medium', () {
      final profile = Profile.fromJson(
        _profileJson(
          weights: {'budget': 90, 'culture': 10, 'food': 33},
          city: {'id': 'c1', 'name': 'Beirut', 'countryCode': 'LB'},
        ),
      );
      expect(profile.preferences.of(Criterion.budget), Level.high);
      expect(profile.preferences.of(Criterion.culture), Level.low);
      expect(profile.preferences.of(Criterion.food), Level.medium);
      expect(profile.preferences.of(Criterion.comfort), Level.medium);
      expect(profile.homeCity?.name, 'Beirut');
      expect(profile.initial, 'S');
    });

    test('the form sends every weight and the city id', () {
      final form = ProfileForm.of(
        Profile.fromJson(_profileJson(city: {'id': 'c1', 'name': 'Beirut', 'countryCode': 'LB'})),
      );
      final json = form.toJson();
      expect(json['homeCityId'], 'c1');
      expect((json['preferences']! as Map).length, Criterion.values.length);
      expect((json['preferences']! as Map)['budget'], 90);
    });

    test('the repository gets, updates and deletes /me', () async {
      final (dio, adapter) = _dio(_Session(), [(200, _profileJson()), (200, _profileJson()), (204, null)]);
      final repository = ProfileRepository(dio);
      final profile = await repository.get();
      await repository.update(ProfileForm.of(profile));
      await repository.delete();
      expect(adapter.requests.map((r) => r.method), ['GET', 'PUT', 'DELETE']);
      expect(adapter.requests.map((r) => r.path), everyElement('/me'));
    });

    test('a 400 names the fields the API refused', () async {
      final (dio, _) = _dio(_Session(), [
        (
          400,
          {
            'errors': {
              'passport': ['Pick a country.'],
              'displayName': <String>[],
            },
          },
        ),
      ]);
      final error = await ProfileRepository(dio)
          .update(ProfileForm.of(defaultProfile()))
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<ProfileFieldErrors>());
      expect((error! as ProfileFieldErrors).errors, {
        'passport': 'Pick a country.',
        'displayName': 'Check this value.',
      });
    });
  });

  group('Firebase settings', () {
    tearDown(Env.reset);

    test('builds the options once every setting for the platform is set', () {
      Env.parse('''
FIREBASE_PROJECT_ID=demo
FIREBASE_MESSAGING_SENDER_ID=1
FIREBASE_WEB_APP_ID=web
FIREBASE_WEB_API_KEY=key
FIREBASE_AUTH_DOMAIN=demo.firebaseapp.com
''');
      final web = FirebaseSettings.fromEnv(isWeb: true);
      expect(web.missing, isNull);
      expect(web.options?.projectId, 'demo');
      expect(web.options?.authDomain, 'demo.firebaseapp.com');
      expect(FirebaseSettings.fromEnv(isWeb: false).missing, 'FIREBASE_ANDROID_APP_ID');
    });

    test('names the first missing setting when app.env has none', () {
      final settings = FirebaseSettings.fromEnv(isWeb: true);
      expect(settings.options, isNull);
      expect(settings.missing, 'FIREBASE_PROJECT_ID');
    });

    test('the not-configured sign-in refuses every step', () async {
      const auth = NotConfiguredAuthRepository('FIREBASE_PROJECT_ID');
      expect(await auth.changes().first, isNull);
      expect(await auth.idToken(), isNull);
      await expectLater(
        auth.signInWithGoogle(),
        throwsA(isA<AuthException>().having((e) => e.failure, 'failure', AuthFailure.notConfigured)),
      );
    });

    test("Firebase's codes read as the app's failures", () {
      expect(FirebaseAuthRepository.failureOf('invalid-credential'), AuthFailure.wrongCredentials);
      expect(FirebaseAuthRepository.failureOf('email-already-in-use'), AuthFailure.emailInUse);
      expect(FirebaseAuthRepository.failureOf('popup-closed-by-user'), AuthFailure.cancelled);
      expect(FirebaseAuthRepository.failureOf('requires-recent-login'), AuthFailure.recentSignInRequired);
      expect(FirebaseAuthRepository.failureOf('something-new'), AuthFailure.other);
    });

    test('a traveller in a log shows neither email nor name', () {
      expect(confirmedUser.toString(), isNot(contains('sam')));
      expect(confirmedUser.toString(), isNot(contains('Sam')));
    });
  });

  group('session', () {
    ProviderContainer container(FakeAuthRepository auth, FakeProfileRepository profiles) {
      final c = ProviderContainer(
        retry: noRetry,
        overrides: signedIn(auth: auth, profiles: profiles),
      );
      addTearDown(c.dispose);
      return c;
    }

    test('seeding sets passport, currency and levels, keeping the trip budget', () async {
      final profiles = FakeProfileRepository(
        defaultProfile(
          passport: 'FR',
          currency: 'EUR',
          preferences: const Preferences(levels: {Criterion.food: Level.high}),
        ),
      );
      final c = container(FakeAuthRepository(user: confirmedUser), profiles);
      c.read(tripSettingsProvider.notifier).setPreferences(const Preferences(tripBudget: 1500));

      await c.read(profileSeederProvider).seed();

      final trip = c.read(tripSettingsProvider);
      expect(trip.passport, 'FR');
      expect(trip.currency, 'EUR');
      expect(trip.preferences.of(Criterion.food), Level.high);
      expect(trip.preferences.tripBudget, 1500);
    });

    test('a profile that fails to load leaves the defaults', () async {
      final profiles = FakeProfileRepository()..getError = Exception('down');
      final c = container(FakeAuthRepository(user: confirmedUser), profiles);
      final before = c.read(tripSettingsProvider);
      await c.read(profileSeederProvider).seed();
      expect(c.read(tripSettingsProvider), before);
    });

    test('signing out forgets the trip settings', () async {
      final auth = FakeAuthRepository(user: confirmedUser);
      final c = container(auth, FakeProfileRepository());
      c.read(tripSettingsProvider.notifier).setPassport('FR');

      await c.read(sessionControllerProvider).signOut();

      expect(auth.calls, contains('signOut'));
      expect(c.read(tripSettingsProvider).passport, isNot('FR'));
    });

    test('the API session gives the token and signs out on rejection', () async {
      final auth = FakeAuthRepository(user: confirmedUser);
      final c = ProviderContainer(overrides: accountOverrides(auth));
      addTearDown(c.dispose);
      final session = c.read(apiSessionProvider);

      expect(await session.token(), 'token-1');
      expect(await session.token(refresh: true), 'token-2');
      await session.emailNotConfirmed();
      await session.signInRejected();
      expect(auth.calls, containsAllInOrder(['token', 'refresh', 'reload', 'signOut']));
    });
  });
}
