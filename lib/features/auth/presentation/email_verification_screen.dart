import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_error.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});
  @override ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool loading = false;
  String? error;
  DateTime? nextResend;

  Future<void> resend() async {
    if (loading || (nextResend != null && DateTime.now().isBefore(nextResend!))) return;
    setState(() { loading = true; error = null; });
    try { await ref.read(authServiceProvider).sendEmailVerification(); await ref.read(analyticsServiceProvider).logEmailVerificationSent(); if (mounted) { setState(() { loading = false; nextResend = DateTime.now().add(const Duration(seconds: 30)); }); } }
    catch (e) { if (mounted) setState(() { loading = false; error = ErrorMessageMapper.from(e, kind: AppErrorKind.verification).message; }); }
  }

  Future<void> check() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try { final verified = await ref.read(authServiceProvider).reloadVerificationState(); if (!mounted) return; if (verified) { await ref.read(analyticsServiceProvider).logEmailVerificationCompleted(); context.go('/profile-setup'); } else { setState(() { loading = false; error = 'your email hasn’t been verified yet. check your inbox and try again.'; }); } }
    catch (e) { if (mounted) setState(() { loading = false; error = ErrorMessageMapper.from(e, kind: AppErrorKind.verification).message; }); }
  }

  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(PulseSpace.xl), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Spacer(), Text('check your inbox.', style: AppTypography.display), const SizedBox(height: PulseSpace.md), Text('we sent a verification link to your email. verify it, then come back here.', style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: PulseSpace.xl), if (error != null) Semantics(liveRegion: true, child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))), const SizedBox(height: PulseSpace.lg), SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: loading ? null : check, child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('i’ve verified'))), const SizedBox(height: PulseSpace.sm), SizedBox(width: double.infinity, child: OutlinedButton(onPressed: loading ? null : resend, child: Text(nextResend != null && DateTime.now().isBefore(nextResend!) ? 'resend available soon' : 'resend email'))), const Spacer(), TextButton(onPressed: loading ? null : () => context.go('/auth'), child: const Text('use a different account'))])));
}
