import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_error.dart';
import '../application/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { entry, signIn, signUp, reset }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthMode mode = _AuthMode.entry;
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();
  bool obscure = true;

  @override void dispose() { email.dispose(); password.dispose(); confirm.dispose(); emailFocus.dispose(); passwordFocus.dispose(); super.dispose(); }

  String? validateEmail() { final value = email.text.trim(); if (value.isEmpty) return 'enter your email address.'; if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'enter a valid email address.'; return null; }
  String? validatePassword() { if (password.text.isEmpty) return 'enter your password.'; if (mode == _AuthMode.signUp && password.text.length < 8) return 'use at least 8 characters for your password.'; return null; }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    final emailError = validateEmail(); final passwordError = mode == _AuthMode.reset ? null : validatePassword();
    if (emailError != null || passwordError != null || (mode == _AuthMode.signUp && password.text != confirm.text)) { setState(() {}); return; }
    final controller = ref.read(authControllerProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);
    if (mode == _AuthMode.reset) { final error = await controller.resetPassword(email.text); if (!mounted) return; if (error == null) { _show('if an account can receive a reset email, you’ll get one shortly.'); setState(() => mode = _AuthMode.signIn); } return; }
    final signUp = mode == _AuthMode.signUp; if (signUp) await analytics.logSignUpStarted(); else await analytics.logSignInStarted();
    final result = signUp ? await controller.signUp(email.text, password.text) : await controller.signIn(email.text, password.text);
    if (!mounted || result == null) return;
    if (result.status == AuthStatus.authenticatedUnverified) { await ref.read(authServiceProvider).sendEmailVerification(); await analytics.logEmailVerificationSent(); if (mounted) context.go('/verify-email'); return; }
    if (result.status == AuthStatus.authenticated) { if (signUp) await analytics.logSignUp(); else await analytics.logLogin(); if (mounted) context.go('/profile-setup'); }
  }

  void _show(String message) => ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(message)));

  @override Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen<AuthControllerState>(authControllerProvider, (_, next) { final message = next.error?.message; if (message != null && message.isNotEmpty && mounted) _show(message); });
    if (mode == _AuthMode.entry) return _entry(context);
    final title = mode == _AuthMode.signUp ? 'create your account' : mode == _AuthMode.reset ? 'reset your password' : 'welcome back';
    return Scaffold(body: SafeArea(child: Form(child: ListView(padding: const EdgeInsets.all(PulseSpace.xl), children: [
      IconButton(alignment: Alignment.centerLeft, onPressed: () => setState(() => mode = _AuthMode.entry), icon: const Icon(Icons.arrow_back), tooltip: 'back'),
      const SizedBox(height: PulseSpace.xl), Text(title, style: AppTypography.display), const SizedBox(height: PulseSpace.sm), Text(mode == _AuthMode.reset ? 'we’ll send a reset link to your email.' : 'your progress starts here.', style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: PulseSpace.xxl),
      TextField(controller: email, focusNode: emailFocus, keyboardType: TextInputType.emailAddress, textInputAction: mode == _AuthMode.reset ? TextInputAction.done : TextInputAction.next, autofillHints: const [AutofillHints.email], decoration: InputDecoration(labelText: 'email', errorText: validateEmail()), onChanged: (_) => setState(() {}), onSubmitted: (_) => passwordFocus.requestFocus()),
      if (mode != _AuthMode.reset) ...[
        const SizedBox(height: PulseSpace.md), TextField(controller: password, focusNode: passwordFocus, obscureText: obscure, textInputAction: mode == _AuthMode.signUp ? TextInputAction.next : TextInputAction.done, autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText: 'password', errorText: validatePassword(), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off), tooltip: obscure ? 'show password' : 'hide password')), onChanged: (_) => setState(() {}), onSubmitted: (_) => mode == _AuthMode.signIn ? submit() : FocusScope.of(context).nextFocus()),
        if (mode == _AuthMode.signUp) ...[const SizedBox(height: PulseSpace.md), TextField(controller: confirm, obscureText: obscure, textInputAction: TextInputAction.done, decoration: InputDecoration(labelText: 'confirm password', errorText: confirm.text.isNotEmpty && confirm.text != password.text ? 'passwords don’t match.' : null), onChanged: (_) => setState(() {}), onSubmitted: (_) => submit())],
      ],
      const SizedBox(height: PulseSpace.lg), SizedBox(height: 52, child: FilledButton(onPressed: auth.loading ? null : submit, child: auth.loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(mode == _AuthMode.signUp ? 'create account' : mode == _AuthMode.reset ? 'send reset link' : 'sign in'))),
      if (mode == _AuthMode.signIn) TextButton(onPressed: auth.loading ? null : () => setState(() => mode = _AuthMode.reset), child: const Text('forgot password?')),
      const SizedBox(height: PulseSpace.md), TextButton(onPressed: auth.loading ? null : () => setState(() => mode = mode == _AuthMode.signUp ? _AuthMode.signIn : _AuthMode.signUp), child: Text(mode == _AuthMode.signUp ? 'already have an account? sign in' : 'new to Pulse? create an account')),
      const SizedBox(height: PulseSpace.xl), const Text('google, apple and phone sign-in are not available in this Firebase configuration yet.', textAlign: TextAlign.center),
    ])));
  }

  Widget _entry(BuildContext context) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(PulseSpace.xl), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Spacer(), Text('welcome to Pulse', style: AppTypography.display), const SizedBox(height: PulseSpace.md), Text('make today count. one small action at a time.', style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: PulseSpace.xxl), SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: () => setState(() => mode = _AuthMode.signUp), child: const Text('create account'))), const SizedBox(height: PulseSpace.sm), SizedBox(width: double.infinity, height: 52, child: OutlinedButton(onPressed: () => setState(() => mode = _AuthMode.signIn), child: const Text('sign in'))), const SizedBox(height: PulseSpace.md), const Text('email authentication is currently available. other providers appear when their Firebase configuration is ready.', textAlign: TextAlign.center), const Spacer()])));
}
