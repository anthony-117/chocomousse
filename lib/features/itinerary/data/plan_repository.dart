import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/network/auth_interceptor.dart';
import 'package:chocomousse/features/account/data/profile_repository.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/ranking/data/ranking_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Why a plan request failed, in the words the screens show (spec Edge Cases).
sealed class PlanFailure implements Exception {
  const PlanFailure(this.message);

  final String message;
}

/// 409 `too-many-plans`.
class PlanLimitReached extends PlanFailure {
  const PlanLimitReached() : super('You can keep up to 50 plans. Delete one to make room.');
}

/// 422 `no-places`.
class NoPlaces extends PlanFailure {
  const NoPlaces(String city)
    : super('No places could be found for $city right now, so no plan can be made. Try again later.');
}

/// 404: the plan is gone, or isn't the traveller's.
class PlanNotFound extends PlanFailure {
  const PlanNotFound() : super("This plan doesn't exist or isn't yours.");
}

/// 422 `day-full`: the day has no free slot for its pace, in the API's words ("Day 2 is full for a balanced pace...").
class DayFull extends PlanFailure {
  const DayFull([super.message = 'This day is full. Replace a place instead.']);
}

/// 400: the API refused a value; [field] is the API's name for it.
class PlanFieldError extends PlanFailure {
  const PlanFieldError(this.field, super.message);

  final String field;
}

/// The plan routes of API spec 008. Tests replace it through [planRepositoryProvider].
class PlanRepository {
  const PlanRepository(this._dio);

  final Dio _dio;

  static final _day = DateFormat('yyyy-MM-dd');

  /// A build may run a hotel search the first time a city is asked, and the first car list runs a car search; both
  /// wait as long as Best for you does.
  static final _slow = Options(
    connectTimeout: RankingRepository.searchTimeout,
    receiveTimeout: RankingRepository.searchTimeout,
  );

  /// Builds and saves a plan from the trip settings (FR-001).
  Future<Plan> build({
    required String destinationId,
    required String destinationName,
    required TripSettings trip,
    String? originId,
  }) => _call(
    () => _dio.post<Map<String, dynamic>>(
      '/plans',
      data: {
        'destinationId': destinationId,
        'from': _day.format(trip.from),
        'to': _day.format(trip.to),
        'adults': trip.adults,
        'currency': trip.currency,
        'originId': originId,
        'preferences': {for (final c in Criterion.values) c.name: trip.preferences.of(c).weight},
        'pace': trip.pace.name,
        'tripBudget': trip.preferences.tripBudget,
      },
      options: _slow,
    ),
    Plan.fromJson,
    city: destinationName,
  );

  Future<Plan> plan(String id) => _call(() => _dio.get<Map<String, dynamic>>('/plans/$id'), Plan.fromJson);

  Future<PlanList> list() => _call(() => _dio.get<Map<String, dynamic>>('/plans'), PlanList.fromJson);

  Future<Plan> rename(String id, String name) =>
      _call(() => _dio.patch<Map<String, dynamic>>('/plans/$id', data: {'name': name}), Plan.fromJson);

