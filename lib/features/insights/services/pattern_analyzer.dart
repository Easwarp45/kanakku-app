import 'dart:math';

import '../models/intelligence_models.dart';

class PatternAnalyzer {
  static double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  static SpendingBehaviour analyze({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> incomes,
  }) {
    if (expenses.isEmpty) {
      return const SpendingBehaviour(
        isWeekendSpender: false,
        isNightSpender: false,
        isImpulseShopper: false,
        isSalaryDaySpender: false,
        mostExpensiveWeekday: 'None',
        mostExpensiveHour: -1,
        favoriteCategory: 'None',
        averageTransactionValue: 0.0,
        largestTransaction: 0.0,
        longestNoSpendStreak: 0,
        currentExpenseStreak: 0,
      );
    }

    final now = DateTime.now();

    // 1. Basic Stats
    double totalExpensesAmount = 0.0;
    double largestTransaction = 0.0;
    final categoryCounts = <String, int>{};
    final categoryTotals = <String, double>{};
    
    // Day of week spending
    final weekdayTotals = List<double>.filled(8, 0.0); // 1 = Monday, 7 = Sunday
    // Hour of day spending
    final hourTotals = List<double>.filled(24, 0.0);
    final hourCounts = List<int>.filled(24, 0);

    double weekendExpenses = 0.0;
    double nightExpenses = 0.0;
    int nightCount = 0;

    for (final e in expenses) {
      final amt = _parseAmount(e['amount']);
      totalExpensesAmount += amt;
      if (amt > largestTransaction) {
        largestTransaction = amt;
      }

      final cat = e['category']?.toString() ?? 'other';
      final cleanCat = cat.substring(0, 1).toUpperCase() + cat.substring(1).toLowerCase();
      categoryCounts[cleanCat] = (categoryCounts[cleanCat] ?? 0) + 1;
      categoryTotals[cleanCat] = (categoryTotals[cleanCat] ?? 0.0) + amt;

      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      if (d != null) {
        weekdayTotals[d.weekday] += amt;
        hourTotals[d.hour] += amt;
        hourCounts[d.hour]++;

        if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
          weekendExpenses += amt;
        }

        // Night is between 8 PM (20:00) and 6 AM (6:00)
        if (d.hour >= 20 || d.hour < 6) {
          nightExpenses += amt;
          nightCount++;
        }
      }
    }

    final double averageTransactionValue = totalExpensesAmount / expenses.length;

    // 2. Behavioral Flags
    // Weekend Spender: Sat/Sun spending is > 35% of total spending
    final bool isWeekendSpender = totalExpensesAmount > 0 && (weekendExpenses / totalExpensesAmount) > 0.35;

    // Night Spender: Night spending is > 20% of total amount or count
    final bool isNightSpender = expenses.isNotEmpty && 
        ((nightExpenses / totalExpensesAmount) > 0.20 || (nightCount / expenses.length) > 0.20);

    // Impulse Shopper: If shopping has high totals or average shopping transaction is higher than average transaction value
    final shoppingTotal = categoryTotals['Shopping'] ?? 0.0;
    final shoppingCount = categoryCounts['Shopping'] ?? 0;
    final avgShopping = shoppingCount > 0 ? (shoppingTotal / shoppingCount) : 0.0;
    final bool isImpulseShopper = avgShopping > averageTransactionValue * 1.5 || 
        (totalExpensesAmount > 0 && (shoppingTotal / totalExpensesAmount) > 0.30);

