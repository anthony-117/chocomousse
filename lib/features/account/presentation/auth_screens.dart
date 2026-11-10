import 'dart:async';

import 'package:chocomousse/app/auth_guard.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/app_logo.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:chocomousse/features/account/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown while Firebase restores a saved sign-in.
class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bgSurface,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(),
            SizedBox(height: AppSpacing.xl),
            SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}

/// A1: Welcome.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with AuthActions {
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final missing = auth.missingSetting;
    return AuthFrame(
      title: wide ? 'Welcome' : null,
      subtitle: wide ? 'Sign in to plan, save and find your trips.' : null,
      children: [
        if (!wide) ...[const BrandPanel(compact: true), const SizedBox(height: AppSpacing.xl)],
        if (missing != null) NoticeBox('${AuthFailure.notConfigured.message} Missing setting: $missing.'),
        if (error != null) NoticeBox(error!),
        GoogleButton(busy: busy, onPressed: () => unawaited(runAuth(auth.signInWithGoogle))),
        const SizedBox(height: AppSpacing.md),
        PrimaryAction(label: 'Continue with email', onPressed: () => goAuth(context, AuthPaths.signUp)),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: () => goAuth(context, AuthPaths.signIn), child: const Text('I already have an account')),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'By continuing you agree to the Terms and the Privacy Policy.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
        ),
      ],
    );
  }
}

/// A2: Sign in (W5 on wide screens).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> with AuthActions {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await runAuth(() => auth.signInWithEmail(_email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Sign in',
      subtitle: 'Welcome back. Your plans are waiting.',
      back: AuthPaths.welcome,
      children: [
        GoogleButton(onPressed: busy ? null : () => unawaited(runAuth(auth.signInWithGoogle))),
        const OrDivider(),
        if (error != null) NoticeBox(error!),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => checkEmail(v ?? ''),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('password'),
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v ?? '').isEmpty ? 'Enter your password.' : null,
                onFieldSubmitted: (_) => unawaited(_submit()),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => goAuth(context, AuthPaths.forgotPassword),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryAction(label: 'Sign in', busy: busy, onPressed: () => unawaited(_submit())),
        const SizedBox(height: AppSpacing.lg),
        LinkLine(text: 'New here?', link: 'Create an account', onTap: () => goAuth(context, AuthPaths.signUp)),
      ],
    );
  }
}

/// A3: Create your account.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> with AuthActions {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await runAuth(() => auth.signUp(_name.text, _email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Create your account',
      subtitle: 'Plan, save and find your trips on any device.',
      back: AuthPaths.welcome,
      children: [
        GoogleButton(onPressed: busy ? null : () => unawaited(runAuth(auth.signInWithGoogle))),
        const OrDivider(),
        if (error != null)
          NoticeBox(
            error!,
            action: failure == AuthFailure.emailInUse
                ? TextButton(onPressed: () => goAuth(context, AuthPaths.signIn), child: const Text('Sign in'))
                : null,
          ),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => checkEmail(v ?? ''),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('password'),
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters.'),
                validator: (v) => (v ?? '').length < 8 ? AuthFailure.weakPassword.message : null,
                onFieldSubmitted: (_) => unawaited(_submit()),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          "We'll email you a link to confirm your address.",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryAction(label: 'Create account', busy: busy, onPressed: () => unawaited(_submit())),
        const SizedBox(height: AppSpacing.lg),
        LinkLine(text: 'Already have an account?', link: 'Sign in', onTap: () => goAuth(context, AuthPaths.signIn)),
      ],
    );
  }
}

/// A4: Check your email.
class CheckEmailScreen extends ConsumerStatefulWidget {
  const CheckEmailScreen({super.key});

  /// How long "Resend email" waits between sends.
  static const resendWait = 60;

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> with AuthActions {
  Timer? _timer;
  int _wait = 0;
  bool _notYet = false;

  @override
  void initState() {
    super.initState();
    // A link opened in another tab or on another device counts as soon as the app opens.
    unawaited(_reload(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool quiet = false}) async {
    AuthUser? user;
    final ok = await runAuth(() async => user = await auth.reloadUser());
    if (!mounted || quiet || !ok) return;
    setState(() => _notYet = user?.emailConfirmed != true);
  }

  Future<void> _resend() async {
    if (!await runAuth(auth.resendConfirmation) || !mounted) return;
    setState(() => _wait = CheckEmailScreen.resendWait);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authUserProvider).value?.email ?? auth.current?.email ?? 'your email';
    return AuthFrame(
      title: 'Check your email',
      subtitle: 'We sent a link to $email. Open it to confirm your address, then come back here.',
      children: [
        if (_notYet) const NoticeBox('Not confirmed yet. Open the link in the email first.'),
        if (error != null) NoticeBox(error!),
        PrimaryAction(label: "I've confirmed", busy: busy, onPressed: () => unawaited(_reload())),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: busy || _wait > 0 ? null : () => unawaited(_resend()),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          child: Text(_wait > 0 ? 'Resend email in ${_wait}s' : 'Resend email'),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => unawaited(ref.read(sessionControllerProvider).signOut()),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// A5: Reset your password.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> with AuthActions {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    if (await runAuth(() => auth.sendPasswordReset(email)) && mounted) setState(() => _sentTo = email);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Reset your password',
      subtitle: 'Enter the email you sign in with.',
      back: AuthPaths.signIn,
      children: [
        if (_sentTo != null)
          NoticeBox("If an account exists for $_sentTo, we've sent a link to reset its password.", error: false),
        if (error != null) NoticeBox(error!),
        Form(
          key: _form,
          child: TextFormField(
            key: const Key('email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => checkEmail(v ?? ''),
            onFieldSubmitted: (_) => unawaited(_submit()),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryAction(label: 'Send link', busy: busy, onPressed: () => unawaited(_submit())),
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: () => goAuth(context, AuthPaths.signIn), child: const Text('Back to sign in')),
      ],
    );
  }
}
