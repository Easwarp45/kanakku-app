import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intelligence_models.dart';

class AchievementEngine {
  static double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  static List<Achievement> evaluate({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> incomes,
    required List<Map<String, dynamic>> budgets,
    required List<Map<String, dynamic>> goals,
    required int currentStreak,
  }) {
    final now = DateTime.now();

    // Compute basic helper values
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

    final totalIncome = incomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final totalExpense = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final totalSavings = totalIncome - totalExpense;

    // Check budget overruns
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

    final hasCompletedGoal = goals.any((g) {
      final target = _parseAmount(g['targetAmount']);
      final current = _parseAmount(g['currentAmount']);
      return target > 0 && current >= target;
    });

    final hasInvestment = expenses.any((e) {
      final desc = e['description']?.toString().toLowerCase() ?? '';
      final cat = e['category']?.toString().toLowerCase() ?? '';
      return cat.contains('invest') || 
             desc.contains('invest') || 
             desc.contains('mutual fund') || 
             desc.contains('sip') || 
             desc.contains('stocks');
    });

    final savingsRate = monthlyIncome > 0 ? (monthlyIncome - monthlyExpense) / monthlyIncome : 0.0;

    return [
      Achievement(
        id: 'streak_7',
        name: '7 Day Streak',
        description: 'Log no excessive spending or log inputs consistently for 7 days.',
        isUnlocked: currentStreak >= 7,
        icon: LucideIcons.flame,
        color: const Color(0xFFF97316),
      ),
      Achievement(
        id: 'streak_30',
        name: '30 Day Streak',
        description: 'Log inputs or maintain savings discipline for 30 consecutive days.',
        isUnlocked: currentStreak >= 30,
        icon: LucideIcons.award,
        color: const Color(0xFFA855F7),
      ),
      Achievement(
        id: 'under_budget',
        name: 'Budget Master',
        description: 'Keep all category budgets fully green this month.',
        isUnlocked: budgets.isNotEmpty && overruns == 0,
        icon: LucideIcons.target,
        color: const Color(0xFF10B981),
      ),
      Achievement(
        id: 'saved_10k',
        name: 'Super Saver',
        description: 'Reach ₹10,000 in total lifetime savings reserves.',
        isUnlocked: totalSavings >= 10000,
        icon: LucideIcons.piggyBank,
        color: const Color(0xFF06B6D4),
      ),
      Achievement(
        id: 'completed_goal',
        name: 'Dream Builder',
        description: 'Hit 100% target progress on any financial savings goal.',
        isUnlocked: hasCompletedGoal,
        icon: LucideIcons.trophy,
        color: const Color(0xFFFBBF24),
      ),
      Achievement(
        id: 'first_income',
        name: 'First Income',
        description: 'Successfully deposit your first cash earnings inflow.',
        isUnlocked: incomes.isNotEmpty,
        icon: LucideIcons.wallet,
        color: const Color(0xFF3B82F6),
      ),
      Achievement(
        id: 'first_investment',
        name: 'Wealth Builder',
        description: 'Log your first wealth asset or long-term market investment.',
        isUnlocked: hasInvestment,
        icon: LucideIcons.trendingUp,
        color: const Color(0xFFEC4899),
      ),
      Achievement(
        id: 'logged_100',
        name: 'Centurion',
        description: 'Track 100 total transactions in your financial logs.',
        isUnlocked: expenses.length + incomes.length >= 100,
        icon: LucideIcons.fileSpreadsheet,
        color: const Color(0xFF14B8A6),
      ),
      Achievement(
        id: 'perfect_month',
        name: 'Perfect Month',
        description: 'No budget overruns and save >= 25% of your income this month.',
        isUnlocked: monthlyIncome > 0 && overruns == 0 && savingsRate >= 0.25,
        icon: LucideIcons.sparkles,
        color: const Color(0xFFF43F5E),
      ),
    ];
  }
}
