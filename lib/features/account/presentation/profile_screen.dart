import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:chocomousse/features/account/data/profile_models.dart';
import 'package:chocomousse/features/account/presentation/delete_account_sheet.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/system/presentation/backend_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P1: Profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const editPath = '/profile/edit';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(authUserProvider).value;
    final profile = ref.watch(profileProvider);
    final name = profile.value?.displayName ?? user?.name ?? '';

    return PageFrame(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary,
              child: Text(
                name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                style: textTheme.headlineSmall?.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: textTheme.titleLarge),
                  Text(user?.email ?? '', style: textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                  Text(
                    user?.method == SignInMethod.google ? 'Signed in with Google' : 'Signed in with email',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        switch (profile) {
          AsyncValue(:final value?) => _ProfileCards(profile: value),
          AsyncValue(:final error?) => ErrorRetry(error: error, onRetry: () => ref.invalidate(profileProvider)),
          _ => const Column(
            children: [
              SkeletonBox(height: 160, radius: AppRadius.lg),
              SizedBox(height: AppSpacing.lg),
              SkeletonBox(height: 100, radius: AppRadius.lg),
            ],
          ),
        },
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => unawaited(ref.read(sessionControllerProvider).signOut()),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () => unawaited(showDeleteAccountSheet(context)),
          child: const Text('Delete my account'),
        ),
        const SizedBox(height: AppSpacing.xl),
        const BackendStatusCard(),
      ],
    );
  }
}

class _ProfileCards extends ConsumerWidget {
  const _ProfileCards({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final countries = ref.watch(countriesProvider).value ?? const [];
    final passport = countries.where((c) => c.code == profile.passport).firstOrNull;
    final city = profile.homeCity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          title: 'Travel profile',
          children: [
            _Row('Passport', passport == null ? profile.passport : '${passport.flag ?? ''} ${passport.name}'.trim()),
            _Row('Home currency', profile.homeCurrency),
            _Row('Home city', city == null ? 'Not set' : '${city.name}, ${city.countryCode}'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "New trips start with these. Changing a trip doesn't change them.",
              style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _Card(
          title: 'Default preferences',
          children: [Text('${profile.preferences.summary} · Pace ${profile.pace.label}', style: textTheme.bodyMedium)],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              TextButton(
                onPressed: () => context.go(ProfileScreen.editPath),
                child: Text('Edit', semanticsLabel: 'Edit ${title.toLowerCase()}'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
          ),
          Flexible(
            child: Text(value, style: textTheme.bodyLarge, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
