import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/passcode_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/set_new_password_screen.dart';
import '../../core/providers/auth_provider.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/expenses/presentation/add_expense_screen.dart';
import '../../features/expenses/presentation/edit_expense_screen.dart';
import '../../features/expenses/presentation/transactions_list_screen.dart';
import '../../features/income/presentation/income_list_screen.dart';
import '../../features/income/presentation/add_income_screen.dart';
import '../../features/income/presentation/edit_income_screen.dart';
import '../../features/groups/presentation/groups_list_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/groups/presentation/create_group_screen.dart';
import '../../features/groups/presentation/group_expense_entry_screen.dart';
import '../../features/groups/presentation/edit_group_expense_screen.dart';
import '../../features/groups/presentation/settle_up_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/insights/presentation/monthly_wrap_screen.dart';
import '../../features/budget/presentation/budget_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/upi_screen.dart';
import '../../features/settings/presentation/install_guide_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../shared/widgets/scaffold_with_nested_navigation.dart';
import '../constants/durations.dart';

Page<T> _buildPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.transitionVeryFast,
    reverseTransitionDuration: AppDurations.transitionVeryFast,
    // Why animation.drive(CurveTween(...)): The previous code created a
    // CurvedAnimation(parent: animation) inside this callback, which is invoked
    // on every animation frame. CurvedAnimation extends Listenable and must be
    // disposed — but there was no owner to call .dispose(), leaking memory on
    // every navigation event. Using .drive(CurveTween) returns a plain
    // Animation<double> value with no lifecycle requirements.
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  // Why keepAlive: GoRouter holds mutable navigation state (history, deep links,
  // observers). If the provider were allowed to dispose, a fresh GoRouter would
  // be created on the next watch(), silently resetting the navigation stack.
  // keepAlive ensures exactly one instance lives for the app’s lifetime.
  ref.keepAlive();

  // Listen for Supabase PASSWORD_RECOVERY events (fired when the deep link from
  // the reset email is opened). When detected, GoRouter refreshes and the redirect
  // callback below sends the user to /set-new-password automatically.
  final authState = ref.watch(authStateProvider);
  final isRecovery = authState.value?.event == AuthChangeEvent.passwordRecovery;

  final router = GoRouter(
    initialLocation: '/splash',
    // Why redirect: After Android opens the app via the custom URL scheme,
    // supabase_flutter fires a PASSWORD_RECOVERY AuthChangeEvent. The redirect
    // callback intercepts every navigation at that point and forces the app to
    // /set-new-password so the user can enter their new password.
    redirect: (context, state) {
      if (isRecovery && state.matchedLocation != '/set-new-password') {
        return '/set-new-password';
      }
      return null; // no redirect
    },
    routes: [
      // Splash
      GoRoute(path: '/splash', pageBuilder: (context, state) => _buildPage(state, const SplashScreen())),

      // Auth
      GoRoute(path: '/login', pageBuilder: (context, state) => _buildPage(state, const LoginScreen())),
      GoRoute(path: '/signup', pageBuilder: (context, state) => _buildPage(state, const SignupScreen())),
      GoRoute(path: '/forgot-password', pageBuilder: (context, state) => _buildPage(state, const ForgotPasswordScreen())),
      GoRoute(path: '/set-new-password', pageBuilder: (context, state) => _buildPage(state, const SetNewPasswordScreen())),
      GoRoute(
        path: '/passcode',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final mode = extra?['mode'] as PasscodeMode? ?? PasscodeMode.unlock;
          final onSuccess = extra?['onSuccess'] as VoidCallback?;
          return _buildPage(state, PasscodeScreen(mode: mode, onSuccess: onSuccess));
        },
      ),

      // Nested tab navigation shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNestedNavigation(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const TransactionsListScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/income-list',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const IncomeListScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const GroupsListScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const InsightsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // Other top-level sub-routes (pushed over the bottom nav shell)
      GoRoute(path: '/notifications', pageBuilder: (context, state) => _buildPage(state, const NotificationsScreen())),
      GoRoute(path: '/notification-settings', pageBuilder: (context, state) => _buildPage(state, const NotificationSettingsScreen())),
      GoRoute(path: '/add-expense', pageBuilder: (context, state) => _buildPage(state, const AddExpenseScreen())),
      GoRoute(
        path: '/edit-expense', 
        pageBuilder: (context, state) {
          final expense = state.extra as Map<String, dynamic>;
          return _buildPage(state, EditExpenseScreen(expense: expense));
        }
      ),
      GoRoute(path: '/add-income', pageBuilder: (context, state) => _buildPage(state, const AddIncomeScreen())),
      GoRoute(
        path: '/edit-income', 
        pageBuilder: (context, state) {
          final income = state.extra as Map<String, dynamic>;
          return _buildPage(state, EditIncomeScreen(income: income));
        }
      ),
      GoRoute(
        path: '/group-detail', 
        pageBuilder: (context, state) {
          final id = state.extra as String?;
          return _buildPage(state, GroupDetailScreen(groupId: id));
        }
      ),
      GoRoute(path: '/create-group', pageBuilder: (context, state) => _buildPage(state, const CreateGroupScreen())),
      GoRoute(
        path: '/group-expense-entry', 
        pageBuilder: (context, state) {
          final id = state.extra as String?;
          return _buildPage(state, GroupExpenseEntryScreen(groupId: id));
        }
      ),
      GoRoute(
        path: '/edit-group-expense', 
        pageBuilder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return _buildPage(state, EditGroupExpenseScreen(
            groupId: data?['groupId'] as String?,
            expense: data?['expense'] as Map<String, dynamic>?,
          ));
        }
      ),
      GoRoute(
        path: '/settle-up', 
        pageBuilder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return _buildPage(state, SettleUpScreen(settlementData: data));
        }
      ),
      GoRoute(path: '/budget', pageBuilder: (context, state) => _buildPage(state, const BudgetScreen())),
      GoRoute(path: '/monthly-wrap', pageBuilder: (context, state) => _buildPage(state, const MonthlyWrapScreen())),
      GoRoute(path: '/profile', pageBuilder: (context, state) => _buildPage(state, const ProfileScreen())),
      GoRoute(path: '/upi', pageBuilder: (context, state) => _buildPage(state, const UpiScreen())),
      GoRoute(path: '/install-guide', pageBuilder: (context, state) => _buildPage(state, const InstallGuideScreen())),
    ],
  );
  return router;
});

