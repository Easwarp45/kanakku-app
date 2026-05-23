import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/expenses/data/expense_service.dart';
import '../../features/income/data/income_service.dart';
import '../../features/budget/data/budget_service.dart';
import '../../features/insights/presentation/insights_screen.dart'; 
import '../../core/utils/multi_currency_helper.dart';
import './preferences_provider.dart';

/// Aggregates financial data across features to provide a high-level summary.
class FinancialSummary {
  final double walletBalance;
  final double monthlyBudget;
  final int healthScore;

  FinancialSummary({
    required this.walletBalance,
    required this.monthlyBudget,
    required this.healthScore,
  });
}

/// Provider that calculates a global financial summary including net balance,
/// total monthly budget, and a health score.
final financialSummaryProvider = Provider<FinancialSummary>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  final incomesAsync = ref.watch(incomeStreamProvider);
  final budgetsAsync = ref.watch(budgetsStreamProvider);
  final goals = ref.watch(localGoalsProvider);
  
  final expenses = expensesAsync.value ?? [];
  final incomes = incomesAsync.value ?? [];
  final budgets = budgetsAsync.value ?? [];
  
  final now = DateTime.now();

  // 1. Wallet Balance (Total Income - Total Expenses)
  double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  final totalIncome = incomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
  final totalExpense = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
  final walletBalance = totalIncome - totalExpense;

  // 2. Monthly Budget (Total of all budgets)
  final monthlyBudget = budgets.fold<double>(0, (sum, b) => sum + _parseAmount(b['amount']));

  // 3. Health Score (Logic from insights_screen.dart)
  final monthlyIncomes = incomes.where((e) {
    final d = DateTime.tryParse(e['income_date']?.toString() ?? e['created_at']?.toString() ?? '');
    return d != null && d.year == now.year && d.month == now.month;
  });
  final monthlyIncomeValue = monthlyIncomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

  final monthlyExpensesList = expenses.where((e) {
    final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
    return d != null && d.year == now.year && d.month == now.month;
  });
  final monthlyExpenseValue = monthlyExpensesList.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));

  final reserves = totalIncome - totalExpense;

  final double savingsRate = monthlyIncomeValue > 0 ? (monthlyIncomeValue - monthlyExpenseValue) / monthlyIncomeValue : 0;
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

  final avgMonthlyExpense = monthlyExpenseValue > 0 ? monthlyExpenseValue : 15000.0;
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

  // Apply currency conversion if necessary (though balance/budget are already in base/selected?)
  // Actually, typical providers in this app return converted values based on preference.
  // Let's check how many other providers do it.
  final pref = ref.watch(preferencesProvider);
  final code = supportedCurrencies[pref.currencyIndex].code;
  final rate = pref.rates[code] ?? 1.0;
  
  return FinancialSummary(
    walletBalance: walletBalance * rate,
    monthlyBudget: monthlyBudget * rate,
    healthScore: score,
  );
});
