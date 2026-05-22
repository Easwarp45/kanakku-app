import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/database/local_cache_service.dart';
import '../../expenses/data/expense_service.dart';
import '../../income/data/income_service.dart';
import '../../budget/data/budget_service.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/multi_currency_helper.dart';

class InsightsQuickStats {
  final int healthScore;
  final String healthCategory;
  final String topSpendCategory;
  final String lifestylePersona;
  final int aiAlertsCount;
  final double nextMonthForecast;
  final int recommendationCount;
  final int riskAlertsCount;
  final int subscriptionCount;
  final int budgetOverrunsCount;
  final double savingsRate;
  final int activeGoalsCount;
  final int expenseStreak;
  final int unlockedBadgesCount;

  InsightsQuickStats({
    required this.healthScore,
    required this.healthCategory,
    required this.topSpendCategory,
    required this.lifestylePersona,
    required this.aiAlertsCount,
    required this.nextMonthForecast,
    required this.recommendationCount,
    required this.riskAlertsCount,
    required this.subscriptionCount,
    required this.budgetOverrunsCount,
    required this.savingsRate,
    required this.activeGoalsCount,
    required this.expenseStreak,
    required this.unlockedBadgesCount,
  });
}

class LocalGoalsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final list = LocalCacheService.getCachedList('local_goals_${user.id}');
      return List<Map<String, dynamic>>.from(list);
    }
    return [];
  }

  void loadGoals() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final list = LocalCacheService.getCachedList('local_goals_${user.id}');
      state = List<Map<String, dynamic>>.from(list);
    }
  }

  Future<void> addGoal(String name, double target, double current) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final newGoal = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'targetAmount': target,
      'currentAmount': current,
    };
    state = [...state, newGoal];
    await LocalCacheService.cacheData('local_goals_${user.id}', state);
  }

  Future<void> updateGoalProgress(String id, double progress) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    state = state.map((g) {
      if (g['id'] == id) {
        return {...g, 'currentAmount': progress};
      }
      return g;
    }).toList();
    await LocalCacheService.cacheData('local_goals_${user.id}', state);
  }

  Future<void> deleteGoal(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    state = state.where((g) => g['id'] != id).toList();
    await LocalCacheService.cacheData('local_goals_${user.id}', state);
  }
}

