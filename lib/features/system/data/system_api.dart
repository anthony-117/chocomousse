import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Response of `GET /api/v1/system/ping` (PingResponse in pamplemousse).
class PingInfo {
  const PingInfo({required this.name, required this.version, required this.environment, required this.utcNow});

  factory PingInfo.fromJson(Map<String, dynamic> json) => PingInfo(
    name: json['name'] as String,
    version: json['version'] as String,
    environment: json['environment'] as String,
    utcNow: DateTime.parse(json['utcNow'] as String),
  );

  final String name;
  final String version;
  final String environment;
  final DateTime utcNow;

  /// Version without the build metadata .NET appends (e.g. "1.0.0+44c9450…" → "1.0.0").
  String get shortVersion => version.split('+').first;
}

class SystemApi {
  const SystemApi(this._dio);

  final Dio _dio;

  Future<PingInfo> ping() async {
    final response = await _dio.get<Map<String, dynamic>>('/system/ping');
    return PingInfo.fromJson(response.data!);
  }
}

final systemApiProvider = Provider<SystemApi>((ref) => SystemApi(ref.watch(dioProvider)));

final pingProvider = FutureProvider.autoDispose<PingInfo>((ref) => ref.watch(systemApiProvider).ping());
