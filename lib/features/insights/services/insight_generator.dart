import '../models/intelligence_models.dart';

class InsightGenerator {
  static double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  /// Generates the Daily Insight Hero card
  static DailyInsight generateDailyInsight({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> incomes,
    required List<Map<String, dynamic>> budgets,
    required List<Map<String, dynamic>> goals,
  }) {
    if (expenses.isEmpty) {
      return const DailyInsight(
        title: 'Start Tracking Today',
        insight: 'We need transaction history to build your financial intelligence models.',
        recommendation: 'Log your first expense or income using the quick add actions.',
        confidence: 0.95,
      );
    }

    final now = DateTime.now();

    // 1. Budget performance check
    final currentMonthExpenses = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
    final monthlyExpense = currentMonthExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    final categoryExpenses = <String, double>{};
    for (final e in currentMonthExpenses) {
      final cat = e['category']?.toString().toLowerCase() ?? 'other';
      categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
    }

    String? overrunCategory;
    double overrunAmount = 0.0;
    for (final b in budgets) {
      final cat = b['category']?.toString().toLowerCase() ?? '';
      final limit = _parseAmount(b['amount']);
      final spent = categoryExpenses[cat] ?? 0.0;
      if (cat.isNotEmpty && limit > 0 && spent > limit) {
        overrunCategory = cat;
        overrunAmount = spent - limit;
        break;
      }
    }

    if (overrunCategory != null) {
      return DailyInsight(
        title: 'Budget Alert: $overrunCategory Exceeded',
        insight: 'Your spending in ${overrunCategory.toUpperCase()} has exceeded its allocated limit by ₹${overrunAmount.toStringAsFixed(0)}.',
        recommendation: 'Freeze non-essential purchases in this category for the next ${DateTime(now.year, now.month + 1, 0).day - now.day} days.',
        confidence: 0.90,
      );
    }

    // 2. Goal progress check
    final activeGoals = goals.where((g) {
      final target = _parseAmount(g['targetAmount']);
      final current = _parseAmount(g['currentAmount']);
      return current < target;
    }).toList();

    if (activeGoals.isNotEmpty) {
      final goal = activeGoals.first;
      final target = _parseAmount(goal['targetAmount']);
      final current = _parseAmount(goal['currentAmount']);
      final pct = (current / target * 100).toStringAsFixed(0);
      if (current / target >= 0.75) {
        return DailyInsight(
          title: 'Goal Milestone: "${goal['name']}"',
          insight: 'You are so close! You have completed $pct% of your target savings for "${goal['name']}". Only ₹${(target - current).toStringAsFixed(0)} remaining.',
          recommendation: 'Top up this goal with a small deposit today to cross the finish line.',
          confidence: 0.95,
        );
      }
    }

    // 3. Category Increase Check (Food category vs total)
    double foodSpend = categoryExpenses['food'] ?? 0.0;
    if (foodSpend > 0 && monthlyExpense > 0 && (foodSpend / monthlyExpense) > 0.3) {
      return DailyInsight(
        title: 'Category Spike: Food & Dining',
        insight: 'Food and dining represents ${(foodSpend / monthlyExpense * 100).toStringAsFixed(0)}% of your expenses this month (₹${foodSpend.toStringAsFixed(0)}).',
        recommendation: 'Cook home meals or prepare a lunch box today to reduce high delivery costs.',
        confidence: 0.85,
      );
    }

    // 4. Weekend vs Weekday trend
    double weekendExpenses = 0.0;
    for (final e in currentMonthExpenses) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      if (d != null && (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday)) {
        weekendExpenses += _parseAmount(e['amount']);
      }
    }
    final double weekendPct = monthlyExpense > 0 ? (weekendExpenses / monthlyExpense) : 0.0;
    if (weekendPct > 0.50) {
      return DailyInsight(
        title: 'Weekend Habit Detected',
        insight: 'Over ${(weekendPct * 100).toStringAsFixed(0)}% of your monthly outflows occur during Saturdays and Sundays.',
        recommendation: 'Establish a "weekend pocket allowance" to control entertainment spikes.',
        confidence: 0.80,
      );
    }

