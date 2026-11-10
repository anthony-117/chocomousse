import 'dart:async';

import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/itinerary/presentation/itinerary_screen.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What `/plans/new` builds: the destination, and where Back returns to.
class BuildPlanRequest {
  const BuildPlanRequest({required this.destinationId, required this.destinationName, required this.returnTo});

  final String destinationId;
  final String destinationName;
  final String returnTo;
}

/// "Build my plan" (Best for you and the overview): opens `/plans/new`, which builds the plan from the trip settings.
class BuildPlanButton extends StatelessWidget {
  const BuildPlanButton({required this.destinationId, required this.destinationName, super.key});

  final String destinationId;
  final String destinationName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => context.go(
          '/plans/new',
          extra: BuildPlanRequest(
            destinationId: destinationId,
            destinationName: destinationName,
            returnTo: GoRouterState.of(context).uri.toString(),
          ),
        ),
        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
        label: const Text('Build my plan'),
      ),
    );
  }
}

/// The plan being built (FR-001): placeholder days until the API answers, then the saved plan at `/plans/{id}`.
class BuildPlanScreen extends ConsumerStatefulWidget {
  const BuildPlanScreen({required this.request, super.key});

  final BuildPlanRequest request;

  @override
  ConsumerState<BuildPlanScreen> createState() => _BuildPlanScreenState();
}

class _BuildPlanScreenState extends ConsumerState<BuildPlanScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_build());
  }

  Future<void> _build() async {
    setState(() => _error = null);
    final request = widget.request;
    try {
      final plan = await ref
          .read(planActionsProvider)
          .build(
            destinationId: request.destinationId,
            destinationName: request.destinationName,
            originId: ref.read(departureCityProvider)?.id,
          );
      if (mounted) context.go('/plans/${plan.id}');
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final title = 'Building your plan for ${request.destinationName}…';

    return switch (_error) {
      null => PlanLoading(title: title),
      final PlanLimitReached e => PlanProblem(message: e.message),
      final NoPlaces e => PlanProblem(message: e.message, action: 'Back', to: request.returnTo),
      final PlanFieldError e => PlanProblem(
        message: e.message,
        action: 'Plan your trip',
        to: '/discover/destination/${request.destinationId}/plan',
      ),
      final e => PlanLoading(
        title: title,
        banner: ErrorRetryBanner(message: describePlanError(e), onRetry: () => unawaited(_build())),
      ),
    };
  }
}
