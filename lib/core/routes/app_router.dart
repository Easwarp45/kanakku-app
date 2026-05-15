import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/expenses/presentation/add_expense_screen.dart';
import '../../features/income/presentation/income_list_screen.dart';
import '../../features/income/presentation/income_detail_screen.dart';
import '../../features/groups/presentation/groups_list_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      // Auth
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),

      // Dashboard
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),

      // Expenses
      GoRoute(path: '/add-expense', builder: (context, state) => const AddExpenseScreen()),

      // Income
      GoRoute(path: '/income-list', builder: (context, state) => const IncomeListScreen()),
      GoRoute(path: '/income-detail', builder: (context, state) => const IncomeDetailScreen()),

      // Groups
      GoRoute(path: '/groups', builder: (context, state) => const GroupsListScreen()),
      GoRoute(path: '/group-detail', builder: (context, state) => const GroupDetailScreen()),
      GoRoute(path: '/group-expense-entry', builder: (context, state) => const GroupExpenseEntryScreen()),
      GoRoute(path: '/edit-group-expense', builder: (context, state) => const EditGroupExpenseScreen()),
      GoRoute(path: '/settle-up', builder: (context, state) => const SettleUpScreen()),

      // Budget
      GoRoute(path: '/budget', builder: (context, state) => const BudgetScreen()),

      // Insights
      GoRoute(path: '/insights', builder: (context, state) => const InsightsScreen()),
      GoRoute(path: '/monthly-wrap', builder: (context, state) => const MonthlyWrapScreen()),

      // Settings & Profile
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/upi', builder: (context, state) => const UpiScreen()),
      GoRoute(path: '/install-guide', builder: (context, state) => const InstallGuideScreen()),
    ],
  );
});
