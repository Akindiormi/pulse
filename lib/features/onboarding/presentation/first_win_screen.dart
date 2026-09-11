import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/widgets/pulse_button.dart';
import '../application/new_user_activation_controller.dart';

class FirstWinScreen extends ConsumerWidget {
  const FirstWinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activation = ref.watch(newUserActivationProvider).valueOrNull;
    final title = activation?.priority?.trim();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PulseSpace.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('you did it.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: PulseSpace.md),
                Text('first task complete.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: PulseSpace.lg),
                if (title != null && title.isNotEmpty) Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: PulseSpace.xxl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(PulseSpace.xl),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.large)),
                  child: Column(children: [
                    Text('focus session completed', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('your project now has real progress.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                ),
                const SizedBox(height: PulseSpace.xxl),
                PulseButton(expand: true, label: 'go to Home', onPressed: () async {
                  await ref.read(newUserActivationProvider.notifier).complete();
                  if (context.mounted) context.go('/home');
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
