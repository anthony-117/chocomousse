import 'dart:async';

import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/itinerary/presentation/itinerary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _Action { rename, status, delete }

/// The plan actions (I6): Rename, Mark as planned (or as a draft), Delete plan, Cancel.
Future<void> showPlanActions(BuildContext context, PlanSummary plan) async {
  final action = await showModalBottomSheet<_Action>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) => _PlanActionsSheet(plan: plan),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _Action.rename:
      await showDialog<void>(
        context: context,
        builder: (_) => RenamePlanDialog(plan: plan),
      );
    case _Action.status:
      await _run(
        context,
        (actions) =>
            actions.setStatus(plan.id, plan.status == PlanStatus.planned ? PlanStatus.draft : PlanStatus.planned),
      );
    case _Action.delete:
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete ${plan.name}?'),
          content: const Text("The plan is deleted for good. This can't be undone."),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: context.palette.statusDanger),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if ((sure ?? false) && context.mounted) await _run(context, (actions) => actions.delete(plan.id));
  }
}

/// Runs a change, and says so when it fails.
Future<void> _run(BuildContext context, Future<Object?> Function(PlanActions actions) change) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await change(ProviderScope.containerOf(context).read(planActionsProvider));
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describePlanError(e))));
  }
}

class _PlanActionsSheet extends StatelessWidget {
  const _PlanActionsSheet({required this.plan});

  final PlanSummary plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    void pick(_Action action) => Navigator.of(context).pop(action);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('Rename'), onTap: () => pick(_Action.rename)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(plan.status == PlanStatus.planned ? 'Mark as draft' : 'Mark as planned'),
              onTap: () => pick(_Action.status),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Delete plan', style: TextStyle(color: context.palette.statusDanger)),
              onTap: () => pick(_Action.delete),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rename: 1 to 60 characters, with the API's reason when it refuses.
class RenamePlanDialog extends ConsumerStatefulWidget {
  const RenamePlanDialog({required this.plan, super.key});

  final PlanSummary plan;

  static const maxLength = 60;

  @override
  ConsumerState<RenamePlanDialog> createState() => _RenamePlanDialogState();
}

class _RenamePlanDialogState extends ConsumerState<RenamePlanDialog> {
  late final _name = TextEditingController(text: widget.plan.name);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(planActionsProvider).rename(widget.plan.id, _name.text.trim());
      if (mounted) Navigator.of(context).pop();
    } on PlanFieldError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describePlanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Rename plan'),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: RenamePlanDialog.maxLength,
        decoration: InputDecoration(labelText: 'Name', errorText: _error),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => valid && !_busy ? unawaited(_save()) : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: valid && !_busy ? () => unawaited(_save()) : null, child: const Text('Save')),
      ],
    );
  }
}