    // Salary Day Spender: Check if they spend significantly within 3 days of receiving an income
    bool isSalaryDaySpender = false;
    for (final inc in incomes) {
      final incDateStr = inc['income_date']?.toString() ?? inc['created_at']?.toString() ?? '';
      final incDate = DateTime.tryParse(incDateStr);
      if (incDate != null) {
        // Look for expenses in the 3 days after this income
        double salaryDaySpend = 0.0;
        for (final exp in expenses) {
          final expDateStr = exp['expense_date']?.toString() ?? exp['created_at']?.toString() ?? '';
          final expDate = DateTime.tryParse(expDateStr);
          if (expDate != null) {
            final diff = expDate.difference(incDate).inDays;
            if (diff >= 0 && diff <= 3) {
              salaryDaySpend += _parseAmount(exp['amount']);
            }
          }
        }
        if (salaryDaySpend > averageTransactionValue * 5) {
          isSalaryDaySpender = true;
          break;
        }
      }
    }

    // 3. Find Most Expensive Weekday and Hour
    int maxWeekdayIdx = 1;
    double maxWeekdayAmt = 0.0;
    for (int i = 1; i <= 7; i++) {
      if (weekdayTotals[i] > maxWeekdayAmt) {
        maxWeekdayAmt = weekdayTotals[i];
        maxWeekdayIdx = i;
      }
    }
    final weekdays = ['None', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final String mostExpensiveWeekday = maxWeekdayAmt > 0 ? weekdays[maxWeekdayIdx] : 'None';

    int mostExpensiveHour = -1;
    double maxHourAmt = 0.0;
    for (int h = 0; h < 24; h++) {
      if (hourTotals[h] > maxHourAmt) {
        maxHourAmt = hourTotals[h];
        mostExpensiveHour = h;
      }
    }

    // Favorite Category
    String favoriteCategory = 'None';
    int maxCatCount = 0;
    for (final entry in categoryCounts.entries) {
      if (entry.value > maxCatCount) {
        maxCatCount = entry.value;
        favoriteCategory = entry.key;
      }
    }

    // 4. Calculate Streaks
    // Get unique dates for expenses (sorted ascending)
    final expenseDates = expenses.map((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null ? DateTime(d.year, d.month, d.day) : null;
    }).whereType<DateTime>().toSet().toList()
      ..sort((a, b) => a.compareTo(b));

    int currentExpenseStreak = 0;
    int longestNoSpendStreak = 0;

    if (expenseDates.isNotEmpty) {
      // Current Streak (consecutive days with spending ending today/yesterday)
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      
      bool hasStreakSeed = expenseDates.contains(today) || expenseDates.contains(yesterday);
      if (hasStreakSeed) {
        int tempStreak = 0;
        DateTime checkDate = expenseDates.contains(today) ? today : yesterday;
        while (expenseDates.contains(checkDate)) {
          tempStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
        currentExpenseStreak = tempStreak;
      }

      // Longest No-spend streak: maximum gap between consecutive expense dates
      int maxGap = 0;
      // Also check gap between first expense and beginning of timeline (e.g. 30 days ago), or just consecutive items
      for (int i = 0; i < expenseDates.length - 1; i++) {
        final gap = expenseDates[i + 1].difference(expenseDates[i]).inDays - 1;
        if (gap > maxGap) {
          maxGap = gap;
        }
      }
      // Also check gap from last expense to today
      final lastGap = today.difference(expenseDates.last).inDays - 1;
      if (lastGap > maxGap) {
        maxGap = lastGap;
      }
      longestNoSpendStreak = max(0, maxGap);
    } else {
      longestNoSpendStreak = 30; // No spend at all
    }

    return SpendingBehaviour(
      isWeekendSpender: isWeekendSpender,
      isNightSpender: isNightSpender,
      isImpulseShopper: isImpulseShopper,
      isSalaryDaySpender: isSalaryDaySpender,
      mostExpensiveWeekday: mostExpensiveWeekday,
      mostExpensiveHour: mostExpensiveHour,
      favoriteCategory: favoriteCategory,
      averageTransactionValue: averageTransactionValue,
      largestTransaction: largestTransaction,
      longestNoSpendStreak: longestNoSpendStreak,
      currentExpenseStreak: currentExpenseStreak,
    );
  }
}
