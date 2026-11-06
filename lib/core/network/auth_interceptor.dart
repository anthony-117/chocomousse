import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the API client needs from the sign-in. The account feature provides it; with none, requests go without a
/// token and the API refuses them.
abstract interface class ApiSession {
  Future<String?> token({bool refresh = false});

  /// The API still refuses the sign-in after a renewal: sign out.
  Future<void> signInRejected();

  /// The API says the email isn't confirmed: reload, so the app shows Check your email.
  Future<void> emailNotConfirmed();
}

class NoApiSession implements ApiSession {
  const NoApiSession();

  @override
  Future<String?> token({bool refresh = false}) async => null;

  @override
  Future<void> signInRejected() async {}

  @override
  Future<void> emailNotConfirmed() async {}
}

final apiSessionProvider = Provider<ApiSession>((ref) => const NoApiSession());

/// The `code` of an API refusal (API contract, spec 009): `sign-in-required`, `email-not-confirmed`, …
String? problemCode(Response<dynamic>? response) {
  final data = response?.data;
  return data is Map && data['code'] is String ? data['code'] as String : null;
}

/// Adds the traveller's ID token to every request (spec FR-002). A 401 `sign-in-required` renews the token once and
/// retries; a second one signs out. A 403 `email-not-confirmed` reloads the traveller.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._session, this._dio);

  static const _retried = 'authRetried';

  final ApiSession _session;
  final Dio _dio;

  /// One renewal at a time, shared by every request refused meanwhile.
  Future<String?>? _renewing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // A retry already carries the renewed token.
    if (options.extra[_retried] == true) return handler.next(options);
    String? token;
    try {
      token = await _session.token();
    } on Object {
      token = null;
    }
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final code = problemCode(err.response);

    if (status == 403 && code == 'email-not-confirmed') {
      await _quietly(_session.emailNotConfirmed);
      return handler.next(err);
    }
    if (status != 401 || code != 'sign-in-required') return handler.next(err);

    if (err.requestOptions.extra[_retried] == true) {
      await _quietly(_session.signInRejected);
      return handler.next(err);
    }

    final token = await (_renewing ??= _renew().whenComplete(() => _renewing = null));
    if (token == null) {
      await _quietly(_session.signInRejected);
      return handler.next(err);
    }

    final options = err.requestOptions
      ..extra[_retried] = true
      ..headers['Authorization'] = 'Bearer $token';
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (again) {
      handler.next(again);
    }
  }

  Future<String?> _renew() async {
    try {
      return await _session.token(refresh: true);
    } on Object {
      return null;
    }
  }

  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // The refusal still reaches the screen, which shows its own error.
    }
  }
}
