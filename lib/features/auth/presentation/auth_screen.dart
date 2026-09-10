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
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  DateTime? dateOfBirth;
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();
  bool obscure = true;
  bool emailTouched = false;
  bool passwordTouched = false;
  bool identityTouched = false;
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
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  String? validateEmail() {
    final value = email.text.trim();
    if (value.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Enter a valid email address.';
    return null;
  }

  String? validatePassword() {
    if (password.text.isEmpty) return 'Enter your password.';
    if (mode == _AuthMode.signUp && password.text.length < 8) return 'Use at least 8 characters for your password.';
    return null;
  }

  String? validateFirstName() {
    final value = firstName.text.trim();
    if (value.isEmpty) return 'Enter your first name.';
    if (value.length < 2) return 'First name is too short.';
    return null;
  }

  String? validateLastName() {
    final value = lastName.text.trim();
    if (value.isEmpty) return 'Enter your last name.';
    if (value.length < 2) return 'Last name is too short.';
    return null;
  }

  String? validateDateOfBirth() {
    if (dateOfBirth == null) return 'Enter your date of birth.';
    final now = DateTime.now();
    if (dateOfBirth!.isAfter(now)) return 'That date is in the future.';
    if (now.difference(dateOfBirth!).inDays > 365 * 120) return 'Enter a valid date of birth.';
    return null;
  }

  String? validatePhone() {
    final digits = phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return 'Enter your phone number.';
    if (digits.replaceAll('+', '').length < 7) return 'Enter a valid phone number.';
    return null;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => dateOfBirth = picked);
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    final emailError = validateEmail();
    final passwordError = mode == _AuthMode.reset ? null : validatePassword();
    final signUp = mode == _AuthMode.signUp;
    final identityError = signUp && (validateFirstName() != null || validateLastName() != null || validateDateOfBirth() != null || validatePhone() != null);
    if (emailError != null || passwordError != null || identityError) {
      setState(() => identityTouched = true);
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);

    if (mode == _AuthMode.reset) {
      final error = await controller.resetPassword(email.text);
      if (!mounted) return;
      if (error == null) {
        _show('If an account can receive a reset email, you’ll get one shortly.');
        setState(() => mode = _AuthMode.signIn);
      }
      return;
    }

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
        // Identity fields live on profiles, not auth.users -- write them now
        // that we have an authenticated session (RLS requires id = auth.uid()).
        // display_name is set from firstName so the existing greeting/profile
        // reads keep working unchanged.
        if (result.uid != null) {
          try {
            await ref.read(userRepositoryProvider).createOrUpdateUser(
                  uid: result.uid!,
                  displayName: firstName.text.trim(),
                  firstName: firstName.text.trim(),
                  lastName: lastName.text.trim(),
                  dateOfBirth: dateOfBirth,
                  phoneNumber: phone.text.trim(),
                );
          } catch (_) {
            // Account creation already succeeded; a failed profile write here
            // shouldn't strand the user on the signup screen. Profile setup
            // can still complete this from /home if needed.
          }
        }
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
      _AuthMode.signUp => 'Create Your Account',
      _AuthMode.reset => 'Reset Your Password',
      _AuthMode.signIn => 'Welcome Back',
      _AuthMode.entry => 'Welcome to Pulse',
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
                  tooltip: 'Back',
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
                mode == _AuthMode.reset ? 'We’ll send a reset link to your email.' : 'Your progress starts here.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: PulseSpace.xxl),
              if (mode == _AuthMode.signUp) ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: firstName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      decoration: InputDecoration(labelText: 'First name', errorText: identityTouched ? validateFirstName() : null),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: PulseSpace.md),
                  Expanded(
                    child: TextField(
                      controller: lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      decoration: InputDecoration(labelText: 'Last name', errorText: identityTouched ? validateLastName() : null),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
                const SizedBox(height: PulseSpace.md),
                InkWell(
                  onTap: _pickDateOfBirth,
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: 'Date of birth', errorText: identityTouched ? validateDateOfBirth() : null),
                    child: Text(
                      dateOfBirth == null ? 'Select date of birth' : '${dateOfBirth!.year}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: PulseSpace.md),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: InputDecoration(labelText: 'Phone number', errorText: identityTouched ? validatePhone() : null),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: PulseSpace.md),
              ],
              TextField(
                key: const Key('auth-email-field'),
                controller: email,
                focusNode: emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: mode == _AuthMode.reset ? TextInputAction.done : TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: 'Email address', errorText: validateEmail()),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => mode == _AuthMode.reset ? submit() : passwordFocus.requestFocus(),
              ),
              if (mode != _AuthMode.reset) ...[
                const SizedBox(height: PulseSpace.md),
                TextField(
                  key: const Key('auth-password-field'),
                  controller: password,
                  focusNode: passwordFocus,
                  obscureText: obscure,
                  textInputAction: mode == _AuthMode.signUp ? TextInputAction.next : TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: validatePassword(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      tooltip: obscure ? 'Show password' : 'Hide password',
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => mode == _AuthMode.signIn ? submit() : submit(),
                ),
              ],
              const SizedBox(height: PulseSpace.lg),
              PulseMotionBoundaryV2(
                intent: PulseMotionIntent.onboardingCta,
                state: auth.loading ? PulseMotionState.loading : PulseMotionState.idle,
                child: PulseButton(
                  expand: true,
                  onPressed: auth.loading ? null : submit,
                  loading: auth.loading,
                  label: mode == _AuthMode.signUp ? 'Create Account' : mode == _AuthMode.reset ? 'Send Reset Link' : 'Sign In',
                ),
              ),
              if (mode == _AuthMode.signIn)
                TextButton(
                  onPressed: auth.loading ? null : () => setState(() => mode = _AuthMode.reset),
                  child: const Text('Forgot password?'),
                ),
              const SizedBox(height: PulseSpace.md),
              TextButton(
                onPressed: auth.loading ? null : () => setState(() => mode = mode == _AuthMode.signUp ? _AuthMode.signIn : _AuthMode.signUp),
                child: Text(mode == _AuthMode.signUp ? 'Already have an account? Sign in' : 'New to Pulse? Create an account'),
              ),
              const SizedBox(height: PulseSpace.xl),
              Text(
                'Email authentication is available. Google, Apple and phone sign-in are not configured.',
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
                  child: Text('Welcome to Pulse', style: AppTypography.display),
                  excludeFromSemantics: false,
                ),
                const SizedBox(height: PulseSpace.md),
                Text(
                  'Make today count. One small action at a time.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: PulseSpace.xxl),
                PulseButton(expand: true, onPressed: () => setState(() => mode = _AuthMode.signUp), label: 'Create Account'),
                const SizedBox(height: PulseSpace.sm),
                PulseButton(expand: true, variant: PulseButtonVariant.secondary, onPressed: () => setState(() => mode = _AuthMode.signIn), label: 'Sign In'),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
}
