import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pulse_button.dart';
import '../../onboarding/application/new_user_activation_controller.dart';
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
  bool obscure = true;
  bool identityTouched = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(analyticsServiceProvider).logAuthScreenViewed());
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
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

  String? validateFirstName() => firstName.text.trim().length < 2 ? 'Enter your first name.' : null;
  String? validateLastName() => lastName.text.trim().length < 2 ? 'Enter your last name.' : null;

  String? validateDateOfBirth() {
    if (dateOfBirth == null) return 'Enter your date of birth.';
    if (dateOfBirth!.isAfter(DateTime.now())) return 'That date is in the future.';
    return null;
  }

  String? validatePhone() => phone.text.replaceAll(RegExp(r'[^0-9+]'), '').replaceAll('+', '').length < 7 ? 'Enter a valid phone number.' : null;

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
      if (mounted && error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('If an account can receive a reset email, you’ll get one shortly.')));
        setState(() => mode = _AuthMode.signIn);
      }
      return;
    }

    if (signUp) {
      await analytics.logSignUpStarted();
    } else {
      await analytics.logSignInStarted();
    }
    final result = signUp ? await controller.signUp(email.text, password.text) : await controller.signIn(email.text, password.text);
    if (!mounted || result == null) return;
    if (result.status != AuthStatus.authenticated || result.uid == null) return;

    if (signUp) {
      try {
        await ref.read(userRepositoryProvider).createOrUpdateUser(
              uid: result.uid!,
              displayName: firstName.text.trim(),
              firstName: firstName.text.trim(),
              lastName: lastName.text.trim(),
              dateOfBirth: dateOfBirth,
              phoneNumber: phone.text.trim(),
            );
        await ref.read(newUserActivationProvider.notifier).begin();
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Your account is ready, but setup could not be saved. Please continue again. $error')));
        return;
      }
      await analytics.logSignUp();
    } else {
      await analytics.logLogin();
    }
    if (mounted) {
      if (signUp) {
        context.go('/profile-setup');
      } else {
        context.go('/splash');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen<AuthControllerState>(authControllerProvider, (_, next) {
      final message = next.error?.message;
      if (message != null && message.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
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
              IconButton(alignment: Alignment.centerLeft, onPressed: auth.loading ? null : () => setState(() => mode = _AuthMode.entry), icon: const Icon(Icons.arrow_back), tooltip: 'Back'),
              const SizedBox(height: PulseSpace.lg),
              Text(title, style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: PulseSpace.sm),
              Text(mode == _AuthMode.reset ? 'We’ll send a reset link to your email.' : 'Your progress starts here.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: PulseSpace.xxl),
              if (mode == _AuthMode.signUp) ...[
                Row(children: [
                  Expanded(child: TextField(controller: firstName, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.givenName], decoration: InputDecoration(labelText: 'First name', errorText: identityTouched ? validateFirstName() : null))),
                  const SizedBox(width: PulseSpace.md),
                  Expanded(child: TextField(controller: lastName, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.familyName], decoration: InputDecoration(labelText: 'Last name', errorText: identityTouched ? validateLastName() : null))),
                ]),
                const SizedBox(height: PulseSpace.md),
                InkWell(onTap: _pickDateOfBirth, child: InputDecorator(decoration: InputDecoration(labelText: 'Date of birth', errorText: identityTouched ? validateDateOfBirth() : null), child: Text(dateOfBirth == null ? 'Select date of birth' : '${dateOfBirth!.year}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}'))),
                const SizedBox(height: PulseSpace.md),
                TextField(controller: phone, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.telephoneNumber], decoration: InputDecoration(labelText: 'Phone number', errorText: identityTouched ? validatePhone() : null)),
                const SizedBox(height: PulseSpace.md),
              ],
              TextField(key: const Key('auth-email-field'), controller: email, keyboardType: TextInputType.emailAddress, textInputAction: mode == _AuthMode.reset ? TextInputAction.done : TextInputAction.next, autofillHints: const [AutofillHints.email], decoration: InputDecoration(labelText: 'Email address', errorText: validateEmail()), onSubmitted: (_) => mode == _AuthMode.reset ? submit() : null),
              if (mode != _AuthMode.reset) ...[
                const SizedBox(height: PulseSpace.md),
                TextField(key: const Key('auth-password-field'), controller: password, obscureText: obscure, textInputAction: TextInputAction.done, autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText: 'Password', errorText: validatePassword(), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off), tooltip: obscure ? 'Show password' : 'Hide password')), onSubmitted: (_) => submit()),
              ],
              const SizedBox(height: PulseSpace.lg),
              PulseButton(expand: true, onPressed: auth.loading ? null : submit, loading: auth.loading, label: mode == _AuthMode.signUp ? 'Create Account' : mode == _AuthMode.reset ? 'Send Reset Link' : 'Sign In'),
              if (mode == _AuthMode.signIn) TextButton(onPressed: auth.loading ? null : () => setState(() => mode = _AuthMode.reset), child: const Text('Forgot password?')),
              const SizedBox(height: PulseSpace.md),
              TextButton(onPressed: auth.loading ? null : () => setState(() => mode = mode == _AuthMode.signUp ? _AuthMode.signIn : _AuthMode.signUp), child: Text(mode == _AuthMode.signUp ? 'Already have an account? Sign in' : 'New to Pulse? Create an account')),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              Text('Welcome to Pulse', style: AppTypography.display),
              const SizedBox(height: PulseSpace.md),
              Text('Turn intentions into focused work.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: PulseSpace.xxl),
              PulseButton(expand: true, onPressed: () => setState(() => mode = _AuthMode.signUp), label: 'Create Account'),
              const SizedBox(height: PulseSpace.sm),
              PulseButton(expand: true, variant: PulseButtonVariant.secondary, onPressed: () => setState(() => mode = _AuthMode.signIn), label: 'Sign In'),
              const Spacer(),
            ]),
          ),
        ),
      );
}
