import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/database/hive_service.dart';
import 'core/logging/app_logger.dart';
import 'core/ui/global_error_handler.dart';
import 'core/feature_flags/feature_flags.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await HiveService.initialize();
  // Initialize logging
  logger.init();
  // Preload feature flags
  await FeatureFlags.load();
  
  runApp(
    const ProviderScope(
      child: KanakkuApp(),
    ),
  );
}

class KanakkuApp extends ConsumerWidget {
  const KanakkuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Kanakku Expense Tracker',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
      builder: (context, child) => GlobalErrorListener(child: child ?? const SizedBox()),
      debugShowCheckedModeBanner: false,
    );
  }
}
