import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_cache_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../expenses/data/expense_service.dart';
import '../../income/data/income_service.dart';
import '../../budget/data/budget_service.dart';
import '../../goals/data/financial_goal_service.dart';
import '../models/intelligence_models.dart';

import 'financial_score_calculator.dart';
import 'pattern_analyzer.dart';
import 'forecast_engine.dart';
import 'achievement_engine.dart';
import 'recommendation_engine.dart';
import 'insight_generator.dart';

class IntelligenceReport {
  final DailyInsight dailyInsight;
  final FinancialHealthScore healthScore;
  final ForecastData forecast;
  final List<BudgetHealth> budgetIntelligence;
  final List<SavingsOpportunity> savingsOpportunities;
  final SpendingBehaviour spendingBehaviour;
  final List<GoalPrediction> goalIntelligence;
  final WeeklyStory weeklyStory;
  final List<Achievement> achievements;
  final List<FinancialChallenge> challenges;
  final List<RecurringSubscription> recurringPayments;
  final List<SmartAlert> smartAlerts;
  final List<CoachingRecommendation> recommendations;
  final MonthlyReportPreview monthlyReport;

  const IntelligenceReport({
    required this.dailyInsight,
    required this.healthScore,
    required this.forecast,
    required this.budgetIntelligence,
    required this.savingsOpportunities,
    required this.spendingBehaviour,
    required this.goalIntelligence,
    required this.weeklyStory,
    required this.achievements,
    required this.challenges,
    required this.recurringPayments,
    required this.smartAlerts,
    required this.recommendations,
    required this.monthlyReport,
  });
}

