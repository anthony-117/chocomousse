import 'dart:convert';

import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/network/auth_interceptor.dart';
import 'package:chocomousse/features/chat/data/chat_transport.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

ChatTransport createChatTransport(Ref ref) => DioChatTransport(ref.watch(dioProvider), ref.watch(apiSessionProvider));

/// Streams the answer with dio, which reads it as it comes on Android, iOS and desktop.
class DioChatTransport implements ChatTransport {
  DioChatTransport(this._dio, this._session);

  final Dio _dio;
  final ApiSession _session;

  @override
  Future<Stream<List<int>>> post(String path, Map<String, Object?> body) => openChatStream(_session, () async {
    final response = await _dio.post<ResponseBody>(
      path,
      data: jsonEncode(body),
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
        contentType: Headers.jsonContentType,
        headers: {'Accept': 'text/event-stream'},
        // Refusals come back as answers, so their JSON body can be read from the stream.
        validateStatus: (_) => true,
      ),
    );
    return RawAnswer(
      status: response.statusCode ?? 0,
      header: response.headers.value,
      body: response.data?.stream ?? const Stream.empty(),
    );
  });
}
