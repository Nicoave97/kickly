import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/setup/setup_page.dart';

class KicklyApp extends StatefulWidget {
  const KicklyApp({super.key});
  @override State<KicklyApp> createState() => _KicklyAppState();
}

class _KicklyAppState extends State<KicklyApp> {
  late final router = AppConfig.isSupabaseConfigured ? createAppRouter() : null;
  @override Widget build(BuildContext context) {
    if (router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('it', 'IT')],
        home: const SetupPage(),
      );
    }
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Kickly',
      theme: AppTheme.dark,
      routerConfig: router!,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('it', 'IT')],
    );
  }
}
