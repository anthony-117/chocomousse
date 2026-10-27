import 'dart:convert';
import 'dart:typed_data';

import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PingAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.toString());
    return ResponseBody.fromString(
      jsonEncode({
        'name': 'pamplemousse',
        'version': '1.0.0+abc',
        'environment': 'Test',
        'utcNow': '2026-10-27T10:00:00Z',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  tearDown(Env.reset);

  test('dio points at API_BASE_URL from env.dart', () {
    Env.parse('API_BASE_URL=https://api.example.com');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(dioProvider).options.baseUrl, 'https://api.example.com/api/v1');
  });

  test('ping calls /system/ping and parses the response', () async {
    final adapter = _PingAdapter();
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter),
      ],
    );
    addTearDown(container.dispose);

    final info = await container.read(pingProvider.future);

    expect(info.shortVersion, '1.0.0');
    expect(adapter.paths.single, 'http://api.test/api/v1/system/ping');
  });
}
