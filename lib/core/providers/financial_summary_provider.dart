import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/expenses/data/expense_service.dart';
import '../../features/income/data/income_service.dart';
import '../../features/budget/data/budget_service.dart';
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

// Internal data model for the raw (pre-currency) score computation.
class _RawFinancialData {
  final double walletBalance;
  final double monthlyBudget;
  final int healthScore;
  const _RawFinancialData(this.walletBalance, this.monthlyBudget, this.healthScore);
}

// Why _financialScoreProvider is split out: The old single provider ran 5+ list
// folds, date-parsing loops, and category aggregation every time expenses, incomes,
// budgets, OR preferences changed. Currency preference changes (which happen when
// users switch between INR/USD/EUR) shouldn't retrigger the entire expensive
// computation — they only need to rescale the final numbers. Splitting here means:
//   - Heavy CPU work runs only when actual financial data changes.
//   - Currency rescaling runs only when the user switches currency.
//   - keepAlive preserves the computed result across screen navigations so the
//     profile screen loads instantly on revisit.
final _financialScoreProvider = Provider<_RawFinancialData>((ref) {
  ref.keepAlive();

  final expensesAsync = ref.watch(expensesStreamProvider);
  final incomesAsync = ref.watch(incomeStreamProvider);
  final budgetsAsync = ref.watch(budgetsStreamProvider);

  final expenses = expensesAsync.value ?? [];
  final incomes = incomesAsync.value ?? [];
  final budgets = budgetsAsync.value ?? [];

  final now = DateTime.now();

  double parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  // 1. Wallet Balance (Total Income - Total Expenses, all-time)
  final totalIncome = incomes.fold<double>(0, (sum, e) => sum + parseAmount(e['amount']));
  final totalExpense = expenses.fold<double>(0, (sum, e) => sum + parseAmount(e['amount']));
  final walletBalance = totalIncome - totalExpense;

  // 2. Monthly Budget (sum of all active budget limits)
  final monthlyBudget = budgets.fold<double>(0, (sum, b) => sum + parseAmount(b['amount']));

  // 3. Health Score — filter to current month once, reuse for both income and expense lists.
  final monthlyIncomes = incomes.where((e) {
    final d = DateTime.tryParse(e['income_date']?.toString() ?? e['created_at']?.toString() ?? '');
    return d != null && d.year == now.year && d.month == now.month;
  }).toList();
  final monthlyExpensesList = expenses.where((e) {
    final d = DateTime.tryParse(e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '');
    return d != null && d.year == now.year && d.month == now.month;
  }).toList();

  final monthlyIncomeValue = monthlyIncomes.fold<double>(0, (sum, e) => sum + parseAmount(e['amount']));
  final monthlyExpenseValue = monthlyExpensesList.fold<double>(0, (sum, e) => sum + parseAmount(e['amount']));

  // Savings rate score (0–40 pts)
  final double savingsRate = monthlyIncomeValue > 0
      ? (monthlyIncomeValue - monthlyExpenseValue) / monthlyIncomeValue
      : 0;
  final int savingsScore = (savingsRate.clamp(0.0, 1.0) * 40).round();

  // Budget overrun score (0–30 pts)
  final categoryExpenses = <String, double>{};
  for (final e in monthlyExpensesList) {
    final cat = e['category']?.toString().toLowerCase() ?? 'other';
    categoryExpenses[cat] = (categoryExpenses[cat] ?? 0.0) + parseAmount(e['amount']);
  }
  int overruns = 0;
  int budgetCount = 0;
  for (final b in budgets) {
    final cat = b['category']?.toString().toLowerCase() ?? '';
    final limit = parseAmount(b['amount']);
    if (cat.isNotEmpty && limit > 0) {
      budgetCount++;
      if ((categoryExpenses[cat] ?? 0.0) > limit) overruns++;
    }
  }
  int budgetScore = 30;
  if (budgetCount > 0) {
    budgetScore = (30 * (1.0 - overruns / budgetCount)).round();
  }

  // Runway score (0–30 pts): how many months the user can sustain current spending.
  final avgMonthlyExpense = monthlyExpenseValue > 0 ? monthlyExpenseValue : 15000.0;
  final runwayMonths = avgMonthlyExpense > 0 ? walletBalance / avgMonthlyExpense : 0.0;
  final int runwayScore = runwayMonths >= 6
      ? 30
      : runwayMonths >= 3
          ? 20
          : runwayMonths >= 1
              ? 10
              : 5;

  final score = (savingsScore + budgetScore + runwayScore).clamp(10, 100);
  return _RawFinancialData(walletBalance, monthlyBudget, score);
});

/// Provider that exposes a global financial summary with currency applied.
/// Watches only the raw score provider + currency preference — so a currency
/// change rescales numbers without rerunning the heavy fold/parse computation.
final financialSummaryProvider = Provider<FinancialSummary>((ref) {
  final raw = ref.watch(_financialScoreProvider);
  // Using .select() to watch only currencyIndex and rates — avoids rebuilding
  // when other prefs (appLock, avatar, passcode, theme) change.
  final currencyIndex = ref.watch(preferencesProvider.select((p) => p.currencyIndex));
  final rates = ref.watch(preferencesProvider.select((p) => p.rates));
  final code = supportedCurrencies[currencyIndex].code;
  final rate = rates[code] ?? 1.0;

  return FinancialSummary(
    walletBalance: raw.walletBalance * rate,
    monthlyBudget: raw.monthlyBudget * rate,
    healthScore: raw.healthScore,
  );
});
