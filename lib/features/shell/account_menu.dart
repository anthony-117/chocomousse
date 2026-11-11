import 'dart:async';

import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/appearance.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The account menu: Preferences and account, Appearance and Sign out (spec 008 US4). A menu above the row on wide
/// screens, a bottom sheet on phones.
class AccountMenu extends StatefulWidget {
  const AccountMenu({required this.builder, super.key});

  /// Builds the row that opens the menu; `open` opens it.
  final Widget Function(BuildContext context, VoidCallback open) builder;

  @override
  State<AccountMenu> createState() => _AccountMenuState();
}

class _AccountMenuState extends State<AccountMenu> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    if (!wide) {
      return widget.builder(
        context,
        () => unawaited(
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                child: AccountMenuContent(onDone: () => Navigator.of(sheetContext).pop()),
              ),
            ),
          ),
        ),
      );
    }
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, -8),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.sm)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
      ),
      menuChildren: [SizedBox(width: 264, child: AccountMenuContent(onDone: _controller.close))],
      builder: (context, controller, _) =>
          widget.builder(context, () => controller.isOpen ? controller.close() : controller.open()),
    );
  }
}

/// The menu's entries, shared by the menu and the sheet.
class AccountMenuContent extends ConsumerWidget {
  const AccountMenuContent({required this.onDone, super.key});

  /// Closes the menu or the sheet.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final mode = ref.watch(appearanceProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Entry(
          icon: AppIcons.user,
          label: 'Preferences and account',
          onTap: () {
            onDone();
            GoRouter.of(context).go(AppPaths.profile);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, AppSpacing.md, 10, AppSpacing.sm),
          child: Text('Appearance', style: AppText.small.copyWith(color: palette.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {mode},
            onSelectionChanged: (choice) => unawaited(ref.read(appearanceProvider.notifier).set(choice.single)),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Divider(color: palette.borderDefault, height: AppSpacing.lg),
        _Entry(
          icon: AppIcons.arrowLeft,
          label: 'Sign out',
          onTap: () {
            onDone();
            unawaited(ref.read(sessionControllerProvider).signOut());
          },
        ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.icon, required this.label, required this.onTap});

  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            AppIcon(icon, size: 18, color: palette.textPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(color: palette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
