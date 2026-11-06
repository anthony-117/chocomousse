import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the traveller signs in.
enum SignInMethod { google, password }

/// The signed-in traveller, as Firebase knows them. Firebase's own types never leave this file.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.emailConfirmed,
    required this.method,
  });

  final String id;
  final String email;
  final String? name;
  final bool emailConfirmed;
  final SignInMethod method;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.name == name &&
      other.emailConfirmed == emailConfirmed &&
      other.method == method;

  @override
  int get hashCode => Object.hash(id, email, name, emailConfirmed, method);

  // Never the email or the name: this may end up in a log (spec FR-008).
  @override
  String toString() => 'AuthUser(confirmed: $emailConfirmed, ${method.name})';
}

/// Why a sign-in step failed, in the app's words (plan decision 2).
enum AuthFailure {
  wrongCredentials('Email or password is wrong.'),
  emailInUse('This email already has an account.'),
  weakPassword('Use at least 8 characters.'),
  invalidEmail('Enter a valid email address.'),
  tooManyRequests('Too many tries. Wait a few minutes, then try again.'),
  network("Sign-in isn't possible right now. Check your connection and try again."),
  popupBlocked('Allow pop-ups for this site, then try again.'),
  recentSignInRequired('Sign in again to continue.'),
  cancelled(''),
  notConfigured("Sign-in isn't set up in this version of the app."),
  other('Something went wrong. Please try again.');

  AuthFailure(this.message);

  final String message;
}

class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException(${failure.name})';
}

/// Signing in, out and the ID token (ADR 0020). The app talks to Firebase only through this.
abstract interface class AuthRepository {
  /// The traveller now and every time they sign in or out, or their email gets confirmed.
  Stream<AuthUser?> changes();

  AuthUser? get current;

  /// The first missing Firebase setting, when sign-in isn't set up; null otherwise.
  String? get missingSetting;

  Future<void> signInWithGoogle();

  Future<void> signInWithEmail(String email, String password);

  /// Makes the account, sets its name and sends the confirmation email.
  Future<void> signUp(String name, String email, String password);

  /// Sends a reset link. Says nothing about whether the email has an account (spec FR-009).
  Future<void> sendPasswordReset(String email);

  Future<void> resendConfirmation();

  /// Reloads the traveller and renews the token, so a confirmation done elsewhere counts.
  Future<AuthUser?> reloadUser();

  /// Signs in again before deleting: Google again, or the [password].
  Future<void> reauthenticate({String? password});

  Future<String?> idToken({bool refresh = false});

  Future<void> signOut();
}

/// Replaced in `main` once Firebase is set up; tests override it with a fake.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const NotConfiguredAuthRepository('FIREBASE_PROJECT_ID'),
);

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, {this.isWeb = kIsWeb});

  final FirebaseAuth _auth;
  final bool isWeb;

  @override
  String? get missingSetting => null;

  @override
  Stream<AuthUser?> changes() => _auth.userChanges().map(_toUser);

  @override
  AuthUser? get current => _toUser(_auth.currentUser);

  @override
  Future<void> signInWithGoogle() => _run(() async {
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    await (isWeb ? _auth.signInWithPopup(provider) : _auth.signInWithProvider(provider));
  });

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _run(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> signUp(String name, String email, String password) => _run(() async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = credential.user!;
    await user.updateDisplayName(name.trim());
    await user.sendEmailVerification();
    // The token carries the name the API makes the profile from.
    await user.getIdToken(true);
  });

  @override
  Future<void> sendPasswordReset(String email) => _run(() async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // The same answer whether or not the email has an account.
      if (e.code != 'user-not-found') rethrow;
    }
  });

  @override
  Future<void> resendConfirmation() => _run(() => _auth.currentUser!.sendEmailVerification());

  @override
  Future<AuthUser?> reloadUser() => _run(() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
    return _toUser(_auth.currentUser);
  });

  @override
  Future<void> reauthenticate({String? password}) => _run(() async {
    final user = _auth.currentUser!;
    if (password != null) {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
    } else {
      final provider = GoogleAuthProvider();
      await (isWeb ? user.reauthenticateWithPopup(provider) : user.reauthenticateWithProvider(provider));
    }
    await user.getIdToken(true);
  });

  @override
  Future<String?> idToken({bool refresh = false}) => _run(() async => await _auth.currentUser?.getIdToken(refresh));

  @override
  Future<void> signOut() => _run(_auth.signOut);

  static AuthUser? _toUser(User? user) {
    if (user == null) return null;
    final google = user.providerData.any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID);
    return AuthUser(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName,
      emailConfirmed: user.emailVerified,
      method: google ? SignInMethod.google : SignInMethod.password,
    );
  }

  static Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(failureOf(e.code));
    } on FirebaseException catch (e) {
      throw AuthException(failureOf(e.code));
    }
  }

  /// Firebase's error codes, in the app's words.
  @visibleForTesting
  static AuthFailure failureOf(String code) => switch (code) {
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' ||
    'user-disabled' => AuthFailure.wrongCredentials,
    'email-already-in-use' || 'account-exists-with-different-credential' => AuthFailure.emailInUse,
    'weak-password' => AuthFailure.weakPassword,
    'invalid-email' || 'missing-email' => AuthFailure.invalidEmail,
    'too-many-requests' => AuthFailure.tooManyRequests,
    'network-request-failed' || 'internal-error' => AuthFailure.network,
    'popup-blocked' => AuthFailure.popupBlocked,
    'requires-recent-login' || 'user-mismatch' => AuthFailure.recentSignInRequired,
    'popup-closed-by-user' ||
    'cancelled-popup-request' ||
    'web-context-canceled' ||
    'web-context-cancelled' ||
    'canceled' ||
    'cancelled' => AuthFailure.cancelled,
    _ => AuthFailure.other,
  };
}

/// Used when a Firebase setting is missing: nobody can sign in, and Welcome names [missingSetting].
class NotConfiguredAuthRepository implements AuthRepository {
  const NotConfiguredAuthRepository(this.missingSetting);

  @override
  final String missingSetting;

  @override
  Stream<AuthUser?> changes() => Stream.value(null);

  @override
  AuthUser? get current => null;

  @override
  Future<String?> idToken({bool refresh = false}) async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser?> reloadUser() async => null;

  Never _refuse() => throw const AuthException(AuthFailure.notConfigured);

  @override
  Future<void> signInWithGoogle() async => _refuse();

  @override
  Future<void> signInWithEmail(String email, String password) async => _refuse();

  @override
  Future<void> signUp(String name, String email, String password) async => _refuse();

  @override
  Future<void> sendPasswordReset(String email) async => _refuse();

  @override
  Future<void> resendConfirmation() async => _refuse();

  @override
  Future<void> reauthenticate({String? password}) async => _refuse();
}