    // Default savings success hero
    final monthlyIncomes = incomes.where((e) {
      final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    });
    final monthlyIncome = monthlyIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final savingsRate = monthlyIncome > 0 ? (monthlyIncome - monthlyExpense) / monthlyIncome : 0.0;

    if (savingsRate >= 0.20) {
      return DailyInsight(
        title: 'Healthy Savings Rate',
        insight: 'Your monthly savings rate is at ${(savingsRate * 100).toStringAsFixed(0)}%. You are keeping a robust share of your earnings.',
        recommendation: 'Consider moving 10% of this surplus into long-term investment assets.',
        confidence: 0.88,
      );
    }

    return const DailyInsight(
      title: 'Maintain Consistency',
      insight: 'Your cash flow is stable today. No abnormal category spikes or overruns detected.',
      recommendation: 'Check back tomorrow! We will analyze new entries for updates.',
      confidence: 0.90,
    );
  }

  /// Generates the list of Smart Context Alerts
  static List<SmartAlert> generateSmartAlerts({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> incomes,
    required List<Map<String, dynamic>> budgets,
    required List<Map<String, dynamic>> goals,
  }) {
    final alerts = <SmartAlert>[];
    final now = DateTime.now();

    final currentMonthExpenses = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
    final monthlyExpense = currentMonthExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    // 1. Food spending alert
    double foodSpend = 0.0;
    for (final e in currentMonthExpenses) {
      final cat = e['category']?.toString().toLowerCase() ?? '';
      if (cat.contains('food') || cat.contains('dine')) {
        foodSpend += _parseAmount(e['amount']);
      }
    }
    final double foodRatio = monthlyExpense > 0 ? (foodSpend / monthlyExpense) : 0.0;
    if (foodRatio > 0.25) {
      alerts.add(
        SmartAlert(
          id: 'alert_food',
          title: 'Food Spending High 🚨',
          message: 'Food and dining represents ${(foodRatio * 100).toStringAsFixed(0)}% of your monthly budget.',
          type: 'spending',
          severity: 'warning',
        ),
      );
    }

    // 2. Shopping doubled alert
    double shoppingSpend = 0.0;
    for (final e in currentMonthExpenses) {
      final cat = e['category']?.toString().toLowerCase() ?? '';
      if (cat.contains('shopping')) {
        shoppingSpend += _parseAmount(e['amount']);
      }
    }
    if (shoppingSpend > monthlyExpense * 0.20 && shoppingSpend > 3000) {
      alerts.add(
        SmartAlert(
          id: 'alert_shopping',
          title: 'Shopping Spend Alert 🛍️',
          message: 'Shopping expenses have increased significantly, taking up 20%+ of your outflows.',
          type: 'spending',
          severity: 'warning',
        ),
      );
    }

    // 3. Goal almost completed
    for (final g in goals) {
      final target = _parseAmount(g['targetAmount']);
      final current = _parseAmount(g['currentAmount']);
      if (target > 0 && current < target && (current / target) >= 0.85) {
        alerts.add(
          SmartAlert(
            id: 'alert_goal_${g['id']}',
            title: 'Goal Near Completion! 🎯',
            message: '"${g['name']}" is ${(current / target * 100).toStringAsFixed(0)}% completed. Almost there!',
            type: 'goal',
            severity: 'info',
          ),
        );
      }
    }

    // 4. Missing monthly income
    final monthlyIncomes = incomes.where((e) {
      final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    });
    if (monthlyIncomes.isEmpty && incomes.isNotEmpty) {
      alerts.add(
        const SmartAlert(
          id: 'alert_income_missing',
          title: 'No Inflows Logged ⚠️',
          message: 'You have not recorded any income transactions for the current month yet.',
          type: 'income',
          severity: 'warning',
        ),
      );
    }

    // 5. Budget overruns
    final categoryExpenses = <String, double>{};
    for (final e in currentMonthExpenses) {
      final cat = e['category']?.toString().toLowerCase() ?? 'other';
      categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
    }
    for (final b in budgets) {
      final cat = b['category']?.toString().toLowerCase() ?? '';
      final limit = _parseAmount(b['amount']);
      final spent = categoryExpenses[cat] ?? 0.0;
      if (cat.isNotEmpty && limit > 0 && spent > limit) {
        alerts.add(
          SmartAlert(
            id: 'alert_budget_$cat',
            title: 'Budget Limit Breached! 🚨',
            message: 'You have spent ₹${spent.toStringAsFixed(0)} of your ₹${limit.toStringAsFixed(0)} budget for $cat.',
            type: 'budget',
            severity: 'critical',
          ),
        );
      }
    }

    if (alerts.isEmpty) {
      alerts.add(
        const SmartAlert(
          id: 'alert_optimal',
          title: 'All Systems Nominal ✨',
          message: 'No risk alerts. Your expenses, budgets, and savings rates are within target limits.',
          type: 'info',
          severity: 'info',
        ),
      );
    }

    return alerts;
  }

  /// Generates the Weekly Financial Story
  static WeeklyStory generateWeeklyStory({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> incomes,
  }) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday of current week

    final currentWeekExpenses = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.isAfter(weekStart.subtract(const Duration(days: 1)));
    }).toList();
    final weekExpense = currentWeekExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    final currentWeekIncomes = incomes.where((e) {
      final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.isAfter(weekStart.subtract(const Duration(days: 1)));
    }).toList();
    final weekIncome = currentWeekIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    final double savings = weekIncome - weekExpense;

    // Previous week metrics (for comparison)
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));
    final prevWeekExpenses = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.isAfter(prevWeekStart.subtract(const Duration(days: 1))) && d.isBefore(weekStart);
    }).toList();
    final prevWeekExpense = prevWeekExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    // Build category stats for current vs previous week
    final catExpenses = <String, double>{};
    for (final e in currentWeekExpenses) {
      final cat = e['category']?.toString().toLowerCase() ?? 'other';
      catExpenses[cat] = (catExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
    }

    final prevCatExpenses = <String, double>{};
    for (final e in prevWeekExpenses) {
      final cat = e['category']?.toString().toLowerCase() ?? 'other';
      prevCatExpenses[cat] = (prevCatExpenses[cat] ?? 0.0) + _parseAmount(e['amount']);
    }

    final bullets = <String>[];
    String summary = 'Overall, this week was a stable period for your finances.';

    if (weekIncome > 0) {
      bullets.add('You earned ₹${weekIncome.toStringAsFixed(0)} in verified inflows.');
    } else {
      bullets.add('No cash inflows were recorded this week.');
    }

    bullets.add('You logged ₹${weekExpense.toStringAsFixed(0)} in outflows.');

    // Look for category differences
    final checkedCats = {'food', 'shopping', 'transport', 'entertainment'};
    for (final cat in checkedCats) {
      final current = catExpenses[cat] ?? 0.0;
      final prev = prevCatExpenses[cat] ?? 0.0;
      final name = cat.substring(0, 1).toUpperCase() + cat.substring(1);
      if (current > 0 && prev > 0) {
        if (current < prev) {
          bullets.add('$name spending decreased by ₹${(prev - current).toStringAsFixed(0)} compared to last week.');
        } else if (current > prev) {
          bullets.add('$name spending increased by ₹${(current - prev).toStringAsFixed(0)} compared to last week.');
        }
      } else if (current > 0 && prev == 0) {
        bullets.add('You started spending on $name this week (₹${current.toStringAsFixed(0)}).');
      }
    }

    if (savings > 0) {
      bullets.add('Your weekly reserves improved, accumulating positive net savings.');
      if (weekExpense < prevWeekExpense) {
        summary = 'Excellent performance! This was one of your strongest weeks: you cut expenditures and built reserves.';
      } else {
        summary = 'A very productive week! Positive inflows expanded your savings despite normal outflows.';
      }
    } else if (savings < 0 && weekIncome > 0) {
      bullets.add('Outflows exceeded income by ₹${savings.abs().toStringAsFixed(0)}.');
      summary = 'A capital-intensive week. You drew down some reserves, likely for essential billing cycles.';
    } else {
      summary = 'A quiet week in tracking. Keep logging transactions to stay consistent.';
    }

    return WeeklyStory(
      earned: weekIncome,
      spent: weekExpense,
      netSavings: savings,
      summary: summary,
      bulletPoints: bullets,
    );
  }
}
