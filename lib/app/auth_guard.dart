import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Routes of the sign-in screens (A1–A5).
abstract final class AuthPaths {
  static const starting = '/starting';
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const checkEmail = '/check-email';

  /// Reachable while signed out (spec FR-003).
  static const Set<String> signedOut = {welcome, signIn, signUp, forgotPassword};

  static const Set<String> all = {starting, welcome, signIn, signUp, forgotPassword, checkEmail};
}

/// Where the router sends the traveller, or null to stay (spec FR-003, plan decision 4):
/// - while the saved sign-in is being restored, the splash;
/// - signed out, Welcome, remembering where they were going;
/// - signed in with an unconfirmed email, Check your email;
/// - signed in and confirmed, away from the sign-in screens, to where they were going or the home.
String? authRedirect(AsyncValue<AuthUser?> session, Uri uri) {
  final path = uri.path;
  final from = _from(uri);

  if (session.isLoading && !session.hasValue) {
    return path == AuthPaths.starting ? null : _with(AuthPaths.starting, from);
  }

  final user = session.hasError ? null : session.value;
  if (user == null) {
    if (AuthPaths.signedOut.contains(path)) return null;
    return _with(AuthPaths.welcome, from);
  }

  if (!user.emailConfirmed) return path == AuthPaths.checkEmail ? null : AuthPaths.checkEmail;

  if (AuthPaths.all.contains(path)) return _safe(uri.queryParameters['from'] ?? '') ?? '/';
  return null;
}

/// The in-app place the traveller was going: the `from` already carried, or this address when it isn't a sign-in
/// screen. Only paths inside the app are kept, never another site.
String? _from(Uri uri) {
  final carried = uri.queryParameters['from'];
  if (carried != null) return _safe(carried);
  if (AuthPaths.all.contains(uri.path) || uri.path == '/' || uri.path == '/discover') return null;
  return _safe(uri.toString());
}

String? _safe(String path) {
  final parsed = Uri.tryParse(path);
  if (parsed == null || parsed.hasScheme || parsed.hasAuthority || !path.startsWith('/') || path.startsWith('//')) {
    return null;
  }
  return AuthPaths.all.contains(parsed.path) ? null : path;
}

String _with(String path, String? from) =>
    from == null ? path : Uri(path: path, queryParameters: {'from': from}).toString();
