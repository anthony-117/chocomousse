import 'dart:async';
import 'dart:convert';

import 'package:chocomousse/core/network/auth_interceptor.dart';
import 'package:chocomousse/features/chat/data/chat_transport_io.dart'
    if (dart.library.js_interop) 'package:chocomousse/features/chat/data/chat_transport_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Posts a message and gives the raw bytes of the `text/event-stream` answer (research R-1). Dio buffers answers on
/// the web, so the web uses `fetch` instead; both send the sign-in token and renew it once on a 401.
abstract interface class ChatTransport {
  /// [path] is relative to `/api/v1`, e.g. `/assistant/chats`. Throws [ChatRefused] when the answer isn't a
  /// `200 text/event-stream`.
  Future<Stream<List<int>>> post(String path, Map<String, Object?> body);
}

/// The API answered with a normal JSON refusal instead of a stream.
class ChatRefused implements Exception {
  const ChatRefused(this.statusCode, {this.problem, this.retryAfter});

  final int statusCode;

  /// The Problem Details body, when it was JSON.
  final Map<String, Object?>? problem;

  /// From `Retry-After` (seconds), on a 429.
  final Duration? retryAfter;

  String? get code => problem?['code'] as String?;

  @override
  String toString() => 'ChatRefused($statusCode, $code)';
}

final chatTransportProvider = Provider<ChatTransport>(createChatTransport);

/// One try at the request, as the platform made it.
class RawAnswer {
  RawAnswer({required this.status, required this.header, required this.body});

  final int status;
  final String? Function(String name) header;
  final Stream<List<int>> body;

  Map<String, Object?>? _problem;
  bool _read = false;

  bool get isStream => status == 200 && (header('content-type') ?? '').contains('text/event-stream');

  /// The JSON body of a refusal, read once.
  Future<Map<String, Object?>?> problem() async {
    if (_read) return _problem;
    _read = true;
    try {
      final json = jsonDecode(await utf8.decodeStream(body));
      _problem = json is Map<String, Object?> ? json : null;
    } on Object {
      _problem = null;
    }
    return _problem;
  }

  Duration? get retryAfter {
    final seconds = int.tryParse(header('retry-after') ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

/// Runs [attempt], renews the sign-in once on a 401 `sign-in-required` as `AuthInterceptor` does, and returns the
/// stream or throws [ChatRefused].
Future<Stream<List<int>>> openChatStream(ApiSession session, Future<RawAnswer> Function() attempt) async {
  var answer = await attempt();
  if (answer.status == 401 && (await answer.problem())?['code'] == 'sign-in-required') {
    String? token;
    try {
      token = await session.token(refresh: true);
    } on Object {
      token = null;
    }
    if (token != null) answer = await attempt();
    if (answer.status == 401) await _quietly(session.signInRejected);
  }
  if (answer.isStream) return answer.body;
  final problem = await answer.problem();
  if (answer.status == 403 && problem?['code'] == 'email-not-confirmed') await _quietly(session.emailNotConfirmed);
  throw ChatRefused(answer.status, problem: problem, retryAfter: answer.retryAfter);
}

Future<void> _quietly(Future<void> Function() action) async {
  try {
    await action();
  } on Object {
    // The refusal still reaches the screen.
  }
}
