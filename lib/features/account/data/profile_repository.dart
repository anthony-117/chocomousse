import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/account/data/profile_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in traveller's account on the API: `GET`, `PUT` and `DELETE /api/v1/me` (API contract, spec 009).
class ProfileRepository {
  const ProfileRepository(this._dio);

  final Dio _dio;

  Future<Profile> get() async {
    final response = await _dio.get<Map<String, dynamic>>('/me');
    return Profile.fromJson(response.data!);
  }

  /// Throws [ProfileFieldErrors] when the API names fields it refused.
  Future<Profile> update(ProfileForm form) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>('/me', data: form.toJson());
      return Profile.fromJson(response.data!);
    } on DioException catch (e) {
      final errors = fieldErrorsOf(e);
      if (errors != null) throw ProfileFieldErrors(errors);
      rethrow;
    }
  }

  /// Deletes the plans, the profile and the sign-in. A 401 `recent-sign-in-required` means "sign in again first".
  Future<void> delete() => _dio.delete<void>('/me');

  /// The `errors` of a 400 Problem Details, one message per field.
  static Map<String, String>? fieldErrorsOf(DioException e) {
    final data = e.response?.data;
    if (e.response?.statusCode != 400 || data is! Map || data['errors'] is! Map) return null;
    return {
      for (final entry in (data['errors'] as Map).entries)
        entry.key.toString(): entry.value is List && (entry.value as List).isNotEmpty
            ? (entry.value as List).first.toString()
            : 'Check this value.',
    };
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(dioProvider)));
