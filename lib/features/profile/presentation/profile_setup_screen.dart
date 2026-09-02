import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_error.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final name = TextEditingController();
  bool saving = false;
  String? error;
  @override void initState() { super.initState(); Future.microtask(_load); }
  Future<void> _load() async { final auth = ref.read(authServiceProvider); final states = await auth.authStateChanges.first; if (!mounted || states.uid == null) return; final user = await ref.read(userRepositoryProvider).getUserModel(states.uid!); if (mounted && user?.displayName != null) name.text = user!.displayName!; }
  Future<void> save() async {
    final displayName = name.text.trim();
    if (displayName.length < 2) { setState(() => error = 'enter a name with at least 2 characters.'); return; }
    if (displayName.length > 40) { setState(() => error = 'keep your name under 40 characters.'); return; }
    if (saving) return; setState(() { saving = true; error = null; });
    try { final state = await ref.read(authServiceProvider).authStateChanges.first; if (state.uid == null) throw const AuthFailure('session-expired'); await ref.read(userRepositoryProvider).createOrUpdateUser(uid: state.uid!, displayName: displayName); await ref.read(analyticsServiceProvider).logProfileSetupCompleted(); if (mounted) context.go('/home'); }
    catch (e) { if (mounted) setState(() { saving = false; error = ErrorMessageMapper.from(e, kind: AppErrorKind.profile).message; }); }
  }
  @override void dispose() { name.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(PulseSpace.xl), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Spacer(), Text('set up your Pulse profile', style: AppTypography.display), const SizedBox(height: PulseSpace.md), Text('just your display name for now. you can keep moving after this.', style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: PulseSpace.xxl), TextField(controller: name, textInputAction: TextInputAction.done, autofillHints: const [AutofillHints.name], maxLength: 40, decoration: InputDecoration(labelText: 'display name', errorText: error), onSubmitted: (_) => save()), const SizedBox(height: PulseSpace.lg), SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('continue'))), const Spacer()])));
}
