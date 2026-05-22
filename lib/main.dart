import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/database/hive_service.dart';
import 'core/database/local_cache_service.dart';
import 'core/logging/app_logger.dart';
import 'core/ui/global_error_handler.dart';
import 'core/feature_flags/feature_flags.dart';
import 'core/providers/preferences_provider.dart';

Future<void> main() async {
  // Protect the entire app in a zone so unhandled async errors are caught
  // and logged rather than silently killing the process.
  await runZonedGuarded(
    _bootstrap,
    (error, stack) {
      debugPrint('[ZONE ERROR] $error\n$stack');
    },
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forward Flutter framework errors to the console instead of crashing.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[FLUTTER ERROR] ${details.exceptionAsString()}');
    debugPrint('${details.stack}');
    // Let the framework continue — don't re-throw.
  };

  // ── Load .env ────────────────────────────────────────────────────────────
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[STARTUP] .env loaded');
  } catch (e) {
    debugPrint('[STARTUP] .env load failed (will use empty strings): $e');
  }

  // ── Supabase ─────────────────────────────────────────────────────────────
  try {
    await Supabase.initialize(
      url: dotenv.env['VITE_SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['VITE_SUPABASE_ANON_KEY'] ?? '',
    );
    debugPrint('[STARTUP] Supabase initialized');
  } catch (e) {
    debugPrint('[STARTUP] Supabase init failed: $e');
    // Continue — app can still launch and show login/offline UI
  }

  // ── Hive / LocalCache ────────────────────────────────────────────────────
  try {
    await HiveService.initialize();
    debugPrint('[STARTUP] Hive initialized');
  } catch (e) {
    debugPrint('[STARTUP] Hive init failed: $e');
    // Continue — LocalCache will use empty fallbacks
  }

  try {
    await LocalCacheService.initialize();
    debugPrint('[STARTUP] LocalCacheService initialized');
  } catch (e) {
    debugPrint('[STARTUP] LocalCacheService init failed: $e');
  }

  // ── Logger ───────────────────────────────────────────────────────────────
  try {
    logger.init();
  } catch (e) {
    debugPrint('[STARTUP] Logger init failed: $e');
  }

  // ── Feature Flags ────────────────────────────────────────────────────────
  try {
    await FeatureFlags.load();
    debugPrint('[STARTUP] FeatureFlags loaded');
  } catch (e) {
    debugPrint('[STARTUP] FeatureFlags load failed: $e');
  }

  debugPrint('[STARTUP] Launching app...');

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
    final prefs = ref.watch(preferencesProvider);
    
    ThemeMode themeMode;
    switch (prefs.themeIndex) {
      case 0:
        themeMode = ThemeMode.system;
        break;
      case 1:
        themeMode = ThemeMode.dark;
        break;
      case 2:
        themeMode = ThemeMode.light;
        break;
      default:
        themeMode = ThemeMode.dark;
    }

    return MaterialApp.router(
      title: 'Kanakku Expense Tracker',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
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
      builder: (context, child) =>
          GlobalErrorListener(child: child ?? const SizedBox()),
      debugShowCheckedModeBanner: false,
    );
  }
}
