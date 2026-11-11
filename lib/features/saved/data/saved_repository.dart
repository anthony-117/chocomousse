import 'dart:convert';

import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/network/auth_interceptor.dart';
import 'package:chocomousse/features/account/data/profile_repository.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/saved/data/saved_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why saving or removing failed, in the words the snack bar shows.
sealed class SavedFailure implements Exception {
  const SavedFailure(this.message);

  final String message;
}

/// 409 `too-many-saved`: the account keeps [max] items at most.
class TooManySaved extends SavedFailure {
  TooManySaved(this.max)
    : super(
        max == null
            ? 'You have saved as many items as you can. Remove one to make room.'
            : 'You can keep up to $max saved items. Remove one to make room.',
      );

  final int? max;
}

/// 400: the API refused a value; [field] is the API's name for it.
class FieldError extends SavedFailure {
  const FieldError(this.field, super.message);

  final String field;
}

/// The trip's city isn't known, so the item can't be filed under one.
class NoCity extends SavedFailure {
  const NoCity() : super('Pick the trip city first, then save it.');
}

/// The saved-items routes of API spec 010 (FR-020). Tests replace it through [savedRepositoryProvider].
class SavedRepository {
  const SavedRepository(this._dio);

  final Dio _dio;

  /// The most a card's raw item may weigh, packed, to be kept with it.
  static const int maxItemBytes = 20 * 1024;

  /// The name the API accepts: 1–200 characters.
  static const maxNameLength = 200;

  static String _path(SavedKind kind, String id) => '/saved/${kind.name}/${Uri.encodeComponent(id)}';

  /// The body of `PUT /saved/{kind}/{id}` for [card]. Its raw `item` is left out when it weighs more than
  /// [maxItemBytes] packed.
  static Map<String, Object?> body(AssistantCard card, {required String destinationId}) {
    final name = card.title.trim();
    final item = card.raw['item'];
    final imageUrl = switch (card) {
      HotelCard(:final hotel) => hotel.photoUrl,
      PlaceCard(:final place) => place.imageUrl,
      _ => null,
    };
    return {
      'destinationId': destinationId,
      'name': name.length > maxNameLength ? name.substring(0, maxNameLength) : name,
      'imageUrl': imageUrl,
      'lat': card.lat,
      'lng': card.lng,
      if (item != null && utf8.encode(jsonEncode(item)).length <= maxItemBytes) 'item': item,
    };
  }

  /// Saves [card] (a hotel, place or event) under [destinationId]. Saving it again changes nothing.
  Future<void> save(AssistantCard card, {required String destinationId}) async {
    final kind = SavedKind.of(card) ?? (throw ArgumentError.value(card.kind, 'card', 'cannot be saved'));
    await _call(() => _dio.put<void>(_path(kind, card.id), data: body(card, destinationId: destinationId)));
  }

  Future<void> remove(SavedKind kind, String id) => _call(() => _dio.delete<void>(_path(kind, id)));

  /// Newest first, optionally of one kind or one city.
  Future<SavedList> list({SavedKind? kind, String? destinationId}) async {
    final response = await _call(
      () => _dio.get<Map<String, dynamic>>(
        '/saved',
        queryParameters: {'kind': ?kind?.name, 'destinationId': ?destinationId},
      ),
    );
    return SavedList.fromJson(response.data!);
  }

  Future<SavedIds> ids() async {
    final response = await _call(() => _dio.get<Map<String, dynamic>>('/saved/ids'));
    return SavedIds.fromJson(response.data!);
  }

  static Future<R> _call<R>(Future<R> Function() send) async {
    try {
      return await send();
    } on DioException catch (e) {
      throw failureOf(e) ?? e;
    }
  }

  static SavedFailure? failureOf(DioException e) {
    final response = e.response;
    if (response?.statusCode == 409 && problemCode(response) == 'too-many-saved') {
      final data = response?.data;
      return TooManySaved(data is Map && data['max'] is int ? data['max'] as int : null);
    }
    final fields = ProfileRepository.fieldErrorsOf(e);
    if (fields != null && fields.isNotEmpty) return FieldError(fields.keys.first, fields.values.first);
    return null;
  }
}

final savedRepositoryProvider = Provider<SavedRepository>((ref) => SavedRepository(ref.watch(dioProvider)));