class IntelligenceEngineNotifier extends Notifier<AsyncValue<IntelligenceReport>> {
  @override
  AsyncValue<IntelligenceReport> build() {
    // Watch streams and rebuild report automatically
    final expensesAsync = ref.watch(expensesStreamProvider);
    final incomesAsync = ref.watch(incomeStreamProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final goals = ref.watch(localGoalsProvider);

    if (expensesAsync.isLoading || incomesAsync.isLoading || budgetsAsync.isLoading) {
      return const AsyncValue.loading();
    }

    if (expensesAsync.hasError || incomesAsync.hasError || budgetsAsync.hasError) {
      return AsyncValue.error(
        expensesAsync.error ?? incomesAsync.error ?? budgetsAsync.error ?? 'Error loading data',
        StackTrace.current,
      );
    }

    final expenses = expensesAsync.value ?? [];
    final incomes = incomesAsync.value ?? [];
    final budgets = budgetsAsync.value ?? [];

    try {
      final report = _computeReport(expenses, incomes, budgets, goals);
      return AsyncValue.data(report);
    } catch (e, stack) {
      return AsyncValue.error(e, stack);
    }
  }

  double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  String get _userId {
    return ref.read(currentUserProvider)?.id ?? 'guest';
  }

  IntelligenceReport _computeReport(
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> incomes,
    List<Map<String, dynamic>> budgets,
    List<Map<String, dynamic>> goals,
  ) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;
    final daysRemaining = max(1, daysInMonth - currentDay + 1);

    // Common Monthly calculations
    final currentMonthExpenses = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
    final monthlyExpense = currentMonthExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    final monthlyIncomes = incomes.where((e) {
      final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    });
    final monthlyIncome = monthlyIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final double savingsRate = monthlyIncome > 0 ? (monthlyIncome - monthlyExpense) / monthlyIncome : 0.0;

    // 1. Behavior Streak from pattern engine
    final spendingBehaviour = PatternAnalyzer.analyze(expenses: expenses, incomes: incomes);

    // 2. Health score
    final healthScore = FinancialScoreCalculator.calculate(
      expenses: expenses,
      incomes: incomes,
      budgets: budgets,
    );

    // 3. Forecast data
    final forecast = ForecastEngine.run(
      expenses: expenses,
      incomes: incomes,
      budgets: budgets,
      goals: goals,
    );

    // 4. Daily insight
    final dailyInsight = InsightGenerator.generateDailyInsight(
      expenses: expenses,
      incomes: incomes,
      budgets: budgets,
      goals: goals,
    );

    // 5. Budget intelligence
    final budgetIntelligence = <BudgetHealth>[];
    final categoryExpenses = <String, double>{};
    for (final e in currentMonthExpenses) {
      final cat = e['category']?.toString().toLowerCase() ?? 'other';
      categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
    }

    for (final b in budgets) {
      final cat = b['category']?.toString() ?? '';
      if (cat.isEmpty) continue;
      final cleanCat = cat.substring(0, 1).toUpperCase() + cat.substring(1).toLowerCase();
      final limit = _parseAmount(b['amount']);
      final spent = categoryExpenses[cat.toLowerCase()] ?? 0.0;
      final remaining = max(0.0, limit - spent);

      // Risky conditions
      final double burnRatio = spent / limit;
      final bool isRisky = burnRatio >= 0.8 || (forecast.expectedCategorySpending[cleanCat] ?? 0.0) > limit;

      // Overrun date calculation
      String? overrunDateStr;
      final double runDays = max(1.0, currentDay.toDouble());
      final double dailyBurn = spent / runDays;
      final double dailyRecommended = remaining / daysRemaining;

      if (dailyBurn > dailyRecommended && remaining > 0) {
        final daysToOverrun = (remaining / dailyBurn).floor();
        final date = now.add(Duration(days: daysToOverrun));
        overrunDateStr = DateFormat('MMM dd').format(date);
      } else if (spent > limit) {
        overrunDateStr = 'Exceeded';
      } else {
        overrunDateStr = 'No Overrun Predicted';
      }

      budgetIntelligence.add(
        BudgetHealth(
          category: cleanCat,
          isRisky: isRisky,
          limit: limit,
          spent: spent,
          overrunDate: overrunDateStr,
          remainingSafeSpending: remaining,
          dailyRecommendedSpending: dailyRecommended,
        ),
      );
    }

    // 6. Savings opportunities
    final savingsOps = <SavingsOpportunity>[];
    // Suggest savings in categories with high spend
    categoryExpenses.forEach((cat, spent) {
      final cleanCat = cat.substring(0, 1).toUpperCase() + cat.substring(1).toLowerCase();
      if (spent > 3000) {
        double potential = spent * 0.15; // Target 15% reduction
        IconData icon = LucideIcons.piggyBank;
        if (cat.contains('food')) icon = LucideIcons.pizza;
        if (cat.contains('shop')) icon = LucideIcons.shoppingBag;
        if (cat.contains('travel') || cat.contains('trans')) icon = LucideIcons.car;

        savingsOps.add(
          SavingsOpportunity(
            category: cleanCat,
            description: 'Trim $cleanCat meals/purchases by 15% to save ₹${potential.toStringAsFixed(0)} monthly.',
            monthlySavingsPotential: potential,
            icon: icon,
          ),
        );
      }
    });

    if (savingsOps.isEmpty) {
      savingsOps.add(
        const SavingsOpportunity(
          category: 'Lifestyle',
          description: 'Try cut streaming services or subscriptions to save ₹500 monthly.',
          monthlySavingsPotential: 500,
          icon: LucideIcons.film,
        ),
      );
    }

    // 7. Goal intelligence predictions
    final goalIntelligence = <GoalPrediction>[];
    for (final g in goals) {
      final name = g['name']?.toString() ?? 'Savings Goal';
      final target = _parseAmount(g['targetAmount']);
      final current = _parseAmount(g['currentAmount']);
      final needed = max(0.0, target - current);

      // Monthly savings rate
      final monthlySave = max(1000.0, forecast.predictedSavings > 0 ? forecast.predictedSavings : 5000.0);
      final dailyNeeded = needed > 0 ? (needed / daysRemaining) : 0.0;
      final weeklyNeeded = needed > 0 ? (needed / (daysRemaining / 7.0)) : 0.0;

      // Completion prediction
      DateTime? compDate;
      if (needed > 0 && monthlySave > 0) {
        final days = (needed / (monthlySave / 30.0)).ceil();
        compDate = now.add(Duration(days: min(365 * 5, days)));
      }

      double prob = 0.5;
      if (current >= target) {
        prob = 1.0;
      } else if (monthlySave / 30.0 >= dailyNeeded) {
        prob = 0.90;
      } else if (monthlySave / 30.0 >= dailyNeeded * 0.5) {
        prob = 0.65;
      } else {
        prob = 0.35;
      }

      final celebrate = current >= target;

      goalIntelligence.add(
        GoalPrediction(
          name: name,
          targetAmount: target,
          currentSaved: current,
          expectedCompletionDate: compDate,
          dailyAmountRequired: dailyNeeded,
          weeklyAmountRequired: weeklyNeeded,
          probabilityOfSuccess: prob,
          fastestPath: 'Save ₹${(dailyNeeded * 1.25).toStringAsFixed(0)} daily to finish 20% faster.',
          delayRisk: dailyNeeded > (monthlySave / 30.0) ? 'Delay risk high due to lower run-rate savings.' : 'On track with zero delay risk.',
          milestoneCelebration: celebrate,
        ),
      );
    }

    // 8. Weekly story
    final weeklyStory = InsightGenerator.generateWeeklyStory(expenses: expenses, incomes: incomes);

    // 9. Achievements
    final achievements = AchievementEngine.evaluate(
      expenses: expenses,
      incomes: incomes,
      budgets: budgets,
      goals: goals,
      currentStreak: spendingBehaviour.currentExpenseStreak,
    );

    // 10. Load recurring payments & confirmed subs from local cache
    final recurringPayments = _detectRecurringSubscriptions(expenses);

    // 11. Challenges: Load or initialize
    final challenges = _loadChallenges(expenses);

    // 12. Smart alerts
    final smartAlerts = InsightGenerator.generateSmartAlerts(
      expenses: expenses,
      incomes: incomes,
      budgets: budgets,
      goals: goals,
    );

    // 13. Coaching recommendations
    final recommendations = RecommendationEngine.evaluate(
      expenses: expenses,
      incomes: incomes,
      budgets: budgets,
      goals: goals,
    );

    // 14. Monthly report preview
    String worstCat = 'None';
    double maxCatSpent = 0.0;
    categoryExpenses.forEach((cat, spent) {
      if (spent > maxCatSpent) {
        maxCatSpent = spent;
        worstCat = cat;
      }
    });

    String bestCat = 'Savings'; // Default
    if (savingsRate > 0.3) {
      bestCat = 'Investment';
    }

    final oneSentenceSummary = savingsRate >= 0.2
        ? 'A strong month where your savings rate successfully hit the target zone.'
        : 'Optimize subscriptions and dining to protect your cash reserves this month.';

    final monthlyReport = MonthlyReportPreview(
      income: monthlyIncome,
      expense: monthlyExpense,
      savings: max(0.0, monthlyIncome - monthlyExpense),
      bestCategory: bestCat.substring(0, 1).toUpperCase() + bestCat.substring(1).toLowerCase(),
      worstCategory: worstCat != 'None' ? worstCat.substring(0, 1).toUpperCase() + worstCat.substring(1).toLowerCase() : 'None',
      healthScore: healthScore.currentScore,
      endOfMonthForecast: forecast.endOfMonthExpenses,
      oneSentenceSummary: oneSentenceSummary,
    );

    return IntelligenceReport(
      dailyInsight: dailyInsight,
      healthScore: healthScore,
      forecast: forecast,
      budgetIntelligence: budgetIntelligence,
      savingsOpportunities: savingsOps,
      spendingBehaviour: spendingBehaviour,
      goalIntelligence: goalIntelligence,
      weeklyStory: weeklyStory,
      achievements: achievements,
      challenges: challenges,
      recurringPayments: recurringPayments,
      smartAlerts: smartAlerts,
      recommendations: recommendations,
      monthlyReport: monthlyReport,
    );
  }

