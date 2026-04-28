import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'widgets/phone_shell.dart';

class EvoraApp extends ConsumerWidget {
  const EvoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Evora Health App',
      debugShowCheckedModeBanner: false,
      theme: EvoraTheme.light,
      routerConfig: router,
      builder: (context, child) {
        // On web desktop: wrap in phone shell
        // On mobile web / native: full screen
        if (kIsWeb) {
          return PhoneShell(child: child ?? const SizedBox.shrink());
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
