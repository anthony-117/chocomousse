import 'dart:async';

import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;

/// Plans the API just returned, waiting for their screen to open, so opening them doesn't ask the API again.
final _freshPlansProvider = Provider<Map<String, Plan>>((ref) => {});

/// One saved plan, kept while its screens are open (plan decision 3).
class PlanNotifier extends AsyncNotifier<Plan> {
  PlanNotifier(this.id);

  final String id;

  @override
  FutureOr<Plan> build() => ref.read(_freshPlansProvider).remove(id) ?? ref.watch(planRepositoryProvider).plan(id);

  /// Shows a plan the API returned after a change.
  void show(Plan plan) => state = AsyncData(plan);
}

final AsyncNotifierProviderFamily<PlanNotifier, Plan, String> planProvider = AsyncNotifierProvider.autoDispose
    .family<PlanNotifier, Plan, String>(PlanNotifier.new);

/// My plans, newest change first.
final FutureProvider<PlanList> plansProvider = FutureProvider.autoDispose<PlanList>(
  (ref) => ref.watch(planRepositoryProvider).list(),
);

/// Every change to a plan. Each one shows the plan the API returns and refreshes My plans, so the itinerary and the
/// list never disagree (plan decision 3).
class PlanActions {
  const PlanActions(this._ref);

  final Ref _ref;

  PlanRepository get _repository => _ref.read(planRepositoryProvider);

  /// Builds a plan from the trip settings. The plan waits for its screen, which opens it without another request.
  Future<Plan> build({required String destinationId, required String destinationName, String? originId}) async {
    final plan = await _repository.build(
      destinationId: destinationId,
      destinationName: destinationName,
      trip: _ref.read(tripSettingsProvider),
      originId: originId,
    );
    _ref.read(_freshPlansProvider)[plan.id] = plan;
    _ref.invalidate(plansProvider);
    return plan;
  }

  Future<Plan> swap(String id, OfferKind kind, String offerId) => _store(_repository.swap(id, kind, offerId));

  Future<Plan> removeCar(String id) => _store(_repository.removeCar(id));

  Future<Plan> addOrReplaceItem(
    String id,
    int day, {
    required RefKind kind,
    required String itemId,
    String? replaces,
  }) => _store(_repository.addOrReplaceItem(id, day, kind: kind, itemId: itemId, replaces: replaces));

  Future<Plan> removeItem(String id, int day, String itemId) => _store(_repository.removeItem(id, day, itemId));

  Future<Plan> rebuild(String id, RebuildRequest values, {String city = 'this city'}) =>
      _store(_repository.rebuild(id, values, city: city));

  Future<Plan> rename(String id, String name) => _store(_repository.rename(id, name));

  Future<Plan> setStatus(String id, PlanStatus status) => _store(_repository.setStatus(id, status));

  Future<void> delete(String id) async {
    await _repository.delete(id);
    _ref
      ..invalidate(planProvider(id))
      ..invalidate(plansProvider);
  }

  Future<Plan> _store(Future<Plan> change) async {
    final plan = await change;
    if (_ref.exists(planProvider(plan.id))) {
      _ref.read(planProvider(plan.id).notifier).show(plan);
    } else {
      _ref.read(_freshPlansProvider)[plan.id] = plan;
    }
    _ref.invalidate(plansProvider);
    return plan;
  }
}

final planActionsProvider = Provider<PlanActions>(PlanActions.new);
