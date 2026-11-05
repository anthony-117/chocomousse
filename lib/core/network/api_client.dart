import 'package:chocomousse/env.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '${Env.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Turns off Riverpod's automatic retries, which keep a failed screen loading for about 38 seconds.
/// Screens show the error at once, with a Try again button.
Duration? noRetry(int retryCount, Object error) => null;

/// Short, user-facing explanation of a failed API call.
String describeApiError(Object error) {
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionError || DioExceptionType.connectionTimeout => 'Cannot reach the TravelGenie server.',
      DioExceptionType.receiveTimeout => 'The server took too long to answer.',
      DioExceptionType.badResponse when error.response?.statusCode == 404 => 'Not found.',
      DioExceptionType.badResponse when error.response?.statusCode == 429 =>
        'Too many messages. Wait a minute and try again.',
      DioExceptionType.badResponse => 'The server could not handle this request.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
