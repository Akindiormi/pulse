import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../design/pulse_tokens.dart';
import '../motion/pulse_motion_policy.dart';

class PulseShell extends StatelessWidget {
  const PulseShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: child),
        bottomNavigationBar: PulseBottomNavigation(currentPath: GoRouterState.of(context).uri.path),
      );
}

class PulseBottomNavigation extends StatelessWidget {
  const PulseBottomNavigation({super.key, required this.currentPath});
  final String currentPath;

  static const destinations = <_PulseDestination>[
    _PulseDestination('/home', 'home', Icons.home_rounded),
    _PulseDestination('/challenges', 'challenges', Icons.bolt_rounded),
    _PulseDestination('/achievements', 'achievements', Icons.workspace_premium_rounded),
    _PulseDestination('/profile', 'profile', Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = destinations.indexWhere((item) => currentPath == item.path || currentPath.startsWith('${item.path}/'));
    final selectedIndex = selected < 0 ? 0 : selected;
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PulseSpace.sm, PulseSpace.sm, PulseSpace.sm, PulseSpace.sm),
          child: Row(
            children: [for (var i = 0; i < destinations.length; i++) Expanded(child: _DestinationTile(destination: destinations[i], selected: i == selectedIndex, onTap: () => context.go(destinations[i].path)))],
          ),
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination, required this.selected, required this.onTap});
  final _PulseDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = PulseMotionPolicy.duration(context, const Duration(milliseconds: 180));
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PulseRadius.medium),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: PulseSpace.xs),
          padding: const EdgeInsets.symmetric(vertical: PulseSpace.sm),
          decoration: BoxDecoration(color: selected ? PulseColors.accentTint : Colors.transparent, borderRadius: BorderRadius.circular(PulseRadius.medium)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedScale(scale: selected ? 1.06 : 1, duration: duration, child: Icon(destination.icon, size: 22, color: selected ? PulseColors.accent : Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: PulseSpace.xs),
            Text(destination.label, style: AppTypography.metadata.copyWith(color: selected ? PulseColors.accent : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _PulseDestination {
  const _PulseDestination(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}
