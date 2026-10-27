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

/// Short, user-facing explanation of a failed API call.
String describeApiError(Object error) {
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionError || DioExceptionType.connectionTimeout => 'Cannot reach the TravelGenie server.',
      DioExceptionType.receiveTimeout => 'The server took too long to answer.',
      DioExceptionType.badResponse when error.response?.statusCode == 404 => 'Not found.',
      DioExceptionType.badResponse => 'The server could not handle this request.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