  Future<Plan> setStatus(String id, PlanStatus status) =>
      _call(() => _dio.patch<Map<String, dynamic>>('/plans/$id', data: {'status': status.name}), Plan.fromJson);

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/plans/$id');
    } on DioException catch (e) {
      throw _failure(e, 'this city') ?? e;
    }
  }

  Future<Alternatives<HotelOffer>> hotels(String id) => _alternatives(id, OfferKind.hotel, HotelOffer.fromJson);

  Future<Alternatives<FlightFare>> flights(String id) => _alternatives(id, OfferKind.flight, FlightFare.fromJson);

  Future<Alternatives<CarOffer>> cars(String id) => _alternatives(id, OfferKind.car, CarOffer.fromJson);

  /// Swaps in an offer of the kept list and returns the rebuilt plan.
  Future<Plan> swap(String id, OfferKind kind, String offerId) =>
      _call(() => _dio.put<Map<String, dynamic>>('/plans/$id/${kind.name}', data: {'offerId': offerId}), Plan.fromJson);

  Future<Plan> removeCar(String id) => _call(() => _dio.delete<Map<String, dynamic>>('/plans/$id/car'), Plan.fromJson);

  /// Places or events that could take [itemId]'s place on [day], or fill a new slot without it.
  Future<DayAlternatives> dayAlternatives(String id, int day, {String? itemId, AlternativeKind? kind}) => _call(
    () => _dio.get<Map<String, dynamic>>(
      '/plans/$id/days/$day/alternatives',
      queryParameters: {'itemId': ?itemId, 'kind': ?kind?.name},
    ),
    DayAlternatives.fromJson,
  );

  /// Adds an alternative to [day], or puts it in place of [replaces]; returns the rebuilt plan.
  Future<Plan> addOrReplaceItem(
    String id,
    int day, {
    required RefKind kind,
    required String itemId,
    String? replaces,
  }) => _call(
    () => _dio.post<Map<String, dynamic>>(
      '/plans/$id/days/$day/items',
      data: {'kind': kind.name, 'id': itemId, 'replaces': ?replaces},
    ),
    Plan.fromJson,
  );

  /// Removes an item; its time becomes free time.
  Future<Plan> removeItem(String id, int day, String itemId) => _call(
    () => _dio.delete<Map<String, dynamic>>('/plans/$id/days/$day/items/${Uri.encodeComponent(itemId)}'),
    Plan.fromJson,
  );

  /// Rebuilds the plan in place with [values]; on any failure the saved plan is unchanged.
  Future<Plan> rebuild(String id, RebuildRequest values, {String city = 'this city'}) => _call(
    () => _dio.post<Map<String, dynamic>>('/plans/$id/rebuild', data: values.toJson(), options: _slow),
    Plan.fromJson,
    city: city,
  );

  Future<Alternatives<T>> _alternatives<T>(String id, OfferKind kind, T Function(Map<String, dynamic>) read) => _call(
    () => _dio.get<Map<String, dynamic>>('/plans/$id/alternatives/${kind.listName}', options: _slow),
    (json) => Alternatives.fromJson(json, read),
  );

  Future<R> _call<R>(
    Future<Response<Map<String, dynamic>>> Function() send,
    R Function(Map<String, dynamic>) read, {
    String city = 'this city',
  }) async {
    try {
      return read((await send()).data!);
    } on DioException catch (e) {
      throw _failure(e, city) ?? e;
    }
  }

  static PlanFailure? _failure(DioException e, String city) {
    final status = e.response?.statusCode;
    final code = problemCode(e.response);
    if (status == 409 && code == 'too-many-plans') return const PlanLimitReached();
    if (status == 422 && code == 'no-places') return NoPlaces(city);
    if (status == 422 && code == 'day-full') return DayFull(_detail(e.response) ?? const DayFull().message);
    if (status == 404) return const PlanNotFound();
    final fields = ProfileRepository.fieldErrorsOf(e);
    if (fields != null && fields.isNotEmpty) return PlanFieldError(fields.keys.first, fields.values.first);
    return null;
  }
}

/// The problem's own words, when it has them.
String? _detail(Response<dynamic>? response) {
  final data = response?.data;
  return data is Map && data['detail'] is String ? data['detail'] as String : null;
}

/// One alternative for a day: a place or event card and how far it is from the day's other items.
typedef DayAlternative = ({AssistantCard card, double walkKmFromDay});

/// The answer of the day alternatives route: at most 6, nearest first; [message] when there are none.
class DayAlternatives {
  const DayAlternatives({required this.day, required this.kind, required this.items, this.itemId, this.message});

  factory DayAlternatives.fromJson(Map<String, dynamic> json) => DayAlternatives(
    day: json['day']! as int,
    itemId: json['itemId'] as String?,
    kind: AlternativeKind.values.asNameMap()[json['kind']] ?? AlternativeKind.sight,
    items: [
      for (final raw in (json['items'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>())
        if (AssistantCard.fromJson(raw) case final card?)
          (card: card, walkKmFromDay: (raw['walkKmFromDay'] as num?)?.toDouble() ?? 0),
    ],
    message: json['message'] as String?,
  );

  final int day;
  final String? itemId;
  final AlternativeKind kind;
  final List<DayAlternative> items;
  final String? message;
}

final planRepositoryProvider = Provider<PlanRepository>((ref) => PlanRepository(ref.watch(dioProvider)));
