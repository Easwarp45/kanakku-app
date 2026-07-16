import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/database/local_cache_service.dart';
import '../../expenses/data/expense_service.dart';
import '../../income/data/income_service.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/multi_currency_helper.dart';

class MonthlyWrapScreen extends ConsumerWidget {
  const MonthlyWrapScreen({super.key});

  double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final incomeAsync = ref.watch(incomeStreamProvider);
    final prefState = ref.watch(preferencesProvider);
    final prefCurrency = supportedCurrencies[prefState.currencyIndex];
    final notifier = ref.read(preferencesProvider.notifier);

    if (expensesAsync.isLoading || incomeAsync.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
      );
    }

    final expenses = expensesAsync.value ?? [];
    final incomes = incomeAsync.value ?? [];
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);

    final monthlyIncomes = incomes.where((e) {
      final d = DateTime.tryParse(e['income_date']?.toString() ?? e['created_at']?.toString() ?? '');
      return d != null && d.year == now.year && d.month == now.month;
    });
    final monthlyIncome = monthlyIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    final monthlyExpensesList = expenses.where((e) {
      final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
      return d != null && d.year == now.year && d.month == now.month;
    });
    final monthlyExpense = monthlyExpensesList.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    final double savingsRate = monthlyIncome > 0 ? ((monthlyIncome - monthlyExpense) / monthlyIncome) : 0.0;
    final double netWorthSurge = savingsRate * 100;

    final totalIncome = incomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final totalExpense = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final reserves = totalIncome - totalExpense;

    final user = ref.watch(currentUserProvider);
    List<Map<String, dynamic>> goals = [];
    if (user != null) {
      goals = LocalCacheService.getCachedList('local_goals_${user.id}');
    }
    final completedGoal = goals.firstWhere(
      (g) => _parseAmount(g['currentAmount']) >= _parseAmount(g['targetAmount']),
      orElse: () => <String, dynamic>{},
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: Text('$monthName Wrap', style: const TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroMessage(savingsRate, netWorthSurge, monthName),
              const SizedBox(height: 24),
              _buildGoalAchievement(completedGoal, goals),
              const SizedBox(height: 24),
              _buildSecuredAssets(reserves, savingsRate, prefCurrency, notifier),
              const SizedBox(height: 24),
              _buildNextMonthStrategy(reserves, prefCurrency, notifier),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMessage(double savingsRate, double netWorthSurge, String monthName) {
    final statusText = savingsRate >= 0.20
        ? 'A stellar performance, Executive.'
        : 'A cautious performance, Executive.';

    final sign = netWorthSurge >= 0 ? '+' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF0e3a4a), AppColors.accentCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.trendingUp, color: AppColors.accentCyan, size: 28),
          const SizedBox(height: 16),
          Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 8),
          const Text('Your net worth surged by', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text('$sign${netWorthSurge.toStringAsFixed(1)}%', style: AppTheme.moneyStyle.copyWith(fontSize: 36, color: AppColors.accentEmerald)),
          const SizedBox(height: 4),
          Text('this $monthName', style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 16),
          const Text(
            'You effectively managed liquidity while accelerating long-term positions. Here is how your capital moved through the ecosystem.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalAchievement(Map<String, dynamic> completedGoal, List<Map<String, dynamic>> goals) {
    final hasCompleted = completedGoal.isNotEmpty;
    final title = hasCompleted ? 'Goal Achieved!' : 'Goal Status';
    final name = hasCompleted ? completedGoal['name']?.toString() ?? 'Untitled Goal' : '';

    String body = 'You reached your "$name" goal early this month. Excellent discipline!';
    if (!hasCompleted) {
      if (goals.isEmpty) {
        body = 'No financial goals set. Head over to the Goal Trajectory module under intelligence to outline major purchase targets.';
      } else {
        body = 'You are currently tracking ${goals.length} active financial goals. Maintain consistent deposits to hit targets.';
      }
    }

    return GlassCard(
      margin: EdgeInsets.zero,
      borderColor: hasCompleted ? AppColors.accentEmerald.withValues(alpha: 0.4) : AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (hasCompleted ? AppColors.accentEmerald : AppColors.accentCyan).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(hasCompleted ? LucideIcons.trophy : LucideIcons.target, color: hasCompleted ? AppColors.accentEmerald : AppColors.accentCyan, size: 22),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          if (hasCompleted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.checkCircle, color: AppColors.accentEmerald, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '$name — ACHIEVED',
                      style: const TextStyle(color: AppColors.accentEmerald, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSecuredAssets(double reserves, double savingsRate, CurrencyInfo prefCurrency, PreferencesNotifier notifier) {
    final reservesPref = notifier.convertFromBaseline(reserves);
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentCyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.database, color: AppColors.accentCyan, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Secured Assets', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your emergency and strategic liquidity reserves total ${CurrencyFormatter.format(reservesPref, prefCurrency.code)}. They are currently earning interest across primary accounts.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          Text('Reserves: ${CurrencyFormatter.format(reservesPref, prefCurrency.code)}', style: AppTheme.moneyStyle.copyWith(fontSize: 24, color: AppColors.accentCyan)),
        ],
      ),
    );
  }

  Widget _buildNextMonthStrategy(double reserves, CurrencyInfo prefCurrency, PreferencesNotifier notifier) {
    final double vaultAllocation = (reserves * 0.25).clamp(1000.0, 50000.0);
    final vaultAllocationPref = notifier.convertFromBaseline(vaultAllocation);

    return GlassCard(
      margin: EdgeInsets.zero,
      borderColor: AppColors.accentPurple.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentPurple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.lightbulb, color: AppColors.accentPurple, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Next Month Strategy', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Based on current burn rates and dividend forecasts, we recommend allocating ${CurrencyFormatter.format(vaultAllocationPref, prefCurrency.code)} into long-term investments to maximize capital efficiency.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(LucideIcons.arrowRight, color: AppColors.accentPurple, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${CurrencyFormatter.format(vaultAllocationPref, prefCurrency.code)} to Investment Vault',
                  style: AppTheme.moneyStyle.copyWith(fontSize: 18, color: AppColors.accentPurple),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