final localGoalsProvider = NotifierProvider<LocalGoalsNotifier, List<Map<String, dynamic>>>(() {
  return LocalGoalsNotifier();
});

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String _selectedCategory = 'Core';

  double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  InsightsQuickStats _computeQuickStats(
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> incomes,
    List<Map<String, dynamic>> budgets,
    List<Map<String, dynamic>> goals,
  ) {
    final now = DateTime.now();

    // 1. Health Score
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

    final totalIncome = incomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final totalExpense = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final reserves = totalIncome - totalExpense;

    final double savingsRate = monthlyIncome > 0 ? (monthlyIncome - monthlyExpense) / monthlyIncome : 0;
    final int savingsScore = (savingsRate.clamp(0.0, 1.0) * 40).round();

    final categoryExpenses = <String, double>{};
    for (final e in monthlyExpensesList) {
      final cat = e['category']?.toString().toLowerCase() ?? 'other';
      categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
    }
    int overruns = 0;
    int budgetCount = 0;
    for (final b in budgets) {
      final cat = b['category']?.toString().toLowerCase() ?? '';
      final limit = _parseAmount(b['amount']);
      if (cat.isNotEmpty && limit > 0) {
        budgetCount++;
        final spent = categoryExpenses[cat] ?? 0.0;
        if (spent > limit) overruns++;
      }
    }
    int budgetScore = 30;
    if (budgetCount > 0) {
      final overrunRatio = overruns / budgetCount;
      budgetScore = (30 * (1.0 - overrunRatio)).round();
    }

    final avgMonthlyExpense = monthlyExpense > 0 ? monthlyExpense : 15000.0;
    final runwayMonths = avgMonthlyExpense > 0 ? reserves / avgMonthlyExpense : 0.0;
    int runwayScore = 0;
    if (runwayMonths >= 6) {
      runwayScore = 30;
    } else if (runwayMonths >= 3) {
      runwayScore = 20;
    } else if (runwayMonths >= 1) {
      runwayScore = 10;
    } else {
      runwayScore = 5;
    }

    final score = (savingsScore + budgetScore + runwayScore).clamp(10, 100);
    String healthCategory = 'AVERAGE';
    if (score >= 80) healthCategory = 'EXCELLENT';
    else if (score >= 60) healthCategory = 'GOOD';
    else if (score < 40) healthCategory = 'CRITICAL';

    // 2. Pattern Top Spend Category
    final allCategoryExpenses = <String, double>{};
    for (final e in expenses) {
      final amt = _parseAmount(e['amount']);
      final cat = (e['category']?.toString() ?? 'other').toLowerCase();
      allCategoryExpenses[cat] = (allCategoryExpenses[cat] ?? 0.0) + amt;
    }
    String highestCat = '';
    double maxCatAmt = 0;
    for (final entry in allCategoryExpenses.entries) {
      if (entry.value > maxCatAmt) {
        maxCatAmt = entry.value;
        highestCat = entry.key;
      }
    }
    String topSpendCategory = 'None';
    if (highestCat.isNotEmpty) {
      topSpendCategory = highestCat.substring(0, 1).toUpperCase() + highestCat.substring(1).toLowerCase();
    }

    // 3. Lifestyle Persona
    String persona = "Saver";
    if (totalExpense > 0 && highestCat.isNotEmpty) {
      if (highestCat.contains('food') || highestCat.contains('dine')) {
        persona = "Gourmet";
      } else if (highestCat.contains('shopping')) {
        persona = "Consumer";
      } else if (highestCat.contains('entertainment') || highestCat.contains('film') || highestCat.contains('movie')) {
        persona = "Trendsetter";
      } else if (highestCat.contains('transport') || highestCat.contains('travel') || highestCat.contains('car')) {
        persona = "Jetsetter";
      } else {
        persona = "Pragmatic";
      }
    }

    // 4. AI Alerts Count
    int aiAlertsCount = 0;
    final sorted = List<Map<String, dynamic>>.from(expenses)
      ..sort((a, b) {
        final da = DateTime.tryParse(a['expense_date']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['expense_date']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(2000);
        return da.compareTo(db);
      });
    for (int i = 0; i < sorted.length - 1; i++) {
      final current = sorted[i];
      final amt = _parseAmount(current['amount']);
      final desc = MultiCurrencyData.cleanDescription(current['description']?.toString() ?? '').toLowerCase().trim();
      final date = DateTime.tryParse(current['expense_date']?.toString() ?? current['created_at']?.toString() ?? '') ?? DateTime(2000);
      if (desc.isEmpty || amt == 0) continue;
      for (int j = i + 1; j < sorted.length; j++) {
        final next = sorted[j];
        final nextAmt = _parseAmount(next['amount']);
        final nextDesc = MultiCurrencyData.cleanDescription(next['description']?.toString() ?? '').toLowerCase().trim();
        final nextDate = DateTime.tryParse(next['expense_date']?.toString() ?? next['created_at']?.toString() ?? '') ?? DateTime(2000);
        if (nextDate.difference(date).inDays > 3) break;
        if (desc == nextDesc && amt == nextAmt) {
          aiAlertsCount++;
          break;
        }
      }
    }
    for (final e in monthlyExpensesList) {
      final amt = _parseAmount(e['amount']);
      if (amt >= 10000.0) {
        aiAlertsCount++;
      }
    }

    // 5. Prediction Forecast
    final expenseMonths = <String, double>{};
    for (final e in expenses) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      if (d != null) {
        final key = '${d.year}-${d.month}';
        expenseMonths[key] = (expenseMonths[key] ?? 0.0) + _parseAmount(e['amount']);
      }
    }
    final incomeMonths = <String, double>{};
    for (final e in incomes) {
      final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      if (d != null) {
        final key = '${d.year}-${d.month}';
        incomeMonths[key] = (incomeMonths[key] ?? 0.0) + _parseAmount(e['amount']);
      }
    }
    double avgIncome = incomeMonths.values.isNotEmpty
        ? (incomeMonths.values.reduce((a, b) => a + b) / incomeMonths.length)
        : 0.0;
    double avgExpense = expenseMonths.values.isNotEmpty
        ? (expenseMonths.values.reduce((a, b) => a + b) / expenseMonths.length)
        : 0.0;
    if (avgIncome == 0.0) avgIncome = monthlyIncome;
    if (avgExpense == 0.0) avgExpense = monthlyExpense;
    final double predictedSavings = avgIncome - avgExpense;

    // 6. Recommendation Count
    int recommendationCount = 0;
    if (reserves > 15000) recommendationCount++;
    if (overruns > 0) recommendationCount++;
    if (_detectSubscriptions(expenses).length > 2) recommendationCount++;
    if (recommendationCount == 0) recommendationCount = 1;

    // 7. Risk Alerts Count
    int riskAlertsCount = 0;
    if (monthlyIncome > 0 && (monthlyExpense / monthlyIncome) > 0.8) riskAlertsCount++;
    riskAlertsCount += overruns;
    for (final e in monthlyExpensesList) {
      if (_parseAmount(e['amount']) >= 10000.0) {
        riskAlertsCount++;
        break;
      }
    }

    // 8. Subscriptions
    final subscriptionCount = _detectSubscriptions(expenses).length;

    // 9. Streak & Badges
    final expenseDates = expenses.map((e) {
      final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
      return d != null ? DateTime(d.year, d.month, d.day) : null;
    }).whereType<DateTime>().toSet();
    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final testDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      if (!expenseDates.contains(testDate)) {
        streak++;
      } else {
        if (i > 0) break;
      }
    }
    int unlockedBadges = 0;
    if (streak >= 5) unlockedBadges++;
    if (savingsRate >= 0.3) unlockedBadges++;
    if (budgets.isNotEmpty && overruns == 0) unlockedBadges++;

    return InsightsQuickStats(
      healthScore: score,
      healthCategory: healthCategory,
      topSpendCategory: topSpendCategory,
      lifestylePersona: persona,
      aiAlertsCount: aiAlertsCount,
      nextMonthForecast: predictedSavings,
      recommendationCount: recommendationCount,
      riskAlertsCount: riskAlertsCount,
      subscriptionCount: subscriptionCount,
      budgetOverrunsCount: overruns,
      savingsRate: savingsRate,
      activeGoalsCount: goals.length,
      expenseStreak: streak,
      unlockedBadgesCount: unlockedBadges,
    );
  }

  String _getAITip(InsightsQuickStats stats) {
    if (stats.riskAlertsCount > 0) {
      return "⚠️ Action needed: You have ${stats.riskAlertsCount} active risk warnings. Tap Risk Alerts below.";
    }
    if (stats.budgetOverrunsCount > 0) {
      return "🎯 Target: Trim spending on category budgets that exceeded limits.";
    }
    if (stats.subscriptionCount > 2) {
      return "💡 Smart choice: Review subscriptions to free up extra cash reserves.";
    }
    if (stats.savingsRate < 0.20 && stats.savingsRate > 0) {
      return "📈 Tip: Try reducing dining/shopping by 10% to hit 20% savings rate.";
    }
    return "✨ Balance secure. Your allocations are aligned with standard financial goals.";
  }

  Widget _buildHeroHealthCard(InsightsQuickStats stats) {
    Color healthColor = AppColors.accentAmber;
    if (stats.healthScore >= 80) healthColor = AppColors.accentEmerald;
    else if (stats.healthScore >= 60) healthColor = AppColors.accentCyan;
    else if (stats.healthScore < 40) healthColor = AppColors.accentRose;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              AppColors.bgElevated,
              AppColors.bgSecondary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: healthColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: healthColor.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        value: stats.healthScore / 100.0,
                        strokeWidth: 8,
                        backgroundColor: AppColors.bgPrimary,
                        color: healthColor,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${stats.healthScore}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: healthColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              stats.healthCategory,
                              style: TextStyle(
                                color: healthColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Health Index',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Financial Brain Analysis',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stats.savingsRate >= 0.2
                            ? 'Your savings rate is highly secure.'
                            : 'Savings could be optimized.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  color: AppColors.accentCyan,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getAITip(stats),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      {'id': 'Core', 'label': 'Core'},
      {'id': 'AI', 'label': 'AI & Forecast'},
      {'id': 'Wealth', 'label': 'Wealth Tracking'},
      {'id': 'Journey', 'label': 'Milestones'},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = cat['id']!;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentCyan.withOpacity(0.12) : AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.accentCyan.withOpacity(0.3) : AppColors.border,
                  width: 1,
                ),
              ),
              child: Text(
                cat['label']!,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionsGrid(BuildContext context, InsightsQuickStats stats) {
    final prefs = ref.watch(preferencesProvider);
    final code = supportedCurrencies[prefs.currencyIndex].code;
    final notifier = ref.read(preferencesProvider.notifier);
    final displayAmt = notifier.convertFromBaseline(stats.nextMonthForecast);
    final formattedForecast = '${stats.nextMonthForecast >= 0 ? '+' : ''}${CurrencyFormatter.format(displayAmt, code)}';

    final List<_DashboardItem> allItems = [
      _DashboardItem(
        title: 'Health Score',
        subtitle: 'Overall wellness index',
        icon: LucideIcons.heartPulse,
        color: AppColors.accentEmerald,
        stat: '${stats.healthScore}/100',
        builder: _buildHealthScoreModal,
      ),
      _DashboardItem(
        title: 'Spend Pattern',
        subtitle: 'Spending distribution',
        icon: LucideIcons.pieChart,
        color: AppColors.accentCyan,
        stat: stats.topSpendCategory,
        builder: _buildPatternModal,
      ),
      _DashboardItem(
        title: 'Spend Heatmap',
        subtitle: 'Intensity & activity',
        icon: LucideIcons.map,
        color: AppColors.accentRose,
        stat: '30-Day View',
        builder: _buildHeatmapModal,
      ),
      _DashboardItem(
        title: 'Lifestyle Persona',
        subtitle: 'Spending archetypes',
        icon: LucideIcons.coffee,
        color: AppColors.accentAmber,
        stat: stats.lifestylePersona,
        builder: _buildLifestyleModal,
      ),
      _DashboardItem(
        title: 'AI Insights',
        subtitle: 'Anomalies & spikes',
        icon: LucideIcons.brain,
        color: AppColors.accentPurple,
        stat: stats.aiAlertsCount == 0 ? 'Optimal' : '${stats.aiAlertsCount} Flagged',
        builder: _buildAIInsightsModal,
      ),
      _DashboardItem(
        title: 'Prediction Engine',
        subtitle: 'Monthly forecasts',
        icon: LucideIcons.trendingUp,
        color: AppColors.accentCyan,
        stat: formattedForecast,
        builder: _buildPredictionModal,
      ),
      _DashboardItem(
        title: 'Smart Advice',
        subtitle: 'Actionable tips',
        icon: LucideIcons.lightbulb,
        color: AppColors.accentAmber,
        stat: '${stats.recommendationCount} Tips',
        builder: _buildRecommendationsModal,
      ),
      _DashboardItem(
        title: 'Risk Alerts',
        subtitle: 'Safety protocols',
        icon: LucideIcons.alertTriangle,
        color: AppColors.accentRose,
        stat: stats.riskAlertsCount == 0 ? 'Secure' : '${stats.riskAlertsCount} Warnings',
        builder: _buildRiskAlertsModal,
      ),
      _DashboardItem(
        title: 'Subscriptions',
        subtitle: 'Recurring charges',
        icon: LucideIcons.refreshCcw,
        color: AppColors.accentCyan,
        stat: '${stats.subscriptionCount} Active',
        builder: _buildSubscriptionModal,
      ),
      _DashboardItem(
        title: 'Budget IQ',
        subtitle: 'Limits vs actuals',
        icon: LucideIcons.target,
        color: AppColors.accentEmerald,
        stat: stats.budgetOverrunsCount == 0 ? 'On Track' : '${stats.budgetOverrunsCount} Overruns',
        builder: _buildBudgetModal,
      ),
      _DashboardItem(
        title: 'Savings IQ',
        subtitle: 'Optimizing reserves',
        icon: LucideIcons.piggyBank,
        color: AppColors.accentPurple,
        stat: '${(stats.savingsRate * 100).toStringAsFixed(0)}% Rate',
        builder: _buildSavingsModal,
      ),
      _DashboardItem(
        title: 'Goal Trajectory',
        subtitle: 'Major milestone paths',
        icon: LucideIcons.flag,
        color: AppColors.accentAmber,
        stat: '${stats.activeGoalsCount} Goals',
        builder: _buildGoalsModal,
      ),
      _DashboardItem(
        title: 'Financial Story',
        subtitle: 'Monthly summaries',
        icon: LucideIcons.bookOpen,
        color: AppColors.accentCyan,
        stat: 'View Recap',
        builder: _buildStoryModal,
      ),
      _DashboardItem(
        title: 'Badges & Streaks',
        subtitle: 'Achievements earned',
        icon: LucideIcons.award,
        color: AppColors.accentEmerald,
        stat: '${stats.expenseStreak}d Streak',
        builder: _buildAchievementsModal,
      ),
    ];

    final List<_DashboardItem> filtered;
    if (_selectedCategory == 'Core') {
      filtered = allItems.sublist(0, 4);
    } else if (_selectedCategory == 'AI') {
      filtered = allItems.sublist(4, 8);
    } else if (_selectedCategory == 'Wealth') {
      filtered = allItems.sublist(8, 12);
    } else {
      filtered = allItems.sublist(12, 14);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildDashboardCard(context, item);
        },
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, _DashboardItem item) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Consumer(
            builder: (context, ref, _) {
              return _buildModalWrapper(context, item.title, item.builder(context, ref));
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgElevated.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 18),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.stat,
                        style: TextStyle(
                          color: item.color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 40,
              child: Text(
                item.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 32,
              child: Text(
                item.subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INTELLIGENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentCyan, letterSpacing: 2)),
          SizedBox(height: 2),
          Text('Financial Brain', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          SizedBox(height: 6),
          Text(
            'Tap on any intelligence module below to run analysis and view detailed interactive reports.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildModalWrapper(BuildContext context, String title, Widget child) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(LucideIcons.x, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Divider(color: AppColors.borderSubtle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _withData(
    WidgetRef ref,
    Widget Function(
      List<Map<String, dynamic>> expenses,
      List<Map<String, dynamic>> incomes,
      List<Map<String, dynamic>> budgets,
    ) builder,
  ) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final incomesAsync = ref.watch(incomeStreamProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);

    if (expensesAsync.isLoading || incomesAsync.isLoading || budgetsAsync.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
      );
    }

    if (expensesAsync.hasError || incomesAsync.hasError || budgetsAsync.hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text(
            'Error loading insights data',
            style: TextStyle(color: AppColors.accentRose, fontSize: 14),
          ),
        ),
      );
    }

    final expenses = expensesAsync.value ?? [];
    final incomes = incomesAsync.value ?? [];
    final budgets = budgetsAsync.value ?? [];

    return builder(expenses, incomes, budgets);
  }

  @override
  Widget build(BuildContext context) {
    Future<void> handleRefresh() async {
      ref.invalidate(expensesStreamProvider);
      ref.invalidate(incomeStreamProvider);
      ref.invalidate(budgetsStreamProvider);
      ref.read(localGoalsProvider.notifier).loadGoals();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final goals = ref.watch(localGoalsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentCyan,
          backgroundColor: AppColors.bgElevated,
          onRefresh: handleRefresh,
          child: _withData(ref, (expenses, incomes, budgets) {
            final stats = _computeQuickStats(expenses, incomes, budgets, goals);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(child: const SizedBox(height: 8)),
                SliverToBoxAdapter(child: _buildHeroHealthCard(stats)),
                SliverToBoxAdapter(child: const SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildCategorySelector()),
                SliverToBoxAdapter(child: const SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildOptionsGrid(context, stats)),
                SliverToBoxAdapter(child: const SizedBox(height: 32)),
              ],
            );
          }),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }


  // --- Modal Builders ---

  Widget _buildHealthScoreModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final now = DateTime.now();

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

      final totalIncome = incomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      final totalExpense = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      final reserves = totalIncome - totalExpense;

      final double savingsRate = monthlyIncome > 0 ? (monthlyIncome - monthlyExpense) / monthlyIncome : 0;
      final int savingsScore = (savingsRate.clamp(0.0, 1.0) * 40).round();

      final categoryExpenses = <String, double>{};
      for (final e in monthlyExpensesList) {
        final cat = e['category']?.toString().toLowerCase() ?? 'other';
        categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
      }
      int overruns = 0;
      int budgetCount = 0;
      for (final b in budgets) {
        final cat = b['category']?.toString().toLowerCase() ?? '';
        final limit = _parseAmount(b['amount']);
        if (cat.isNotEmpty && limit > 0) {
          budgetCount++;
          final spent = categoryExpenses[cat] ?? 0.0;
          if (spent > limit) overruns++;
        }
      }
      int budgetScore = 30;
      if (budgetCount > 0) {
        final overrunRatio = overruns / budgetCount;
        budgetScore = (30 * (1.0 - overrunRatio)).round();
      }

      final avgMonthlyExpense = monthlyExpense > 0 ? monthlyExpense : 15000.0;
      final runwayMonths = avgMonthlyExpense > 0 ? reserves / avgMonthlyExpense : 0.0;
      int runwayScore = 0;
      if (runwayMonths >= 6) {
        runwayScore = 30;
      } else if (runwayMonths >= 3) {
        runwayScore = 20;
      } else if (runwayMonths >= 1) {
        runwayScore = 10;
      } else {
        runwayScore = 5;
      }

      final score = (savingsScore + budgetScore + runwayScore).clamp(10, 100);

      String category = 'AVERAGE';
      Color color = AppColors.accentAmber;
      if (score >= 80) {
        category = 'EXCELLENT';
        color = AppColors.accentEmerald;
      } else if (score >= 60) {
        category = 'GOOD';
        color = AppColors.accentCyan;
      } else if (score < 40) {
        category = 'CRITICAL';
        color = AppColors.accentRose;
      }

      final savingsPercentStr = '${(savingsRate * 100).toStringAsFixed(0)}%';

      return Column(
        children: [
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 10,
                      color: color,
                      backgroundColor: color.withOpacity(0.1),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          color: color,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildDetailRow('Monthly Savings Rate', '$savingsPercentStr (${savingsRate >= 0.2 ? "Healthy" : "Needs Improvement"})', LucideIcons.piggyBank, color),
          const SizedBox(height: 16),
          _buildDetailRow('Budget Overruns', overruns == 0 ? '0 Categories Exceeded' : '$overruns Category Overrun(s)', LucideIcons.target, overruns == 0 ? AppColors.accentEmerald : AppColors.accentRose),
          const SizedBox(height: 16),
          _buildDetailRow('Emergency Fund Runway', runwayMonths >= 3.0 ? 'Runway Secure (${runwayMonths.toStringAsFixed(1)}m)' : 'Action Needed (${runwayMonths.toStringAsFixed(1)}m)', LucideIcons.shieldCheck, runwayMonths >= 3.0 ? AppColors.accentEmerald : AppColors.accentAmber),
        ],
      );
    });
  }

  Widget _buildPatternModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      final categoryExpenses = <String, double>{};
      double weekendExpenses = 0;

      for (final e in expenses) {
        final amt = _parseAmount(e['amount']);
        final cat = e['category']?.toString() ?? 'Other';
        final key = cat.substring(0, 1).toUpperCase() + cat.substring(1).toLowerCase();
        categoryExpenses[key] = (categoryExpenses[key] ?? 0.0) + amt;

        final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
        final d = DateTime.tryParse(dateStr);
        if (d != null && (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday)) {
          weekendExpenses += amt;
        }
      }

      final weekendPercent = totalExpenses > 0 ? (weekendExpenses / totalExpenses * 100) : 0.0;
      final sortedCategories = categoryExpenses.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      String behaviorText = "Your spending is balanced between weekdays and weekends.";
      if (weekendPercent > 50.0) {
        behaviorText = "Your spending is heavily skewed towards weekends (${weekendPercent.toStringAsFixed(0)}% of total).";
      } else if (weekendPercent < 15.0 && totalExpenses > 0) {
        behaviorText = "Your spending occurs mostly during weekdays (${(100 - weekendPercent).toStringAsFixed(0)}% of total).";
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(behaviorText, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          if (sortedCategories.isEmpty)
            const Text('No expense transactions recorded yet.', style: TextStyle(color: AppColors.textSecondary))
          else
            ...sortedCategories.map((entry) {
              final pct = totalExpenses > 0 ? (entry.value / totalExpenses * 100) : 0.0;
              IconData icon = LucideIcons.shoppingBag;
              Color color = AppColors.accentCyan;

              final lowerCat = entry.key.toLowerCase();
              if (lowerCat.contains('food') || lowerCat.contains('dine')) {
                icon = LucideIcons.pizza;
                color = AppColors.accentRose;
              } else if (lowerCat.contains('transport') || lowerCat.contains('travel') || lowerCat.contains('car')) {
                icon = LucideIcons.car;
                color = AppColors.accentCyan;
              } else if (lowerCat.contains('entertainment') || lowerCat.contains('film') || lowerCat.contains('movie')) {
                icon = LucideIcons.film;
                color = AppColors.accentPurple;
              } else if (lowerCat.contains('bill') || lowerCat.contains('rent') || lowerCat.contains('utility')) {
                icon = LucideIcons.receipt;
                color = AppColors.accentAmber;
              } else if (lowerCat.contains('shopping')) {
                icon = LucideIcons.shoppingCart;
                color = AppColors.accentCyan;
              }

              final prefs = ref.watch(preferencesProvider);
              final code = supportedCurrencies[prefs.currencyIndex].code;
              final notifier = ref.read(preferencesProvider.notifier);
              final convertedVal = notifier.convertFromBaseline(entry.value);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildDetailRow(
                  entry.key,
                  '${CurrencyFormatter.format(convertedVal, code)} (${pct.toStringAsFixed(0)}%)',
                  icon,
                  color,
                ),
              );
            }),
        ],
      );
    });
  }

  Widget _buildHeatmapModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final now = DateTime.now();
      final todayDateOnly = DateTime(now.year, now.month, now.day);
      final daySpending = List<double>.filled(30, 0.0);
      final dayDates = List<DateTime>.generate(30, (i) => todayDateOnly.subtract(Duration(days: 29 - i)));
      final dayExpenses = List<List<Map<String, dynamic>>>.generate(30, (_) => []);

      int activeDays = 0;
      double totalPeriodSpend = 0.0;
      double maxDaySpend = 0.0;
      DateTime? maxSpendDay;

      for (final e in expenses) {
        final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
        final d = DateTime.tryParse(dateStr);
        if (d != null) {
          final expenseDateOnly = DateTime(d.year, d.month, d.day);
          final diff = todayDateOnly.difference(expenseDateOnly).inDays;
          if (diff >= 0 && diff < 30) {
            daySpending[29 - diff] += _parseAmount(e['amount']);
            dayExpenses[29 - diff].add(e);
          }
        }
      }

      for (int i = 0; i < 30; i++) {
        final amt = daySpending[i];
        totalPeriodSpend += amt;
        if (amt > 0) {
          activeDays++;
        }
        if (amt > maxDaySpend) {
          maxDaySpend = amt;
          maxSpendDay = dayDates[i];
        }
      }
      final double avgDailySpend = totalPeriodSpend / 30.0;
      final double maxSpent = maxDaySpend;

      int selectedIndex = 29;

      return StatefulBuilder(
        builder: (context, setState) {
          final selectedDate = dayDates[selectedIndex];
          final selectedSpent = daySpending[selectedIndex];
          final selectedList = dayExpenses[selectedIndex];
          final formattedDate = DateFormat('EEEE, MMMM dd').format(selectedDate);
          final peakDayStr = maxSpendDay != null ? DateFormat('MMM dd').format(maxSpendDay) : 'N/A';

          final prefs = ref.watch(preferencesProvider);
          final code = supportedCurrencies[prefs.currencyIndex].code;
          final notifier = ref.read(preferencesProvider.notifier);

          final displayTotal = CurrencyFormatter.format(notifier.convertFromBaseline(totalPeriodSpend), code);
          final displayAvg = CurrencyFormatter.format(notifier.convertFromBaseline(avgDailySpend), code);
          final displayPeak = CurrencyFormatter.format(notifier.convertFromBaseline(maxDaySpend), code);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Metrics Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '30-DAY INTENSITY SUMMARY',
                      style: TextStyle(
                        color: AppColors.accentRose,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Spent', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(displayTotal, style: AppTheme.moneyStyle.copyWith(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Daily Average', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(displayAvg, style: AppTheme.moneyStyle.copyWith(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.borderSubtle, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Peak Day Spend', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text('$displayPeak ($peakDayStr)', style: AppTheme.moneyStyle.copyWith(color: AppColors.accentRose, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Active Spend Days', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text('$activeDays / 30 days', style: const TextStyle(color: AppColors.accentCyan, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Intensity of spending over the last 30 days. Tap any square to view details below.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              
              // Heatmap Responsive Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemCount: 30,
                itemBuilder: (context, index) {
                  final spent = daySpending[index];
                  final ratio = maxSpent > 0 ? (spent / maxSpent) : 0.0;
                  final isSelected = index == selectedIndex;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedIndex = index;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentRose.withOpacity(0.9)
                            : AppColors.accentRose.withOpacity(ratio == 0 ? 0.05 : 0.1 + (ratio * 0.7)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.textPrimary
                              : (ratio > 0 ? AppColors.accentRose.withOpacity(0.4) : AppColors.borderSubtle),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.accentRose.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${dayDates[index].day}',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : (ratio > 0 ? AppColors.textPrimary : AppColors.textSecondary.withOpacity(0.8)),
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Less',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    ...List.generate(5, (i) {
                      final opacity = 0.05 + (i * 0.22);
                      return Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentRose.withOpacity(opacity),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: AppColors.accentRose.withOpacity(0.15),
                            width: 0.5,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 6),
                    const Text(
                      'More',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedList.isEmpty
                              ? 'No transactions'
                              : '${selectedList.length} transaction(s)',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(notifier.convertFromBaseline(selectedSpent), code),
                    style: AppTheme.moneyStyle.copyWith(
                      color: selectedSpent > 0 ? AppColors.accentRose : AppColors.textSecondary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (selectedList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Column(
                    children: [
                      Icon(LucideIcons.smile, color: AppColors.textSecondary, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'No money spent on this day!',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedList.length,
                  itemBuilder: (context, idx) {
                    final item = selectedList[idx];
                    final amt = _parseAmount(item['amount']);
                    final rawDesc = item['description'] ?? 'Expense';
                    final cleanGroup = rawDesc.toString().replaceFirst(RegExp(r'^\[GroupExpense:[^\]]+\]\s*'), '').trim();
                    final desc = MultiCurrencyData.cleanDescription(cleanGroup);
                    final category = item['category'] ?? 'Other';
                    
                    IconData icon = LucideIcons.shoppingBag;
                    Color color = AppColors.accentCyan;
                    final lowerCat = category.toString().toLowerCase();
                    if (lowerCat.contains('food') || lowerCat.contains('dine')) {
                      icon = LucideIcons.pizza;
                      color = AppColors.accentRose;
                    } else if (lowerCat.contains('transport') || lowerCat.contains('travel') || lowerCat.contains('car')) {
                      icon = LucideIcons.car;
                      color = AppColors.accentCyan;
                    } else if (lowerCat.contains('entertainment') || lowerCat.contains('film') || lowerCat.contains('movie')) {
                      icon = LucideIcons.film;
                      color = AppColors.accentPurple;
                    } else if (lowerCat.contains('bill') || lowerCat.contains('rent') || lowerCat.contains('utility')) {
                      icon = LucideIcons.receipt;
                      color = AppColors.accentAmber;
                    } else if (lowerCat.contains('shopping')) {
                      icon = LucideIcons.shoppingCart;
                      color = AppColors.accentCyan;
                    }

                    final itemMc = MultiCurrencyData.parse(rawDesc.toString());
                    String formattedAmount = '';
                    String sublabel = '';

                    if (itemMc != null) {
                      formattedAmount = '-${CurrencyFormatter.format(itemMc.amount, itemMc.currency)}';
                      if (code != itemMc.currency) {
                        final preferredVal = notifier.convertFromBaseline(amt);
                        sublabel = '≈ -${CurrencyFormatter.format(preferredVal, code)}';
                      }
                    } else {
                      final converted = notifier.convertFromBaseline(amt);
                      formattedAmount = '-${CurrencyFormatter.format(converted, code)}';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  category,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formattedAmount,
                                style: AppTheme.moneyStyle.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (sublabel.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  sublabel,
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      );
    });
  }

  Widget _buildLifestyleModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final categoryExpenses = <String, double>{};
      double totalExpenses = 0.0;

      for (final e in expenses) {
        final amt = _parseAmount(e['amount']);
        totalExpenses += amt;
        final cat = (e['category']?.toString() ?? 'other').toLowerCase();
        categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + amt;
      }

      String highestCat = '';
      double maxSpent = 0.0;
      for (final entry in categoryExpenses.entries) {
        if (entry.value > maxSpent) {
          maxSpent = entry.value;
          highestCat = entry.key;
        }
      }

      String persona = "The Mindful Saver";
      String description = "You maintain low spending and track expenses with high discipline. Keep up the secure reserves!";
      IconData icon = LucideIcons.piggyBank;
      Color color = AppColors.accentEmerald;

      if (totalExpenses > 0) {
        final pct = (maxSpent / totalExpenses * 100).toStringAsFixed(0);
        if (highestCat.contains('food') || highestCat.contains('dine')) {
          persona = "The Gourmet Connoisseur";
          description = "Food & dining out represents $pct% of your total spend. Cooking at home a couple more times a week could yield massive savings.";
          icon = LucideIcons.pizza;
          color = AppColors.accentRose;
        } else if (highestCat.contains('shopping')) {
          persona = "The Premium Consumer";
          description = "Shopping accounts for $pct% of your outlay. Introducing a 48-hour cooling-off period for online purchases will lock down impulse costs.";
          icon = LucideIcons.shoppingBag;
          color = AppColors.accentAmber;
        } else if (highestCat.contains('entertainment') || highestCat.contains('film') || highestCat.contains('movie')) {
          persona = "The Trendsetter";
          description = "Entertainment accounts for $pct% of your cash outflow. Auditing subscription counts or comparing local activity spends will benefit your monthly buffer.";
          icon = LucideIcons.film;
          color = AppColors.accentPurple;
        } else if (highestCat.contains('transport') || highestCat.contains('travel') || highestCat.contains('car')) {
          persona = "The Jetsetter";
          description = "Commuting and traveling constitutes $pct% of your expenses. Evaluating subscription passes or ride-sharing structures could streamline transportation costs.";
          icon = LucideIcons.car;
          color = AppColors.accentCyan;
        } else {
          persona = "The Pragmatic Household";
          description = "Your primary spending goes to essential categories and utility invoices ($pct%). Your allocation follows standard budget priorities.";
          icon = LucideIcons.home;
          color = AppColors.accentCyan;
        }
      }

      return Column(
        children: [
          Icon(icon, color: color, size: 64),
          const SizedBox(height: 16),
          Text(persona, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
        ],
      );
    });
  }

  Widget _buildAIInsightsModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final insights = <Widget>[];

      final sorted = List<Map<String, dynamic>>.from(expenses)
        ..sort((a, b) {
          final da = DateTime.tryParse(a['expense_date']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(2000);
          final db = DateTime.tryParse(b['expense_date']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(2000);
          return da.compareTo(db);
        });

      final prefs = ref.watch(preferencesProvider);
      final code = supportedCurrencies[prefs.currencyIndex].code;
      final notifier = ref.read(preferencesProvider.notifier);

      for (int i = 0; i < sorted.length - 1; i++) {
        final current = sorted[i];
        final amt = _parseAmount(current['amount']);
        final desc = MultiCurrencyData.cleanDescription(current['description']?.toString() ?? '').toLowerCase().trim();
        final date = DateTime.tryParse(current['expense_date']?.toString() ?? current['created_at']?.toString() ?? '') ?? DateTime(2000);

        if (desc.isEmpty || amt == 0) continue;

        for (int j = i + 1; j < sorted.length; j++) {
          final next = sorted[j];
          final nextAmt = _parseAmount(next['amount']);
          final nextDesc = MultiCurrencyData.cleanDescription(next['description']?.toString() ?? '').toLowerCase().trim();
          final nextDate = DateTime.tryParse(next['expense_date']?.toString() ?? next['created_at']?.toString() ?? '') ?? DateTime(2000);

          if (nextDate.difference(date).inDays > 3) break;

          if (desc == nextDesc && amt == nextAmt) {
            final displayAmt = CurrencyFormatter.format(notifier.convertFromBaseline(amt), code);
            insights.add(_buildInsightCard(
              'Duplicate Charge Detected',
              'You paid $displayAmt for "${MultiCurrencyData.cleanDescription(current['description'] ?? '')}" twice within 3 days. Check if this is an error.',
              LucideIcons.copy,
              AppColors.accentRose,
            ));
            insights.add(const SizedBox(height: 16));
            break;
          }
        }
      }

      final now = DateTime.now();
      final currentMonthExpenses = expenses.where((e) {
        final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final totalMonthlyExpense = currentMonthExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

      final currentMonthIncomes = incomes.where((e) {
        final d = DateTime.tryParse(e['income_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final totalMonthlyIncome = currentMonthIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

      if (totalMonthlyIncome > 0 && (totalMonthlyExpense / totalMonthlyIncome) > 0.8) {
        final burnPct = (totalMonthlyExpense / totalMonthlyIncome * 100).toStringAsFixed(0);
        insights.add(_buildInsightCard(
          'Optimized Cashflow Alert',
          'You have consumed $burnPct% of this month\'s income. Delay discretionary shopping until next month to keep a positive buffer.',
          LucideIcons.trendingDown,
          AppColors.accentCyan,
        ));
        insights.add(const SizedBox(height: 16));
      }

      final totalExpensesAllTime = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      final avgExpense = expenses.isNotEmpty ? (totalExpensesAllTime / expenses.length) : 0.0;
      for (final e in currentMonthExpenses) {
        final amt = _parseAmount(e['amount']);
        if (amt > 3 * avgExpense && amt > 3000) {
          final displayAmt = CurrencyFormatter.format(notifier.convertFromBaseline(amt), code);
          final displayAvg = CurrencyFormatter.format(notifier.convertFromBaseline(avgExpense), code);
          insights.add(_buildInsightCard(
            'Large Single Outflow',
            'Your purchase of "${MultiCurrencyData.cleanDescription(e['description'] ?? '')}" for $displayAmt is significantly larger than your average transaction of $displayAvg.',
            LucideIcons.zap,
            AppColors.accentAmber,
          ));
          insights.add(const SizedBox(height: 16));
          break;
        }
      }

      if (insights.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(LucideIcons.checkCircle2, color: AppColors.accentEmerald, size: 48),
                SizedBox(height: 16),
                Text('All Clean!', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('No unusual spikes or duplicate transactions detected.', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }

      if (insights.isNotEmpty && insights.last is SizedBox) {
        insights.removeLast();
      }

      return Column(children: insights);
    });
  }

  Widget _buildPredictionModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final now = DateTime.now();

      final expenseMonths = <String, double>{};
      for (final e in expenses) {
        final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
        final d = DateTime.tryParse(dateStr);
        if (d != null) {
          final key = '${d.year}-${d.month}';
          expenseMonths[key] = (expenseMonths[key] ?? 0.0) + _parseAmount(e['amount']);
        }
      }
      final incomeMonths = <String, double>{};
      for (final e in incomes) {
        final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
        final d = DateTime.tryParse(dateStr);
        if (d != null) {
          final key = '${d.year}-${d.month}';
          incomeMonths[key] = (incomeMonths[key] ?? 0.0) + _parseAmount(e['amount']);
        }
      }

      double avgIncome = incomeMonths.values.isNotEmpty
          ? (incomeMonths.values.reduce((a, b) => a + b) / incomeMonths.length)
          : 0.0;
      double avgExpense = expenseMonths.values.isNotEmpty
          ? (expenseMonths.values.reduce((a, b) => a + b) / expenseMonths.length)
          : 0.0;

      if (avgIncome == 0.0) {
        final monthlyIncomes = incomes.where((e) {
          final d = DateTime.tryParse(e['income_date']?.toString() ?? e['created_at']?.toString() ?? '');
          return d != null && d.year == now.year && d.month == now.month;
        });
        avgIncome = monthlyIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      }

      if (avgExpense == 0.0) {
        final monthlyExpensesList = expenses.where((e) {
          final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
          return d != null && d.year == now.year && d.month == now.month;
        });
        avgExpense = monthlyExpensesList.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      }

      final double predictedSavings = avgIncome - avgExpense;

      return Column(
        children: [
          const Text('Based on historical monthly transaction averages, here is your projected cash flow for next month.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 24),
          _buildDetailRow('Expected Income', CurrencyFormatter.format(ref.read(preferencesProvider.notifier).convertFromBaseline(avgIncome), supportedCurrencies[ref.read(preferencesProvider).currencyIndex].code), LucideIcons.arrowDownLeft, AppColors.accentEmerald),
          const SizedBox(height: 16),
          _buildDetailRow('Predicted Expenses', CurrencyFormatter.format(ref.read(preferencesProvider.notifier).convertFromBaseline(avgExpense), supportedCurrencies[ref.read(preferencesProvider).currencyIndex].code), LucideIcons.arrowUpRight, AppColors.accentRose),
          const SizedBox(height: 16),
          _buildDetailRow('Estimated Savings', CurrencyFormatter.format(ref.read(preferencesProvider.notifier).convertFromBaseline(predictedSavings), supportedCurrencies[ref.read(preferencesProvider).currencyIndex].code), LucideIcons.piggyBank, AppColors.accentCyan),
        ],
      );
    });
  }

  Widget _buildRecommendationsModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final totalIncome = incomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      final totalExpense = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      final cashReserve = totalIncome - totalExpense;

      final recommendations = <Widget>[];

      final prefs = ref.watch(preferencesProvider);
      final code = supportedCurrencies[prefs.currencyIndex].code;
      final notifier = ref.read(preferencesProvider.notifier);
      if (cashReserve > 15000) {
        final displayReserve = CurrencyFormatter.format(notifier.convertFromBaseline(cashReserve), code);
        final displayInvest = CurrencyFormatter.format(notifier.convertFromBaseline(cashReserve * 0.4), code);
        final displayReturn = CurrencyFormatter.format(notifier.convertFromBaseline(cashReserve * 0.06), code);
        recommendations.add(_buildInsightCard(
          'Invest Idle Cash',
          'You have accumulated $displayReserve in reserves. Allocating $displayInvest into a liquid mutual fund could yield up to $displayReturn in annual returns.',
          LucideIcons.trendingUp,
          AppColors.accentEmerald,
        ));
        recommendations.add(const SizedBox(height: 16));
      }

      final now = DateTime.now();
      final monthlyExpensesList = expenses.where((e) {
        final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final categoryExpenses = <String, double>{};
      for (final e in monthlyExpensesList) {
        final cat = e['category']?.toString().toLowerCase() ?? 'other';
        categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
      }

      String overBudgetName = '';
      for (final b in budgets) {
        final cat = b['category']?.toString().toLowerCase() ?? '';
        final limit = _parseAmount(b['amount']);
        if (cat.isNotEmpty && limit > 0) {
          final spent = categoryExpenses[cat] ?? 0.0;
          if (spent > limit) {
            overBudgetName = b['category']?.toString() ?? '';
            break;
          }
        }
      }

      if (overBudgetName.isNotEmpty) {
        recommendations.add(_buildInsightCard(
          'Target Budget Trimming',
          'You have exceeded your "$overBudgetName" budget. Postpone optional shopping items in this category for 10 days to recover balance.',
          LucideIcons.target,
          AppColors.accentRose,
        ));
        recommendations.add(const SizedBox(height: 16));
      }

      final subs = _detectSubscriptions(expenses);
      if (subs.length > 2) {
        recommendations.add(_buildInsightCard(
          'Audit Subscriptions',
          'You currently run ${subs.length} active subscription contracts. Periodically cancel unused streaming/service bundles to secure extra cash.',
          LucideIcons.refreshCcw,
          AppColors.accentAmber,
        ));
        recommendations.add(const SizedBox(height: 16));
      }

      if (recommendations.isEmpty) {
        recommendations.add(_buildInsightCard(
          'Keep Going!',
          'Your current expense-to-income distribution matches the 50/30/20 standard. Keep recording items to unlock more complex recommendations.',
          LucideIcons.lightbulb,
          AppColors.accentCyan,
        ));
      } else if (recommendations.last is SizedBox) {
        recommendations.removeLast();
      }

      return Column(children: recommendations);
    });
  }

  Widget _buildRiskAlertsModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final now = DateTime.now();
      final monthlyExpensesList = expenses.where((e) {
        final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final totalMonthlyExpense = monthlyExpensesList.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

      final monthlyIncomes = incomes.where((e) {
        final d = DateTime.tryParse(e['income_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final totalMonthlyIncome = monthlyIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

      final alerts = <Widget>[];

      if (totalMonthlyIncome > 0 && (totalMonthlyExpense / totalMonthlyIncome) > 0.8) {
        final pct = (totalMonthlyExpense / totalMonthlyIncome * 100).toStringAsFixed(0);
        alerts.add(_buildInsightCard(
          'Critical Burn Rate',
          'You have consumed $pct% of your total incoming capital. We recommend locking down all discretionary expenditures.',
          LucideIcons.flame,
          AppColors.accentRose,
        ));
        alerts.add(const SizedBox(height: 16));
      }

      final categoryExpenses = <String, double>{};
      for (final e in monthlyExpensesList) {
        final cat = e['category']?.toString().toLowerCase() ?? 'other';
        categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
      }
      for (final b in budgets) {
        final cat = b['category']?.toString().toLowerCase() ?? '';
        final limit = _parseAmount(b['amount']);
        if (cat.isNotEmpty && limit > 0) {
          final spent = categoryExpenses[cat] ?? 0.0;
          if (spent > limit) {
            final prefs = ref.watch(preferencesProvider);
            final code = supportedCurrencies[prefs.currencyIndex].code;
            final notifier = ref.read(preferencesProvider.notifier);
            final displaySpent = CurrencyFormatter.format(notifier.convertFromBaseline(spent), code);
            final displayLimit = CurrencyFormatter.format(notifier.convertFromBaseline(limit), code);
            alerts.add(_buildInsightCard(
              'Budget Limits Exceeded',
              'Your spending in "${b['category']}" is $displaySpent, which exceeds the configured limit of $displayLimit.',
              LucideIcons.alertOctagon,
              AppColors.accentRose,
            ));
            alerts.add(const SizedBox(height: 16));
          }
        }
      }

      for (final e in monthlyExpensesList) {
        final amt = _parseAmount(e['amount']);
        if (amt >= 10000.0) {
          final prefs = ref.watch(preferencesProvider);
          final code = supportedCurrencies[prefs.currencyIndex].code;
          final notifier = ref.read(preferencesProvider.notifier);
          final displayAmt = CurrencyFormatter.format(notifier.convertFromBaseline(amt), code);
          final cleanDesc = MultiCurrencyData.cleanDescription(e['description'] ?? '');
          alerts.add(_buildInsightCard(
            'Large Single Outflow',
            'A single large transaction of $displayAmt for "$cleanDesc" was posted this month. Please audit.',
            LucideIcons.alertTriangle,
            AppColors.accentAmber,
          ));
          alerts.add(const SizedBox(height: 16));
          break;
        }
      }

      if (alerts.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(LucideIcons.shieldCheck, color: AppColors.accentEmerald, size: 48),
                SizedBox(height: 16),
                Text('Buffer Secure', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('No critical risk alerts triggered. Your allocations are healthy.', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }

      if (alerts.isNotEmpty && alerts.last is SizedBox) {
        alerts.removeLast();
      }

      return Column(children: alerts);
    });
  }

  Widget _buildSubscriptionModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final subs = _detectSubscriptions(expenses);

      if (subs.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No active subscriptions detected in transactions.', style: TextStyle(color: AppColors.textSecondary)),
          ),
        );
      }

      return Column(
        children: [
          Text('We found ${subs.length} active recurring charges.', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ...subs.map((sub) {
            final amt = _parseAmount(sub['amount']);
            final rawDesc = sub['description'] ?? 'Recurring Charge';
            final title = MultiCurrencyData.cleanDescription(rawDesc);
            Color color = AppColors.accentCyan;
            final lowerTitle = title.toLowerCase();

            if (lowerTitle.contains('netflix')) color = AppColors.accentRose;
            else if (lowerTitle.contains('spotify')) color = AppColors.accentEmerald;
            else if (lowerTitle.contains('prime') || lowerTitle.contains('amazon')) color = AppColors.accentCyan;

            final prefs = ref.watch(preferencesProvider);
            final code = supportedCurrencies[prefs.currencyIndex].code;
            final notifier = ref.read(preferencesProvider.notifier);
            final subMc = MultiCurrencyData.parse(rawDesc);

            String displayPrice = '';
            if (subMc != null) {
              displayPrice = '${CurrencyFormatter.format(subMc.amount, subMc.currency)}/mo';
            } else {
              displayPrice = '${CurrencyFormatter.format(notifier.convertFromBaseline(amt), code)}/mo';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: Icon(LucideIcons.playCircle, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(displayPrice, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppColors.bgElevated,
                          title: const Text('Delete Subscription Transaction', style: TextStyle(color: AppColors.textPrimary)),
                          content: Text('Are you sure you want to delete the transaction "$title" for $displayPrice? This will remove it from database.', style: const TextStyle(color: AppColors.textSecondary)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final id = sub['id']?.toString() ?? '';
                        if (id.isNotEmpty) {
                          await ref.read(expenseServiceProvider).deleteExpense(id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Subscription transaction deleted successfully.')),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Cancel', style: TextStyle(color: AppColors.accentRose)),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    });
  }

  Widget _buildBudgetModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      if (budgets.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('No budgets configured. Set category limits in Budgets screen.', style: TextStyle(color: AppColors.textSecondary)),
          ),
        );
      }

      final now = DateTime.now();
      final monthlyExpensesList = expenses.where((e) {
        final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });

      final categoryExpenses = <String, double>{};
      for (final e in monthlyExpensesList) {
        final cat = e['category']?.toString().toLowerCase() ?? 'other';
        categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
      }

      return Column(
        children: budgets.map((b) {
          final cat = b['category']?.toString() ?? 'Other';
          final limit = _parseAmount(b['amount']);
          final spent = categoryExpenses[cat.toLowerCase()] ?? 0.0;
          final double fill = limit > 0 ? (spent / limit) : 0.0;

          Color color = AppColors.accentEmerald;
          if (fill >= 0.9) {
            color = AppColors.accentRose;
          } else if (fill >= 0.7) {
            color = AppColors.accentAmber;
          }

          final pct = (fill * 100).toInt();

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(cat, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      '${CurrencyFormatter.format(ref.read(preferencesProvider.notifier).convertFromBaseline(spent), supportedCurrencies[ref.read(preferencesProvider).currencyIndex].code)} / ${CurrencyFormatter.format(ref.read(preferencesProvider.notifier).convertFromBaseline(limit), supportedCurrencies[ref.read(preferencesProvider).currencyIndex].code)} ($pct%)',
                      style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: fill.clamp(0.0, 1.0),
                  backgroundColor: AppColors.bgPrimary,
                  color: color,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildSavingsModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final now = DateTime.now();

      final currentMonthExpenses = expenses.where((e) {
        final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final monthlyExpense = currentMonthExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

      final currentMonthIncomes = incomes.where((e) {
        final d = DateTime.tryParse(e['income_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final monthlyIncome = currentMonthIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

      final double monthlySavings = monthlyIncome - monthlyExpense;
      final double savingsRate = monthlyIncome > 0 ? (monthlySavings / monthlyIncome) : 0.0;

      final totalIncome = incomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      final totalExpense = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      final reserves = totalIncome - totalExpense;

      final avgMonthlyExpense = monthlyExpense > 0 ? monthlyExpense : 15000.0;
      final double runway = avgMonthlyExpense > 0 ? (reserves / avgMonthlyExpense) : 0.0;

      return Column(
        children: [
          Text('Total Savings Rate: ${(savingsRate * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(savingsRate >= 0.20
              ? 'You are in a healthy savings bracket! Keep it up!'
              : 'Try keeping your expenses under 80% of income to improve savings.', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          _buildDetailRow(
            'Cash Reserve Buffer',
            CurrencyFormatter.format(ref.read(preferencesProvider.notifier).convertFromBaseline(reserves), supportedCurrencies[ref.read(preferencesProvider).currencyIndex].code),
            LucideIcons.shieldCheck,
            AppColors.accentCyan,
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Emergency Runway', '${runway.toStringAsFixed(1)} Month(s)', LucideIcons.trendingUp, AppColors.accentPurple),
        ],
      );
    });
  }

  Widget _buildGoalsModal(BuildContext context, WidgetRef ref) {
    return const GoalsManagerWidget();
  }

  Widget _buildStoryModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final now = DateTime.now();
      final monthName = DateFormat('MMMM').format(now);

      final currentMonthExpenses = expenses.where((e) {
        final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final monthlyExpense = currentMonthExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

      final currentMonthIncomes = incomes.where((e) {
        final d = DateTime.tryParse(e['income_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final monthlyIncome = currentMonthIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

      final double savingsRate = monthlyIncome > 0 ? ((monthlyIncome - monthlyExpense) / monthlyIncome) : 0.0;
      final savingsPct = (savingsRate * 100).toStringAsFixed(0);

      final categoryExpenses = <String, double>{};
      for (final e in currentMonthExpenses) {
        final cat = e['category']?.toString() ?? 'Other';
        categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
      }
      String topCat = 'none';
      double maxAmt = 0;
      for (final entry in categoryExpenses.entries) {
        if (entry.value > maxAmt) {
          maxAmt = entry.value;
          topCat = entry.key;
        }
      }

      final recapText = monthlyIncome > 0 || monthlyExpense > 0
          ? 'You started $monthName strong, achieving a $savingsPct% savings rate. '
              '${topCat != 'none' ? "Your largest spending sector was \"$topCat\" costing ${CurrencyFormatter.format(ref.read(preferencesProvider.notifier).convertFromBaseline(maxAmt), supportedCurrencies[ref.read(preferencesProvider).currencyIndex].code)}." : ""} '
              'Overall, your balance remained ${savingsRate >= 0.20 ? "highly secure" : "tightly buffered"}.'
          : 'You haven\'t recorded any income or expense transactions in $monthName yet. Record some bills to craft your financial story!';

      return Column(
        children: [
          const Icon(LucideIcons.sparkles, color: AppColors.accentPurple, size: 48),
          const SizedBox(height: 24),
          Text('$monthName Recap', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(recapText, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('/monthly-wrap');
              },
              icon: const Icon(LucideIcons.bookOpen, size: 18),
              label: const Text('View Full Wrap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildAchievementsModal(BuildContext context, WidgetRef ref) {
    return _withData(ref, (expenses, incomes, budgets) {
      final now = DateTime.now();

      final currentMonthExpenses = expenses.where((e) {
        final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final monthlyExpense = currentMonthExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

      final currentMonthIncomes = incomes.where((e) {
        final d = DateTime.tryParse(e['income_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      });
      final monthlyIncome = currentMonthIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
      final savingsRate = monthlyIncome > 0 ? ((monthlyIncome - monthlyExpense) / monthlyIncome) : 0.0;

      final categoryExpenses = <String, double>{};
      for (final e in currentMonthExpenses) {
        final cat = e['category']?.toString().toLowerCase() ?? 'other';
        categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
      }
      int overruns = 0;
      for (final b in budgets) {
        final cat = b['category']?.toString().toLowerCase() ?? '';
        final limit = _parseAmount(b['amount']);
        if (cat.isNotEmpty && limit > 0) {
          final spent = categoryExpenses[cat] ?? 0.0;
          if (spent > limit) overruns++;
        }
      }

      final expenseDates = expenses.map((e) {
        final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
        return d != null ? DateTime(d.year, d.month, d.day) : null;
      }).whereType<DateTime>().toSet();

      int streak = 0;
      for (int i = 0; i < 30; i++) {
        final testDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        if (!expenseDates.contains(testDate)) {
          streak++;
        } else {
          if (i > 0) break;
        }
      }

      final isStreakUnlocked = streak >= 5;
      final isSaverUnlocked = savingsRate >= 0.3;
      final isBudgetBossUnlocked = budgets.isNotEmpty && overruns == 0;

      return Column(
        children: [
          const Text('Your financial milestones and streak rewards', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBadge(
                isStreakUnlocked ? '$streak Day Streak' : 'No Expense Streak',
                LucideIcons.flame,
                isStreakUnlocked ? AppColors.accentRose : AppColors.textTertiary,
                isStreakUnlocked,
              ),
              _buildBadge(
                'Super Saver',
                LucideIcons.piggyBank,
                isSaverUnlocked ? AppColors.accentEmerald : AppColors.textTertiary,
                isSaverUnlocked,
              ),
              _buildBadge(
                'Budget Boss',
                LucideIcons.target,
                isBudgetBossUnlocked ? AppColors.accentCyan : AppColors.textTertiary,
                isBudgetBossUnlocked,
              ),
            ],
          ),
        ],
      );
    });
  }

  // --- Helpers for Modals ---

  Widget _buildDetailRow(String title, String value, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(String title, String body, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBadge(String title, IconData icon, Color color, bool unlocked) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(unlocked ? 0.2 : 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(unlocked ? 1.0 : 0.2), width: 1.5),
          ),
          child: Icon(icon, color: color.withOpacity(unlocked ? 1.0 : 0.3), size: 32),
        ),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: unlocked ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  List<Map<String, dynamic>> _detectSubscriptions(List<Map<String, dynamic>> expenses) {
    final keywords = ['spotify', 'netflix', 'youtube', 'prime', 'gym', 'rent', 'broadband', 'adobe'];
    return expenses.where((e) {
      final desc = MultiCurrencyData.cleanDescription(e['description']?.toString() ?? '').toLowerCase();
      return keywords.any((kw) => desc.contains(kw));
    }).toList();
  }
}

class _DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String stat;
  final Widget Function(BuildContext, WidgetRef) builder;

  _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.stat,
    required this.builder,
  });
}

class GoalsManagerWidget extends ConsumerStatefulWidget {
  const GoalsManagerWidget({super.key});

  @override
  ConsumerState<GoalsManagerWidget> createState() => _GoalsManagerWidgetState();
}

class _GoalsManagerWidgetState extends ConsumerState<GoalsManagerWidget> {
  void _addGoal(String name, double targetInPref, double currentInPref) {
    final prefs = ref.read(preferencesProvider);
    final prefCurrency = supportedCurrencies[prefs.currencyIndex];
    final notifier = ref.read(preferencesProvider.notifier);
    
    final targetBaseline = notifier.convertToBaseline(targetInPref, prefCurrency.code);
    final currentBaseline = notifier.convertToBaseline(currentInPref, prefCurrency.code);
    
    ref.read(localGoalsProvider.notifier).addGoal(name, targetBaseline, currentBaseline);
  }

  void _updateGoalProgress(String id, double progressInPref) {
    final prefs = ref.read(preferencesProvider);
    final prefCurrency = supportedCurrencies[prefs.currencyIndex];
    final notifier = ref.read(preferencesProvider.notifier);
    
    final progressBaseline = notifier.convertToBaseline(progressInPref, prefCurrency.code);
    
    ref.read(localGoalsProvider.notifier).updateGoalProgress(id, progressBaseline);
  }

  void _deleteGoal(String id) {
    ref.read(localGoalsProvider.notifier).deleteGoal(id);
  }

  double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final currentController = TextEditingController();

    final prefs = ref.read(preferencesProvider);
    final prefCurrency = supportedCurrencies[prefs.currencyIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Add Financial Goal', style: TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Goal Name',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentCyan)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Target Amount (${prefCurrency.symbol})',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentCyan)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: currentController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Current Saved Amount (${prefCurrency.symbol})',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentCyan)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final target = double.tryParse(targetController.text) ?? 0.0;
              final current = double.tryParse(currentController.text) ?? 0.0;
              if (name.isNotEmpty && target > 0) {
                _addGoal(name, target, current);
                Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUpdateProgressDialog(Map<String, dynamic> goal) {
    final prefs = ref.read(preferencesProvider);
    final prefCurrency = supportedCurrencies[prefs.currencyIndex];
    final notifier = ref.read(preferencesProvider.notifier);

    final currentBaseline = _parseAmount(goal['currentAmount']);
    final currentInPref = notifier.convertFromBaseline(currentBaseline);
    final currentController = TextEditingController(text: currentInPref.toStringAsFixed(prefCurrency.code == 'JPY' ? 0 : 2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Update "${goal['name']}" Progress', style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: currentController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'New Saved Amount (${prefCurrency.symbol})',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSubtle)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentCyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final amt = double.tryParse(currentController.text) ?? 0.0;
              _updateGoalProgress(goal['id']?.toString() ?? '', amt);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(localGoalsProvider);
    if (goals.isEmpty) {
      return Column(
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No goals tracked. Tap below to create your first goal!', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showAddGoalDialog,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan.withOpacity(0.12),
              foregroundColor: AppColors.accentCyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        ...goals.map((g) {
          final targetBaseline = _parseAmount(g['targetAmount']);
          final currentBaseline = _parseAmount(g['currentAmount']);

          final prefs = ref.watch(preferencesProvider);
          final code = supportedCurrencies[prefs.currencyIndex].code;
          final notifier = ref.read(preferencesProvider.notifier);

          final target = notifier.convertFromBaseline(targetBaseline);
          final current = notifier.convertFromBaseline(currentBaseline);

          final fill = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
          final pct = (fill * 100).toStringAsFixed(0);

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        g['name'] ?? 'Untitled Goal',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.edit2, color: AppColors.accentCyan, size: 16),
                          onPressed: () => _showUpdateProgressDialog(g),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, color: AppColors.accentRose, size: 16),
                          onPressed: () {
                            _deleteGoal(g['id']?.toString() ?? '');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${CurrencyFormatter.format(current, code)} / ${CurrencyFormatter.format(target, code)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    Text('$pct%', style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: fill,
                  backgroundColor: AppColors.bgPrimary,
                  color: AppColors.accentCyan,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _showAddGoalDialog,
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Add New Goal'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan.withOpacity(0.12),
            foregroundColor: AppColors.accentCyan,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
