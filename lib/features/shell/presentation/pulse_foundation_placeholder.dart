import 'package:flutter/material.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/theme/app_theme.dart';

class PulseFoundationPlaceholder extends StatelessWidget {
  const PulseFoundationPlaceholder({super.key, required this.title, this.detail});
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(PulseSpace.xxl, PulseSpace.xxxl, PulseSpace.xxl, PulseSpace.hero),
          sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTypography.display),
            if (detail != null) ...[const SizedBox(height: PulseSpace.md), Text(detail!, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))],
          ])),
        ),
      ]);
}
