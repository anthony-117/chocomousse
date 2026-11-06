import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/network/auth_interceptor.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:chocomousse/features/account/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// P3: Delete your account?
Future<void> showDeleteAccountSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => const DeleteAccountSheet(),
);

class DeleteAccountSheet extends ConsumerStatefulWidget {
  const DeleteAccountSheet({super.key});

  @override
  ConsumerState<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<DeleteAccountSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _deleteOnce();
    } on _Stop {
      // Cancelled the sign-in again: nothing deleted, nothing to say.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.failure.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Deletes; when the API wants a recent sign-in, asks for it and tries once more (spec Story 5).
  Future<void> _deleteOnce() async {
    final repository = ref.read(profileRepositoryProvider);
    try {
      await repository.delete();
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || problemCode(e.response) != 'recent-sign-in-required') rethrow;
      await _signInAgain();
      await repository.delete();
    }
    if (!mounted) return;
    final session = ref.read(sessionControllerProvider);
    Navigator.of(context).pop();
    await session.signOut();
  }

  Future<void> _signInAgain() async {
    final auth = ref.read(authRepositoryProvider);
    if (auth.current?.method == SignInMethod.google) {
      try {
        await auth.reauthenticate();
      } on AuthException catch (e) {
        if (e.failure == AuthFailure.cancelled) throw const _Stop();
        rethrow;
      }
      return;
    }
    final password = await showDialog<String>(context: context, builder: (_) => const ReauthDialog());
    if (password == null) throw const _Stop();
    await auth.reauthenticate(password: password);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Delete your account?', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            Text(
              "This removes your sign-in, your travel profile and your saved plans. It can't be undone.",
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "If you signed in a while ago, you'll be asked to sign in again first.",
              style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(_error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              onPressed: _busy ? null : () => unawaited(_delete()),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : const Text('Delete my account'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}

class _Stop implements Exception {
  const _Stop();
}

/// Asks for the password before deleting an email account.
class ReauthDialog extends StatefulWidget {
  const ReauthDialog({super.key});

  @override
  State<ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<ReauthDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in again'),
      content: TextField(
        key: const Key('reauth-password'),
        controller: _password,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_password.text), child: const Text('Continue')),
      ],
    );
  }
}
