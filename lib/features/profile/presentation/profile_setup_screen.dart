import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/pulse_button.dart';
import '../../onboarding/application/new_user_activation_controller.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final name = TextEditingController();
  final priority = TextEditingController();
  String? area;
  bool saving = false;
  String? error;

  static const areas = ['School', 'Work', 'Business', 'Personal', 'Health', 'Something else'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final state = await ref.read(newUserActivationProvider.future);
      if (!mounted) return;
      if (state.priority != null) priority.text = state.priority!;
      if (state.area != null) area = state.area;
      setState(() {});
    });
    Future.microtask(() => ref.read(analyticsServiceProvider).logProfileSetupStarted());
  }

  @override
  void dispose() {
    name.dispose();
    priority.dispose();
    super.dispose();
  }

  Future<void> nextPersonal() async {
    final value = name.text.trim();
    if (value.length < 2) return setState(() => error = 'Enter a name with at least 2 characters.');
    if (area == null) return setState(() => error = 'Choose what matters most right now.');
    await _run(() => ref.read(newUserActivationProvider.notifier).savePersonal(displayName: value, area: area!));
  }

  Future<void> nextPriority() async {
    if (priority.text.trim().isEmpty) return setState(() => error = 'Tell Pulse what matters right now.');
    await _run(() => ref.read(newUserActivationProvider.notifier).savePriority(priority.text));
  }

  Future<void> createWork() async {
    await _run(() async {
      await ref.read(newUserActivationProvider.notifier).createFirstWork();
      final state = ref.read(newUserActivationProvider).valueOrNull;
      if (mounted && state?.taskId != null) context.go('/first-focus?taskId=${Uri.encodeQueryComponent(state!.taskId!)}');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (saving) return;
    setState(() { saving = true; error = null; });
    try {
      await action();
      if (mounted) setState(() => saving = false);
    } catch (e) {
      if (mounted) setState(() { saving = false; error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newUserActivationProvider).valueOrNull;
    final step = state?.step ?? ActivationStep.personal;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(PulseSpace.xl, PulseSpace.xl, PulseSpace.xl, PulseSpace.xxxl),
          children: [
            Text('PULSE', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: PulseSpace.giant),
            if (step == ActivationStep.personal) _personal(context),
            if (step == ActivationStep.priority) _priority(context),
            if (step == ActivationStep.work) _work(context),
            if (step == ActivationStep.focus || step == ActivationStep.firstWin) _resume(context, step),
            if (error != null) ...[const SizedBox(height: PulseSpace.md), Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          ],
        ),
      ),
    );
  }

  Widget _personal(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('make Pulse yours', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: PulseSpace.md),
        Text('Start with the basics. We’ll use them to shape your first experience.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: PulseSpace.xxl),
        TextField(controller: name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.done, maxLength: 40, decoration: const InputDecoration(labelText: 'Display name')),
        const SizedBox(height: PulseSpace.lg),
        Text('What matters most to you right now?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: PulseSpace.md),
        Wrap(spacing: 8, runSpacing: 8, children: areas.map((item) => ChoiceChip(label: Text(item), selected: area == item, onSelected: (_) => setState(() => area = item))).toList()),
        const SizedBox(height: PulseSpace.xxl),
        PulseButton(expand: true, loading: saving, label: 'continue', onPressed: saving ? null : nextPersonal),
      ]);

  Widget _priority(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('what matters most right now?', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: PulseSpace.md),
        Text('Give Pulse one real outcome to help you move forward.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: PulseSpace.xxl),
        TextField(controller: priority, autofocus: true, maxLength: 100, textInputAction: TextInputAction.done, decoration: const InputDecoration(labelText: 'Your priority', hintText: 'e.g. launch my website')),
        const SizedBox(height: PulseSpace.xxl),
        PulseButton(expand: true, loading: saving, label: 'continue', onPressed: saving ? null : nextPriority),
      ]);

  Widget _work(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('let’s turn it into work', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: PulseSpace.md),
        Text('Pulse will create a real project and your first task. You can build it out later.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: PulseSpace.xxl),
        Container(padding: const EdgeInsets.all(PulseSpace.xl), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.large)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Project', style: Theme.of(context).textTheme.labelLarge), const SizedBox(height: 6), Text(priority.text.trim(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: PulseSpace.lg), Text('First task', style: Theme.of(context).textTheme.labelLarge), const SizedBox(height: 6), Text(priority.text.trim(), style: Theme.of(context).textTheme.bodyLarge)])),
        const SizedBox(height: PulseSpace.xxl),
        PulseButton(expand: true, loading: saving, label: 'create my first work', onPressed: saving ? null : createWork),
      ]);

  Widget _resume(BuildContext context, ActivationStep step) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(step == ActivationStep.firstWin ? 'one last step' : 'your first Pulse session is ready', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: PulseSpace.md),
        Text(step == ActivationStep.firstWin ? 'Your first focus is complete. Finish the first win to enter Home.' : 'We saved your setup. Continue with your real first task.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: PulseSpace.xxl),
        PulseButton(expand: true, label: step == ActivationStep.firstWin ? 'view first win' : 'start first focus', onPressed: () => context.go(step == ActivationStep.firstWin ? '/first-win' : '/first-focus?taskId=${Uri.encodeQueryComponent(ref.read(newUserActivationProvider).valueOrNull?.taskId ?? '')}')),
      ]);
}
