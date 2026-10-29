import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/theme.dart';
import '../core/l10n/app_localizations.dart';
import '../features/settings/settings.dart';
import 'providers.dart';
import 'router.dart';

class LumenApp extends ConsumerWidget {
  const LumenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isTv = ref.watch(deviceProfileProvider).isTv;
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Lumen',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: settings.themeMode,
      theme: buildLumenTheme(
          brightness: Brightness.light, accent: settings.accent, isTv: isTv),
      darkTheme: buildLumenTheme(
          brightness: Brightness.dark, accent: settings.accent, isTv: isTv),
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
