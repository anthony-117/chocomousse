import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/account/data/profile_models.dart';
import 'package:chocomousse/features/account/data/profile_repository.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/trip_chips.dart';
import 'package:chocomousse/features/flights/presentation/widgets/departure_city_field.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/pace_choice.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/preferences_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P2: Edit profile.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      body: switch (profile) {
        AsyncValue(:final value?) => _EditProfileForm(profile: value),
        AsyncValue(:final error?) => PageFrame(
          children: [ErrorRetry(error: error, onRetry: () => ref.invalidate(profileProvider))],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  late final _name = TextEditingController(text: widget.profile.displayName);
  late String _passport = widget.profile.passport;
  late String _currency = widget.profile.homeCurrency;
  late HomeCity? _city = widget.profile.homeCity;
  late Preferences _preferences = widget.profile.preferences;
  late Pace _pace = widget.profile.pace;
  Map<String, String> _fieldErrors = const {};
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _fieldErrors = {'displayName': 'Enter your name.'});
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      final saved = await ref
          .read(profileRepositoryProvider)
          .update(
            ProfileForm(
              displayName: _name.text,
              passport: _passport,
              homeCurrency: _currency,
              homeCityId: _city?.id,
              preferences: _preferences,
              pace: _pace,
            ),
          );
      ref.read(profileSeederProvider).apply(saved);
      if (mounted) context.go('/profile');
      ref.invalidate(profileProvider);
    } on ProfileFieldErrors catch (e) {
      if (mounted) setState(() => _fieldErrors = e.errors);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPassport() async {
    final code = await pickCountry(context, title: 'Passport', value: countryCode);
    if (code != null && mounted) setState(() => _passport = code);
  }

  Future<void> _pickCurrency() async {
    final currency = await pickCountry(context, title: 'Home currency', value: mainCurrency);
    if (currency != null && mounted) setState(() => _currency = currency);
  }

  Future<void> _pickCity() async {
    final city = await pickCity(context, title: 'Home city');
    if (city != null && mounted) {
      setState(() => _city = HomeCity(id: city.id, name: city.name, countryCode: city.countryCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PageFrame(
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Back',
              onPressed: () => context.go('/profile'),
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text('Edit profile', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: AppSpacing.lg),
        ],
        TextField(
          key: const Key('name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Name', errorText: _fieldErrors['displayName']),
        ),
        const SizedBox(height: AppSpacing.md),
        InputDecorator(
          decoration: const InputDecoration(
            enabled: false,
            labelText: 'Email',
            helperText: "Your email is how you sign in, so it can't be changed here.",
          ),
          child: Text(widget.profile.email),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Travel profile', style: textTheme.titleMedium),
        _PickTile(label: 'Passport', value: _passport, error: _fieldErrors['passport'], onTap: _pickPassport),
        _PickTile(label: 'Home currency', value: _currency, error: _fieldErrors['homeCurrency'], onTap: _pickCurrency),
        _PickTile(
          label: 'Home city',
          value: _city == null ? 'Not set' : '${_city!.name}, ${_city!.countryCode}',
          error: _fieldErrors['homeCityId'],
          onTap: _pickCity,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Default preferences', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        for (final criterion in Criterion.values)
          LevelSlider(
            criterion: criterion,
            level: _preferences.of(criterion),
            onChanged: (level) => setState(() => _preferences = _preferences.withLevel(criterion, level)),
          ),
        const SizedBox(height: AppSpacing.md),
        PaceChoice(value: _pace, onChanged: (pace) => setState(() => _pace = pace)),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          onPressed: _saving ? null : () => unawaited(_save()),
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.label, required this.value, required this.onTap, this.error});

  final String label;
  final String value;
  final String? error;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(value, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
          ),
        ],
      ),
      subtitle: error == null ? null : Text(error!, style: const TextStyle(color: AppColors.danger)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(onTap()),
    );
  }
}
