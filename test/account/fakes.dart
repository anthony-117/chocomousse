import 'dart:async';

import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:chocomousse/features/account/data/profile_models.dart';
import 'package:chocomousse/features/account/data/profile_repository.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart';

const confirmedUser = AuthUser(
  id: 'u1',
  email: 'sam@example.com',
  name: 'Sam Haddad',
  emailConfirmed: true,
  method: SignInMethod.password,
);

/// A profile matching the app's defaults, so seeding it changes nothing in tests about other features.
Profile defaultProfile({
  String? passport,
  String? currency,
  HomeCity? city,
  Preferences? preferences,
  Pace pace = Pace.balanced,
  String displayName = 'Sam Haddad',
}) => Profile(
  displayName: displayName,
  email: 'sam@example.com',
  passport: passport ?? Env.defaultPassport,
  homeCurrency: currency ?? Env.defaultCurrency,
  homeCity: city,
  preferences: preferences ?? const Preferences(),
  pace: pace,
);

/// Sign-in that answers from memory. [failWith] makes the next call fail.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? user, this.missingSetting}) {
    _user = user;
  }

  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  final String? missingSetting;

  AuthFailure? failWith;

  /// What [reloadUser] finds: set it to a confirmed user to act out "the link was opened".
  AuthUser? Function()? onReload;

  final calls = <String>[];
  String? token = 'token-1';
  String? refreshedToken = 'token-2';

  void setUser(AuthUser? user) {
    _user = user;
    _changes.add(user);
  }

  Future<void> _call(String name, [void Function()? then]) async {
    calls.add(name);
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw AuthException(failure);
    }
    then?.call();
  }

  @override
  Stream<AuthUser?> changes() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  AuthUser? get current => _user;

  @override
  Future<void> signInWithGoogle() => _call(
    'google',
    () => setUser(
      const AuthUser(id: 'g1', email: 'sam@gmail.com', name: 'Sam', emailConfirmed: true, method: SignInMethod.google),
    ),
  );

  @override
  Future<void> signInWithEmail(String email, String password) => _call(
    'email:$email',
    () => setUser(AuthUser(id: 'u1', email: email, name: 'Sam', emailConfirmed: true, method: SignInMethod.password)),
  );

  @override
  Future<void> signUp(String name, String email, String password) => _call(
    'signUp:$name:$email',
    () => setUser(AuthUser(id: 'u2', email: email, name: name, emailConfirmed: false, method: SignInMethod.password)),
  );

  @override
  Future<void> sendPasswordReset(String email) => _call('reset:$email');

  @override
  Future<void> resendConfirmation() => _call('resend');

  @override
  Future<AuthUser?> reloadUser() async {
    await _call('reload');
    final next = onReload?.call();
    if (next != null && next != _user) setUser(next);
    return _user;
  }

  @override
  Future<void> reauthenticate({String? password}) => _call('reauth:${password ?? 'google'}');

  @override
  Future<String?> idToken({bool refresh = false}) async {
    calls.add(refresh ? 'refresh' : 'token');
    return refresh ? refreshedToken : token;
  }

  @override
  Future<void> signOut() => _call('signOut', () => setUser(null));
}

/// The account API from memory.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([Profile? profile]) : profile = profile ?? defaultProfile();

  Profile profile;
  Exception? getError;
  Exception? updateError;

  /// Errors [delete] throws, one per call, before it succeeds.
  final deleteErrors = <Exception>[];
  int deletes = 0;
  ProfileForm? saved;

  @override
  Future<Profile> get() async {
    if (getError case final e?) throw e;
    return profile;
  }

  @override
  Future<Profile> update(ProfileForm form) async {
    if (updateError case final e?) throw e;
    saved = form;
    return profile = Profile(
      displayName: form.displayName.trim(),
      email: profile.email,
      passport: form.passport,
      homeCurrency: form.homeCurrency,
      homeCity: profile.homeCity?.id == form.homeCityId ? profile.homeCity : null,
      preferences: form.preferences,
    );
  }

  @override
  Future<void> delete() async {
    deletes++;
    if (deleteErrors.isNotEmpty) throw deleteErrors.removeAt(0);
  }
}

/// A refusal from the API, as dio reports it.
DioException apiRefusal(int status, String code, {String path = '/me'}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(requestOptions: options, statusCode: status, data: {'code': code}),
    type: DioExceptionType.badResponse,
  );
}

/// A confirmed traveller and their profile, for tests about the rest of the app.
List<Override> signedIn({FakeAuthRepository? auth, FakeProfileRepository? profiles}) => [
  authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository(user: confirmedUser)),
  profileRepositoryProvider.overrideWithValue(profiles ?? FakeProfileRepository()),
];
