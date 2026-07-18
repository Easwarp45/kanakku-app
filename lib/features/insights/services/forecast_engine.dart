import 'dart:math';
import '../models/intelligence_models.dart';

class ForecastEngine {
  static double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  static ForecastData run({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> incomes,
    required List<Map<String, dynamic>> budgets,
    required List<Map<String, dynamic>> goals,
  }) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;

    // Current month actuals
    final currentMonthExpenses = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
    final monthlyExpense = currentMonthExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    final currentMonthIncomes = incomes.where((e) {
      final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
    final monthlyIncome = currentMonthIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

    // 1. End-of-month expense projection using daily burn rate
    // Prevent division by zero if it's day 1, or if we have high spikes
    final runDays = max(1, currentDay);
    final double dailyBurnRate = monthlyExpense / runDays;
    double projectedExpenses = dailyBurnRate * daysInMonth;

    // If there is historical average expense, let's mix it (Bayesian shrinkage)
    final totalExpense = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final totalDays = expenses.isNotEmpty ? 90.0 : 1.0; // Assume 90 day sample
    final double historicalDailyBurn = totalExpense / totalDays;

    if (expenses.length > 10) {
      // 70% current run rate + 30% historical base
      projectedExpenses = (dailyBurnRate * 0.7 + historicalDailyBurn * 0.3) * daysInMonth;
    }

    // Adjust in case projected expenses are lower than already spent
    projectedExpenses = max(monthlyExpense, projectedExpenses);

    // 2. Projected Monthly Income
    // Income is usually discrete (salary once a month).
    // Let's assume income remains at least what we earned, or historical average.
    final totalIncome = incomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final historicalMonthlyIncome = incomes.isNotEmpty ? (totalIncome / max(1.0, incomes.length / 2.0)) : 0.0;
    final double projectedIncome = max(monthlyIncome, historicalMonthlyIncome > 0 ? historicalMonthlyIncome : monthlyIncome);

    // 3. Predicted Savings
    final double predictedSavings = max(0.0, projectedIncome - projectedExpenses);

    // 4. Remaining Budget Forecast
    final double totalBudgetLimit = budgets.fold<double>(0, (sum, b) => sum + _parseAmount(b['amount']));
    final double remainingBudget = max(0.0, totalBudgetLimit - monthlyExpense);

    // 5. Expected Category spending
    final expectedCategorySpending = <String, double>{};
    final categoryExpenses = <String, double>{};
    for (final e in currentMonthExpenses) {
      final cat = e['category']?.toString() ?? 'other';
      final cleanCat = cat.substring(0, 1).toUpperCase() + cat.substring(1).toLowerCase();
      categoryExpenses[cleanCat] = (categoryExpenses[cleanCat] ?? 0.0) + _parseAmount(e['amount']);
    }

    for (final b in budgets) {
      final cat = b['category']?.toString() ?? '';
      if (cat.isEmpty) continue;
      final cleanCat = cat.substring(0, 1).toUpperCase() + cat.substring(1).toLowerCase();
      final spent = categoryExpenses[cleanCat] ?? 0.0;
      final limit = _parseAmount(b['amount']);
      
      // Predict by projecting category spending
      double predictedCatSpent = (spent / runDays) * daysInMonth;
      // Shrink towards budget limit or historical spend
      predictedCatSpent = max(spent, (predictedCatSpent * 0.8 + limit * 0.2));
      expectedCategorySpending[cleanCat] = predictedCatSpent;
    }

    // 6. Goal Completion Date Projection
    DateTime? goalCompletionDate;
    if (goals.isNotEmpty) {
      // Find the first goal that is not completed
      final incompleteGoals = goals.where((g) {
        final target = _parseAmount(g['targetAmount']);
        final current = _parseAmount(g['currentAmount']);
        return current < target;
      }).toList();

      if (incompleteGoals.isNotEmpty) {
        final primaryGoal = incompleteGoals.first;
        final target = _parseAmount(primaryGoal['targetAmount']);
        final current = _parseAmount(primaryGoal['currentAmount']);
        final needed = target - current;

        // Daily savings rate
        // We use projected monthly savings or fallback to a standard save rate
        final double monthlySaveRate = predictedSavings > 0 ? predictedSavings : (projectedIncome * 0.20 > 0 ? projectedIncome * 0.20 : 5000.0);
        final double dailySaveRate = monthlySaveRate / 30.0;

        if (dailySaveRate > 0) {
          final daysToComplete = (needed / dailySaveRate).ceil();
          // Cap at 5 years for sanity
          final clampedDays = min(365 * 5, daysToComplete);
          goalCompletionDate = now.add(Duration(days: clampedDays));
        }
      }
    }

    // 7. Confidence Score
    // Decreases if we have fewer than 10 transactions. Increases as the month advances.
    double confidence = 50.0;
    if (expenses.length > 20) {
      confidence += 20;
    } else if (expenses.length > 5) {
      confidence += 10;
    }
    // High day in month = higher certainty
    confidence += (currentDay / daysInMonth) * 25;
    confidence = confidence.clamp(60.0, 98.0);

    return ForecastData(
      endOfMonthExpenses: projectedExpenses,
      predictedSavings: predictedSavings,
      remainingBudget: remainingBudget,
      goalCompletionDate: goalCompletionDate,
      expectedCategorySpending: expectedCategorySpending,
      confidencePercentage: confidence,
    );
  }
}