  // --- Subscriptions helpers ---

  List<RecurringSubscription> _detectRecurringSubscriptions(List<Map<String, dynamic>> expenses) {
    final keywords = {
      'spotify': 'Spotify Premium',
      'netflix': 'Netflix Sub',
      'youtube': 'YouTube Premium',
      'prime': 'Amazon Prime',
      'gym': 'Gym Membership',
      'rent': 'Rent Payment',
      'broadband': 'Internet Bills',
      'adobe': 'Adobe Creative Cloud',
      'electricity': 'Electricity Bill',
      'insurance': 'Insurance Premium',
    };

    final detected = <String, Map<String, dynamic>>{};
    final confirmedSet = Set<String>.from(
      LocalCacheService.getCachedData('confirmed_subs_$_userId') ?? [],
    );

    for (final e in expenses) {
      final desc = e['description']?.toString().toLowerCase() ?? '';
      final amt = _parseAmount(e['amount']);
      if (amt <= 0) continue;

      for (final kw in keywords.entries) {
        if (desc.contains(kw.key)) {
          // Keep the latest record
          final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
          final date = DateTime.tryParse(dateStr) ?? DateTime.now();
          final id = kw.key;

          if (!detected.containsKey(id) || date.isAfter(DateTime.tryParse(detected[id]!['date']) ?? DateTime(2000))) {
            detected[id] = {
              'id': id,
              'description': e['description']?.toString() ?? kw.value,
              'cleanName': kw.value,
              'amount': amt,
              'date': date.toIso8601String(),
              'isConfirmed': confirmedSet.contains(id),
            };
          }
        }
      }
    }

    return detected.values.map((v) {
      IconData icon = LucideIcons.refreshCcw;
      if (v['id'] == 'rent') icon = LucideIcons.home;
      if (v['id'] == 'electricity') icon = LucideIcons.zap;

      return RecurringSubscription(
        id: v['id'],
        description: v['description'],
        cleanName: v['cleanName'],
        amount: v['amount'],
        dateDetected: DateTime.parse(v['date']),
        isConfirmed: v['isConfirmed'],
        icon: icon,
      );
    }).toList();
  }

