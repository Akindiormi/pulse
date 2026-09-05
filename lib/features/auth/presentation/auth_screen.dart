import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/motion/pulse_motion_attachment.dart';
import '../../../core/motion/pulse_motion_policy.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../core/motion/pulse_rive.dart';
import '../../../core/motion/pulse_rive_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pulse_button.dart';
import '../application/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
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
  bool emailTouched = false;
  bool passwordTouched = false;
  bool submittedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(analyticsServiceProvider).logAuthScreenViewed());
    emailFocus.addListener(_onFocusChange);
    passwordFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!emailFocus.hasFocus && email.text.isNotEmpty) emailTouched = true;
    if (!passwordFocus.hasFocus && password.text.isNotEmpty) passwordTouched = true;
    if (mounted) setState(() {});
  }

  /// Drives the optional Pulse auth avatar (see assets/rive/auth/README.md).
  /// Falls back to nothing if no .riv asset is present yet.
  PulseAuthAvatarState get avatarState {
    if (submittedSuccessfully) return PulseAuthAvatarState.success;
    final emailError = emailTouched && validateEmail() != null;
    final passwordError = passwordTouched && mode != _AuthMode.reset && validatePassword() != null;
    if (emailError || passwordError) return PulseAuthAvatarState.error;
    if (passwordFocus.hasFocus && mode != _AuthMode.reset) return PulseAuthAvatarState.passwordFocused;
    if (emailFocus.hasFocus) return PulseAuthAvatarState.emailFocused;
    return PulseAuthAvatarState.idle;
  }

  @override
  void dispose() {
    emailFocus.removeListener(_onFocusChange);
    passwordFocus.removeListener(_onFocusChange);
    email.dispose();
    password.dispose();
    confirm.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  String? validateEmail() {
    final value = email.text.trim();
    if (value.isEmpty) return 'enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'enter a valid email address.';
    return null;
  }

  String? validatePassword() {
    if (password.text.isEmpty) return 'enter your password.';
    if (mode == _AuthMode.signUp && password.text.length < 8) return 'use at least 8 characters for your password.';
    return null;
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    final emailError = validateEmail();
    final passwordError = mode == _AuthMode.reset ? null : validatePassword();
    final mismatch = mode == _AuthMode.signUp && password.text != confirm.text;
    if (emailError != null || passwordError != null || mismatch) {
      setState(() {});
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);

    if (mode == _AuthMode.reset) {
      final error = await controller.resetPassword(email.text);
      if (!mounted) return;
      if (error == null) {
        _show('if an account can receive a reset email, you’ll get one shortly.');
        setState(() => mode = _AuthMode.signIn);
      }
      return;
    }

    final signUp = mode == _AuthMode.signUp;
    if (signUp) {
      await analytics.logSignUpStarted();
    } else {
      await analytics.logSignInStarted();
    }

    final result = signUp
        ? await controller.signUp(email.text, password.text)
        : await controller.signIn(email.text, password.text);
    if (!mounted || result == null) return;

    if (result.status == AuthStatus.authenticatedUnverified) {
      try {
        await ref.read(authServiceProvider).sendEmailVerification();
        await analytics.logEmailVerificationSent();
      } catch (_) {}
      if (mounted) {
        setState(() => submittedSuccessfully = true);
        context.go('/verify-email');
      }
      return;
    }

    if (result.status == AuthStatus.authenticated) {
      if (signUp) {
        await analytics.logSignUp();
      } else {
        await analytics.logLogin();
      }
      if (mounted) {
        setState(() => submittedSuccessfully = true);
        context.go('/splash');
      }
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen<AuthControllerState>(authControllerProvider, (_, next) {
      final message = next.error?.message;
      if (message != null && message.isNotEmpty && mounted) _show(message);
    });

    if (mode == _AuthMode.entry) return _entry(context);

    final title = switch (mode) {
      _AuthMode.signUp => 'create your account',
      _AuthMode.reset => 'reset your password',
      _AuthMode.signIn => 'welcome back',
      _AuthMode.entry => 'welcome to Pulse',
    };

    return Scaffold(
      body: SafeArea(
        child: Form(
          child: ListView(
            padding: const EdgeInsets.all(PulseSpace.xl),
            children: [
              PulseMotionAttachment(
                intent: PulseMotionIntent.onboardingCta,
                state: PulseMotionState.entering,
                child: IconButton(
                  alignment: Alignment.centerLeft,
                  onPressed: () => setState(() => mode = _AuthMode.entry),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'back',
                ),
                excludeFromSemantics: false,
              ),
              const SizedBox(height: PulseSpace.lg),
              PulseRiveAttachment(
                data: PulseMotionAttachmentData(
                  intent: PulseMotionIntent.authAvatar,
                  state: avatarState,
                  reducedMotion: PulseMotionPolicy.isReducedMotion(context),
                  duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 220)),
                ),
                assetPath: PulseRiveAssets.auth,
                fallback: const SizedBox.shrink(),
                triggerForState: const {
                  'idle': 'idle',
                  'emailFocused': 'emailFocused',
                  'passwordFocused': 'passwordFocused',
                  'error': 'error',
                  'success': 'success',
                },
                semanticLabel: 'Pulse assistant avatar',
              ),
              const SizedBox(height: PulseSpace.xl),
              Text(title, style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: PulseSpace.sm),
              Text(
                mode == _AuthMode.reset ? 'we’ll send a reset link to your email.' : 'your progress starts here.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: PulseSpace.xxl),
              TextField(
                controller: email,
                focusNode: emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: mode == _AuthMode.reset ? TextInputAction.done : TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: 'email', errorText: validateEmail()),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => mode == _AuthMode.reset ? submit() : passwordFocus.requestFocus(),
              ),
              if (mode != _AuthMode.reset) ...[
                const SizedBox(height: PulseSpace.md),
                TextField(
                  controller: password,
                  focusNode: passwordFocus,
                  obscureText: obscure,
                  textInputAction: mode == _AuthMode.signUp ? TextInputAction.next : TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'password',
                    errorText: validatePassword(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      tooltip: obscure ? 'show password' : 'hide password',
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => mode == _AuthMode.signIn ? submit() : FocusScope.of(context).nextFocus(),
                ),
                if (mode == _AuthMode.signUp) ...[
                  const SizedBox(height: PulseSpace.md),
                  TextField(
                    controller: confirm,
                    obscureText: obscure,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'confirm password',
                      errorText: confirm.text.isNotEmpty && confirm.text != password.text ? 'passwords don’t match.' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ],
              const SizedBox(height: PulseSpace.lg),
              PulseMotionBoundaryV2(
                intent: PulseMotionIntent.onboardingCta,
                state: auth.loading ? PulseMotionState.loading : PulseMotionState.idle,
                child: PulseButton(
                  expand: true,
                  onPressed: auth.loading ? null : submit,
                  loading: auth.loading,
                  label: mode == _AuthMode.signUp ? 'create account' : mode == _AuthMode.reset ? 'send reset link' : 'sign in',
                ),
              ),
              if (mode == _AuthMode.signIn)
                TextButton(
                  onPressed: auth.loading ? null : () => setState(() => mode = _AuthMode.reset),
                  child: const Text('forgot password?'),
                ),
              const SizedBox(height: PulseSpace.md),
              TextButton(
                onPressed: auth.loading ? null : () => setState(() => mode = mode == _AuthMode.signUp ? _AuthMode.signIn : _AuthMode.signUp),
                child: Text(mode == _AuthMode.signUp ? 'already have an account? sign in' : 'new to Pulse? create an account'),
              ),
              const SizedBox(height: PulseSpace.xl),
              Text(
                'email authentication is currently available. google, apple and phone sign-in are not configured in the current Firebase auth boundary.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entry(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(PulseSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                PulseMotionAttachment(
                  intent: PulseMotionIntent.onboardingIllustration,
                  state: PulseMotionState.entering,
                  child: Text('welcome to Pulse', style: AppTypography.display),
                  excludeFromSemantics: false,
                ),
                const SizedBox(height: PulseSpace.md),
                Text(
                  'make today count. one small action at a time.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: PulseSpace.xxl),
                PulseButton(expand: true, onPressed: () => setState(() => mode = _AuthMode.signUp), label: 'create account'),
                const SizedBox(height: PulseSpace.sm),
                PulseButton(expand: true, variant: PulseButtonVariant.secondary, onPressed: () => setState(() => mode = _AuthMode.signIn), label: 'sign in'),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
}
