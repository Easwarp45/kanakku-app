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
import 'core/providers/auth_provider.dart';
import 'features/auth/presentation/passcode_screen.dart';
import 'features/notifications/services/notification_service.dart';
import 'features/notifications/services/notification_scheduler.dart';
import 'features/notifications/providers/notification_provider.dart';

// Why themeModeProvider: The full preferencesProvider holds currency, avatar,
// app-lock, budget, passcode, and more. Watching it directly in KanakkuApp.build()
// means ANY preference change (e.g. toggling notifications) rebuilds the entire
// MaterialApp tree. This lightweight selector rebuilds only when themeIndex changes.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final themeIndex = ref.watch(preferencesProvider.select((p) => p.themeIndex));
  switch (themeIndex) {
    case 1:
      return ThemeMode.dark;
    case 2:
      return ThemeMode.light;
    default:
      return ThemeMode.system;
  }
});

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

  // ── Smart Notifications ──────────────────────────────────────────────────
  try {
    await NotificationService().initialize();
    await NotificationService().requestPermissions();
    await NotificationScheduler().initialize();
    debugPrint('[STARTUP] Smart Notifications initialized');
  } catch (e) {
    debugPrint('[STARTUP] Smart Notifications init failed: $e');
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
    // Watch only the lightweight selectors — avoids full MaterialApp rebuild
    // on unrelated preference changes (currency, avatar, budget, etc.).
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    // Warm up background notification schedules orchestrator
    ref.watch(notificationScheduleOrchestratorProvider);

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
      builder: (context, child) => AppLockLifecycleWrapper(
        child: GlobalErrorListener(child: child ?? const SizedBox()),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppLockLifecycleWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const AppLockLifecycleWrapper({super.key, required this.child});

  @override
  ConsumerState<AppLockLifecycleWrapper> createState() => _AppLockLifecycleWrapperState();
}

class _AppLockLifecycleWrapperState extends ConsumerState<AppLockLifecycleWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App went to background, require lock on next resume
      ref.read(sessionLockProvider.notifier).setLock(true);
    } else if (state == AppLifecycleState.resumed) {
      _checkLock();
    }
  }

  void _checkLock() {
    final router = ref.read(routerProvider);
    final prefs = ref.read(preferencesProvider);
    final user = ref.read(currentUserProvider);
    
    // Check if user is logged in, appLock is enabled, passcode PIN is configured,
    // and sessionLockProvider is true (needs verification)
    if (user != null && prefs.appLock && prefs.passcodePin.isNotEmpty) {
      final isLocked = ref.read(sessionLockProvider);
      if (isLocked) {
        final routeInfo = router.routerDelegate.currentConfiguration;
        final currentPath = routeInfo.uri.path;
        
        // Avoid redirecting if already on splash, login, signup, or passcode screen
        if (currentPath != '/passcode' &&
            currentPath != '/splash' &&
            currentPath != '/login' &&
            currentPath != '/signup') {
          router.go('/passcode', extra: {'mode': PasscodeMode.unlock});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
