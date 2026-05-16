import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
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
import '../constants/durations.dart';

Page<T> _buildPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.transitionVeryFast,
    reverseTransitionDuration: AppDurations.transitionVeryFast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curve, child: child);
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      // Auth
      GoRoute(path: '/login', pageBuilder: (context, state) => _buildPage(state, const LoginScreen())),
      GoRoute(path: '/signup', pageBuilder: (context, state) => _buildPage(state, const SignupScreen())),

      // Dashboard
      GoRoute(path: '/dashboard', pageBuilder: (context, state) => _buildPage(state, const DashboardScreen())),

      // Expenses
      GoRoute(path: '/add-expense', pageBuilder: (context, state) => _buildPage(state, const AddExpenseScreen())),
      GoRoute(
        path: '/edit-expense', 
        pageBuilder: (context, state) {
          final expense = state.extra as Map<String, dynamic>;
          return _buildPage(state, EditExpenseScreen(expense: expense));
        }
      ),
      GoRoute(path: '/transactions', pageBuilder: (context, state) => _buildPage(state, const TransactionsListScreen())),

      // Income
      GoRoute(path: '/income-list', pageBuilder: (context, state) => _buildPage(state, const IncomeListScreen())),
      GoRoute(path: '/add-income', pageBuilder: (context, state) => _buildPage(state, const AddIncomeScreen())),
      GoRoute(
        path: '/edit-income', 
        pageBuilder: (context, state) {
          final income = state.extra as Map<String, dynamic>;
          return _buildPage(state, EditIncomeScreen(income: income));
        }
      ),

      // Groups
      GoRoute(path: '/groups', pageBuilder: (context, state) => _buildPage(state, const GroupsListScreen())),
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
      GoRoute(path: '/edit-group-expense', pageBuilder: (context, state) => _buildPage(state, const EditGroupExpenseScreen())),
      GoRoute(
        path: '/settle-up', 
        pageBuilder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return _buildPage(state, SettleUpScreen(settlementData: data));
        }
      ),

      // Budget
      GoRoute(path: '/budget', pageBuilder: (context, state) => _buildPage(state, const BudgetScreen())),

      // Insights
      GoRoute(path: '/insights', pageBuilder: (context, state) => _buildPage(state, const InsightsScreen())),
      GoRoute(path: '/monthly-wrap', pageBuilder: (context, state) => _buildPage(state, const MonthlyWrapScreen())),

      // Settings & Profile
      GoRoute(path: '/settings', pageBuilder: (context, state) => _buildPage(state, const SettingsScreen())),
      GoRoute(path: '/profile', pageBuilder: (context, state) => _buildPage(state, const ProfileScreen())),
      GoRoute(path: '/upi', pageBuilder: (context, state) => _buildPage(state, const UpiScreen())),
      GoRoute(path: '/install-guide', pageBuilder: (context, state) => _buildPage(state, const InstallGuideScreen())),
    ],
  );
});
