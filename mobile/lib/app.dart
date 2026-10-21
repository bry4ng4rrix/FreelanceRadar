import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/feedback.dart';

class FreelanceRadarApp extends ConsumerWidget {
  const FreelanceRadarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: kAppName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.dark,
    scaffoldMessengerKey: rootMessengerKey,
    routerConfig: ref.watch(appRouterProvider),
    locale: const Locale('fr', 'FR'),
    supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}
