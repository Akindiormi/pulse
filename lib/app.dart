import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'routing/app_router.dart';

class PulseApp extends ConsumerWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'PULSE',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: mode,
      routerConfig: appRouter,
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
      );
}
