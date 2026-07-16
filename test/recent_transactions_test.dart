import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanakku_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:kanakku_flutter/features/expenses/data/expense_service.dart';
import 'package:kanakku_flutter/features/income/data/income_service.dart';

void main() {
  group('recentCombinedTransactionsProvider Tests', () {
    test('Empty inputs - emits empty list', () {
      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWithValue(const AsyncValue.data([])),
          incomeStreamProvider.overrideWithValue(const AsyncValue.data([])),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(recentCombinedTransactionsProvider);
      expect(result.value, isEmpty);
    });

    test('Happy path - merges, sorts descending by date, and filters to current month', () {
      final now = DateTime.now();
      final currentMonthStr = now.toIso8601String();
      final currentMonthMinus1DayStr = now.subtract(const Duration(days: 1)).toIso8601String();
      final currentMonthMinus2DaysStr = now.subtract(const Duration(days: 2)).toIso8601String();
      
      final prevMonthStr = DateTime(now.year, now.month - 1, 15).toIso8601String();

      final mockExpenses = [
        {
          'id': 'exp1',
          'amount': 150.0,
          'description': 'Lunch',
          'expense_date': currentMonthMinus1DayStr,
        },
        {
          'id': 'exp2',
          'amount': 50.0,
          'description': 'Coffee',
          'expense_date': prevMonthStr, // Should be filtered out (previous month)
        },
      ];

      final mockIncomes = [
        {
          'id': 'inc1',
          'amount': 1000.0,
          'description': 'Salary',
          'income_date': currentMonthStr, // Most recent
        },
        {
          'id': 'inc2',
          'amount': 200.0,
          'description': 'Freelance',
          'income_date': currentMonthMinus2DaysStr,
        },
      ];

      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWithValue(AsyncValue.data(mockExpenses)),
          incomeStreamProvider.overrideWithValue(AsyncValue.data(mockIncomes)),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(recentCombinedTransactionsProvider);
      final list = result.value!;

      // Should have 3 transactions (exp2 filtered out)
      expect(list.length, 3);

      // Verify sorting descending: inc1 (currentMonth) -> exp1 (minus 1 day) -> inc2 (minus 2 days)
      expect(list[0]['id'], 'inc1');
      expect(list[0]['is_income'], true);
      expect(list[1]['id'], 'exp1');
      expect(list[1]['is_legacy_expense'], true);
      expect(list[2]['id'], 'inc2');
    });

    test('Cap at 5 items - returns only top 5 most recent', () {
      final now = DateTime.now();
      final mockExpenses = List.generate(10, (index) => {
        'id': 'exp_$index',
        'amount': 10.0 + index,
        'description': 'Item $index',
        'expense_date': now.subtract(Duration(minutes: index)).toIso8601String(),
      });

      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWithValue(AsyncValue.data(mockExpenses)),
          incomeStreamProvider.overrideWithValue(const AsyncValue.data([])),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(recentCombinedTransactionsProvider);
      final list = result.value!;

      expect(list.length, 5);
      // Index 0 should be the most recent (exp_0)
      expect(list[0]['id'], 'exp_0');
      expect(list[4]['id'], 'exp_4');
    });

    test('Invalid/Null dates - handled gracefully without crash', () {
      final now = DateTime.now();
      final mockExpenses = [
        {
          'id': 'exp_null',
          'amount': 10.0,
          'description': 'Null Date',
          'expense_date': null, // tryParse returns null -> will be filtered out as not current month
        },
        {
          'id': 'exp_invalid',
          'amount': 20.0,
          'description': 'Invalid Date Format',
          'expense_date': 'not-a-date', // tryParse returns null -> filtered out
        },
        {
          'id': 'exp_valid',
          'amount': 30.0,
          'description': 'Valid Date',
          'expense_date': now.toIso8601String(), // Retained
        }
      ];

      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWithValue(AsyncValue.data(mockExpenses)),
          incomeStreamProvider.overrideWithValue(const AsyncValue.data([])),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(recentCombinedTransactionsProvider);
      final list = result.value!;

      expect(list.length, 1);
      expect(list[0]['id'], 'exp_valid');
    });
  });
}
