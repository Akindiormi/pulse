import 'package:flutter/material.dart';
import '../design/pulse_tokens.dart';
import '../motion/pulse_interaction.dart';
import '../theme/app_theme.dart';

class PulseButton extends StatelessWidget {
  const PulseButton({super.key, required this.label, this.onPressed, this.variant = PulseButtonVariant.primary, this.loading = false, this.icon, this.expand = false});

  final String label;
  final VoidCallback? onPressed;
  final PulseButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: loading
          ? const SizedBox(key: ValueKey('loading'), width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(key: const ValueKey('content'), mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: PulseSpace.sm)],
              Text(label),
            ]),
    );

    final button = switch (variant) {
      PulseButtonVariant.primary => FilledButton(onPressed: enabled ? onPressed : null, style: _style(context), child: child),
      PulseButtonVariant.secondary => OutlinedButton(onPressed: enabled ? onPressed : null, style: _secondaryStyle(context), child: child),
      PulseButtonVariant.tertiary => TextButton(onPressed: enabled ? onPressed : null, child: child),
      PulseButtonVariant.destructive => FilledButton(onPressed: enabled ? onPressed : null, style: _destructiveStyle(context), child: child),
    };

    final tactile = PulsePressScale(scale: .985, child: button);
    return expand ? SizedBox(width: double.infinity, child: tactile) : tactile;
  }

  ButtonStyle _style(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: PulseColors.accent,
        foregroundColor: const Color(0xFF1A100D),
        disabledBackgroundColor: PulseColors.accent.withValues(alpha: 0.35),
        disabledForegroundColor: const Color(0xFF1A100D).withValues(alpha: 0.55),
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: PulseSpace.xl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.medium)),
        textStyle: AppTypography.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      );

  ButtonStyle _secondaryStyle(BuildContext context) => OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: PulseSpace.xl),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.medium)),
        textStyle: AppTypography.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      );

  ButtonStyle _destructiveStyle(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: PulseColors.error,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.medium)),
        textStyle: AppTypography.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      );
}

enum PulseButtonVariant { primary, secondary, tertiary, destructive }

class PulseIconButton extends StatelessWidget {
  const PulseIconButton({super.key, required this.icon, this.onPressed, this.tooltip, this.selected = false});
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) => PulsePressScale(
        scale: .96,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: selected ? PulseColors.accentTint : Colors.transparent,
            foregroundColor: selected ? PulseColors.accent : Theme.of(context).colorScheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.medium)),
          ),
        ),
      );
}
