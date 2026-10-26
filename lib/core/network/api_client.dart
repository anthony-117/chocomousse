import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base URL of the pamplemousse API. Override at build time:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
/// (Android emulator: use http://10.0.2.2:5064).
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5064');

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '$apiBaseUrl/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
