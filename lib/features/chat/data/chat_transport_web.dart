import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:chocomousse/core/network/auth_interceptor.dart';
import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/chat/data/chat_transport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

ChatTransport createChatTransport(Ref ref) => FetchChatTransport(ref.watch(apiSessionProvider));

@JS('fetch')
external JSPromise<_Response> _fetch(String url, JSAny init);

extension type _Response._(JSObject _) implements JSObject {
  external int get status;
  external _Headers get headers;
  external _ReadableStream? get body;
}

extension type _Headers._(JSObject _) implements JSObject {
  external String? get(String name);
}

extension type _ReadableStream._(JSObject _) implements JSObject {
  external _Reader getReader();
}

extension type _Reader._(JSObject _) implements JSObject {
  external JSPromise<_ReadResult> read();
  external JSPromise<JSAny?> cancel();
}

extension type _ReadResult._(JSObject _) implements JSObject {
  external bool get done;
  external JSUint8Array? get value;
}

/// Streams the answer with the browser's `fetch`, reading the body chunk by chunk (dio's web adapter waits for the
/// whole answer). It sends the same sign-in token as the API client.
class FetchChatTransport implements ChatTransport {
  FetchChatTransport(this._session);

  final ApiSession _session;

  @override
  Future<Stream<List<int>>> post(String path, Map<String, Object?> body) => openChatStream(_session, () async {
    final token = await _session.token();
    final init = <String, Object?>{
      'method': 'POST',
      'headers': <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Authorization': ?(token == null ? null : 'Bearer $token'),
      },
      'body': jsonEncode(body),
    }.jsify()!;
    final response = await _fetch('${Env.apiBaseUrl}/api/v1$path', init).toDart;
    final reader = response.body?.getReader();
    return RawAnswer(
      status: response.status,
      header: response.headers.get,
      body: reader == null ? const Stream.empty() : _chunks(reader),
    );
  });

  /// The body's chunks; cancelling the Dart stream cancels the browser's reader.
  static Stream<List<int>> _chunks(_Reader reader) {
    late final StreamController<List<int>> controller;
    var cancelled = false;

    Future<void> pump() async {
      try {
        while (!cancelled) {
          final result = await reader.read().toDart;
          if (result.done) break;
          final value = result.value;
          if (value != null) controller.add(value.toDart);
        }
      } on Object catch (error, stack) {
        if (!cancelled) controller.addError(error, stack);
      }
      if (!cancelled) await controller.close();
    }

    controller = StreamController<List<int>>(
      onListen: pump,
      onCancel: () async {
        cancelled = true;
        await reader.cancel().toDart;
      },
    );
    return controller.stream;
  }
}
