import 'package:chocomousse/app/auth_guard.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/app_logo.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The three lines under the headline on Welcome (A1) and the web panel (W5).
const List<(IconData, String)> benefits = [
  (Icons.travel_explore_outlined, 'Every flight, stay and experience in one place'),
  (Icons.tune, 'Ranked by what matters to you'),
  (Icons.calendar_month_outlined, 'A day-by-day plan you can keep'),
];

const headline = 'Your whole trip, planned in minutes.';

/// Goes to another sign-in screen, keeping where the traveller was going.
void goAuth(BuildContext context, String path) {
  final from = GoRouterState.of(context).uri.queryParameters['from'];
  context.go(from == null ? path : Uri(path: path, queryParameters: {'from': from}).toString());
}

/// The frame of the sign-in screens: one column on phones; on wide screens (W5) the brand panel on the left and
/// the form on the right.
class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.children, this.title, this.subtitle, this.back, super.key});

  final String? title;
  final String? subtitle;

  /// Where the back arrow goes; no arrow when null.
  final String? back;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (back != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton.filledTonal(
                    tooltip: 'Back',
                    onPressed: () => goAuth(context, back!),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
              if (title != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(title!, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: textTheme.bodyMedium?.copyWith(color: context.palette.textSecondary)),
              ],
              const SizedBox(height: AppSpacing.xl),
              ...children,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: context.palette.bgSurface,
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  const Expanded(child: BrandPanel()),
                  Expanded(child: Center(child: form)),
                ],
              )
            : form,
      ),
    );
  }
}

/// The brand side of W5, also the top of Welcome on phones.
class BrandPanel extends StatelessWidget {
  const BrandPanel({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppWordmark(),
        SizedBox(height: compact ? AppSpacing.xl : 48),
        Text(
          headline,
          style: (compact ? textTheme.headlineMedium : textTheme.displaySmall)?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final (icon, text) in benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: context.palette.bgSurface,
                  child: Icon(icon, size: 18, color: context.palette.brandPrimary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(text, style: textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
    if (compact) return content;
    return Container(
      color: context.palette.brandPrimarySoft,
      padding: const EdgeInsets.all(64),
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: content),
    );
  }
}

/// "Continue with Google", as the GoogleButton component.
class GoogleButton extends StatelessWidget {
  const GoogleButton({required this.onPressed, this.busy = false, super.key});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        side: BorderSide(color: context.palette.borderDefault),
        foregroundColor: context.palette.textPrimary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            const Text(
              'G',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF4285F4)),
            ),
          const SizedBox(width: AppSpacing.md),
          const Flexible(child: Text('Continue with Google', overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// The main action, full width, with a spinner while it runs.
class PrimaryAction extends StatelessWidget {
  const PrimaryAction({required this.label, required this.onPressed, this.busy = false, super.key});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
      child: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.brandOnPrimary),
            )
          : Text(label),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('or', style: Theme.of(context).textTheme.bodySmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// A message in a soft box: red for an error, indigo for information.
class NoticeBox extends StatelessWidget {
  const NoticeBox(this.message, {this.error = true, this.action, super.key});

  final String message;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colour = error ? context.palette.statusDanger : context.palette.brandPrimary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.mark_email_read_outlined, color: colour, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.textPrimary),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Text with a link at the end: "New here? Create an account".
class LinkLine extends StatelessWidget {
  const LinkLine({required this.text, required this.link, required this.onTap, super.key});

  final String text;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
        TextButton(onPressed: onTap, child: Text(link)),
      ],
    );
  }
}

/// Busy and error state for a screen's sign-in actions. A closed Google window shows nothing (spec Story 1).
mixin AuthActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  String? error;
  AuthFailure? failure;

  AuthRepository get auth => ref.read(authRepositoryProvider);

  Future<bool> runAuth(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      failure = null;
    });
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      if (mounted && e.failure != AuthFailure.cancelled) {
        setState(() {
          failure = e.failure;
          error = e.failure.message;
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

/// A rough check before anything is sent (spec Story 2, scenario 6); Firebase has the last word.
String? checkEmail(String value) {
  final v = value.trim();
  final at = v.indexOf('@');
  return at > 0 && v.indexOf('.', at) > at + 1 && !v.endsWith('.') ? null : AuthFailure.invalidEmail.message;
}

/// The path the sign-in screens fall back to.
const String welcomePath = AuthPaths.welcome;
