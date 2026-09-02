import 'package:flutter/material.dart';
import '../design/pulse_tokens.dart';
import '../theme/app_theme.dart';
import 'pulse_button.dart';

class PulsePageLoading extends StatelessWidget {
  const PulsePageLoading({super.key, this.label = 'loading pulse…'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(child: Semantics(label: label, child: const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: PulseColors.accent))));
}

class PulseCardLoading extends StatelessWidget {
  const PulseCardLoading({super.key, this.height = 180});
  final double height;
  @override
  Widget build(BuildContext context) => Container(height: height, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.large)));
}

class PulseInlineLoading extends StatelessWidget {
  const PulseInlineLoading({super.key, this.label = 'loading'});
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PulseColors.accent)), const SizedBox(width: PulseSpace.sm), Text(label, style: AppTypography.metadata)]);
}

class PulseErrorState extends StatelessWidget {
  const PulseErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(PulseSpace.xxxl), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.error_outline_rounded, size: 34, color: PulseColors.error),
    const SizedBox(height: PulseSpace.lg),
    Text(message, textAlign: TextAlign.center, style: AppTypography.body),
    if (onRetry != null) ...[const SizedBox(height: PulseSpace.lg), PulseButton(label: 'try again', onPressed: onRetry)],
  ])));
}

class PulseEmptyState extends StatelessWidget {
  const PulseEmptyState({super.key, required this.title, required this.message, this.actionLabel, this.onAction});
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(PulseSpace.xxxl), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(title, textAlign: TextAlign.center, style: AppTypography.title),
    const SizedBox(height: PulseSpace.sm),
    Text(message, textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    if (actionLabel != null && onAction != null) ...[const SizedBox(height: PulseSpace.lg), PulseButton(label: actionLabel!, onPressed: onAction)],
  ])));
}

class PulseOfflineState extends StatelessWidget {
  const PulseOfflineState({super.key, this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: PulseSpace.lg, vertical: PulseSpace.md),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.medium)),
    child: Row(children: [Icon(Icons.cloud_off_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: PulseSpace.md), Expanded(child: Text('you\'re offline. pulse will retry when you\'re connected.', style: AppTypography.metadata)), if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('retry'))]),
  );
}