  void confirmSubscription(String subId) async {
    final confirmedList = List<String>.from(
      LocalCacheService.getCachedData('confirmed_subs_$_userId') ?? [],
    );
    if (!confirmedList.contains(subId)) {
      confirmedList.add(subId);
      await LocalCacheService.cacheData('confirmed_subs_$_userId', confirmedList);
      // Re-trigger calculation
      ref.invalidateSelf();
    }
  }

  // --- Challenges Helpers ---

  List<FinancialChallenge> _loadChallenges(List<Map<String, dynamic>> expenses) {
    final now = DateTime.now();

    // Base mock challenges
    final baseChallenges = [
      {
        'id': 'no_delivery',
        'name': 'No Food Delivery',
        'description': 'Avoid ordering food for 7 days. Cook at home instead.',
        'targetAmount': 0.0,
      },
      {
        'id': 'under_500',
        'name': 'Spend Under ₹500 Today',
        'description': 'Keep total daily outflows below ₹500 today.',
        'targetAmount': 500.0,
      },
      {
        'id': 'save_100_daily',
        'name': 'Save ₹100 Daily',
        'description': 'Manually log or add ₹100 daily savings for a week.',
        'targetAmount': 700.0,
      },
      {
        'id': 'no_shopping',
        'name': 'No Shopping Weekend',
        'description': 'Avoid shopping and apparel outflows during Saturday and Sunday.',
        'targetAmount': 0.0,
      },
    ];

    // Load active from preferences/cache
    final activeMap = Map<String, dynamic>.from(
      LocalCacheService.getCachedMap('active_challenges_$_userId') ?? {},
    );

    return baseChallenges.map((bc) {
      final id = bc['id'] as String;
      final isActive = activeMap.containsKey(id);
      double currentAmount = 0.0;
      bool isCompleted = false;

      if (isActive) {
        final startDateStr = activeMap[id] as String;
        final startDate = DateTime.tryParse(startDateStr) ?? now;

        // Compute actual current spent based on challenge criteria
        if (id == 'under_500') {
          // Spent today
          final todayExpenses = expenses.where((e) {
            final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
            final d = DateTime.tryParse(dateStr);
            return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
          });
          currentAmount = todayExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
          isCompleted = currentAmount <= 500.0;
        } else if (id == 'no_delivery') {
          // Food spend since start date
          final foodExpenses = expenses.where((e) {
            final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
            final d = DateTime.tryParse(dateStr);
            final isFood = (e['category']?.toString().toLowerCase() ?? '').contains('food') || 
                           (e['description']?.toString().toLowerCase() ?? '').contains('deliver');
            return d != null && d.isAfter(startDate.subtract(const Duration(seconds: 1))) && isFood;
          });
          currentAmount = foodExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
          isCompleted = currentAmount == 0.0 && now.difference(startDate).inDays >= 7;
        } else if (id == 'no_shopping') {
          // Shopping spend since start date
          final shopExpenses = expenses.where((e) {
            final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
            final d = DateTime.tryParse(dateStr);
            final isShop = (e['category']?.toString().toLowerCase() ?? '').contains('shop');
            return d != null && d.isAfter(startDate.subtract(const Duration(seconds: 1))) && isShop;
          });
          currentAmount = shopExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
          // Check if weekend completed
          isCompleted = currentAmount == 0.0 && now.difference(startDate).inDays >= 2;
        } else {
          // General saving target
          currentAmount = 100.0 * min(7, now.difference(startDate).inDays + 1);
          isCompleted = currentAmount >= (bc['targetAmount'] as double);
        }
      }

      return FinancialChallenge(
        id: id,
        name: bc['name'] as String,
        description: bc['description'] as String,
        targetAmount: bc['targetAmount'] as double,
        currentAmount: currentAmount,
        isCompleted: isCompleted,
        isActive: isActive,
      );
    }).toList();
  }

  void acceptChallenge(String challengeId) async {
    final activeMap = Map<String, dynamic>.from(
      LocalCacheService.getCachedMap('active_challenges_$_userId') ?? {},
    );
    if (!activeMap.containsKey(challengeId)) {
      activeMap[challengeId] = DateTime.now().toIso8601String();
      await LocalCacheService.cacheData('active_challenges_$_userId', activeMap);
      ref.invalidateSelf();
    }
  }

  void abandonChallenge(String challengeId) async {
    final activeMap = Map<String, dynamic>.from(
      LocalCacheService.getCachedMap('active_challenges_$_userId') ?? {},
    );
    if (activeMap.containsKey(challengeId)) {
      activeMap.remove(challengeId);
      await LocalCacheService.cacheData('active_challenges_$_userId', activeMap);
      ref.invalidateSelf();
    }
  }
}

final intelligenceEngineProvider = NotifierProvider<IntelligenceEngineNotifier, AsyncValue<IntelligenceReport>>(() {
  return IntelligenceEngineNotifier();
});
