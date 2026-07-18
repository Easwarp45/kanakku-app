import 'package:flutter_test/flutter_test.dart';
import 'package:kanakku_flutter/features/insights/services/financial_score_calculator.dart';
import 'package:kanakku_flutter/features/insights/services/pattern_analyzer.dart';
import 'package:kanakku_flutter/features/insights/services/forecast_engine.dart';
import 'package:kanakku_flutter/features/insights/services/achievement_engine.dart';

void main() {
  group('FinancialScoreCalculator Tests', () {
    test('calculate returns healthy score when no overruns and high savings rate', () {
      final incomes = [
        {'amount': 50000.0, 'income_date': '2026-07-01'}
      ];
      final expenses = [
        {'amount': 15000.0, 'expense_date': '2026-07-05', 'category': 'food'}
      ];
      final budgets = [
        {'amount': 5000.0, 'category': 'food'}
      ];

      final score = FinancialScoreCalculator.calculate(
        expenses: expenses,
        incomes: incomes,
        budgets: budgets,
      );
      expect(score.currentScore, greaterThan(0));

      // Savings rate = (50000 - 15000) / 50000 = 70% (>= 30% gets full savings score: 40)
      // Budget adherence: no budgets exceeded (food has limit 5000, but spent is 15000 - wait, spent 15000 > limit 5000, so it exceeded!)
      // Let's make food spent 3000 to keep under budget
      final expensesHealthy = [
        {'amount': 3000.0, 'expense_date': '2026-07-05', 'category': 'food'}
      ];
      final scoreHealthy = FinancialScoreCalculator.calculate(
        expenses: expensesHealthy,
        incomes: incomes,
        budgets: budgets,
      );

      expect(scoreHealthy.currentScore, greaterThanOrEqualTo(60));
    });

    test('calculate returns critical score when savings rate is negative', () {
      final incomes = [
        {'amount': 10000.0, 'income_date': '2026-07-01'}
      ];
      final expenses = [
        {'amount': 20000.0, 'expense_date': '2026-07-05', 'category': 'food'}
      ];

      final score = FinancialScoreCalculator.calculate(
        expenses: expenses,
        incomes: incomes,
        budgets: [],
      );

      // Negative savings rate gets 0 points. Runway is low. Score should be low.
      expect(score.currentScore, lessThan(40));
    });
  });

  group('PatternAnalyzer Tests', () {
    test('detects weekend spending spikes correctly', () {
      final expenses = [
        {'amount': 5000.0, 'expense_date': '2026-07-18'}, // Saturday
        {'amount': 5000.0, 'expense_date': '2026-07-19'}, // Sunday
        {'amount': 2000.0, 'expense_date': '2026-07-20'}, // Monday
      ];

      final behaviour = PatternAnalyzer.analyze(expenses: expenses, incomes: []);

      // Weekend spending: 10000 / 12000 = 83.3% (> 35%)
      expect(behaviour.isWeekendSpender, isTrue);
    });

    test('detects late night spending correctly', () {
      final expenses = [
        {'amount': 1000.0, 'expense_date': '2026-07-20T23:30:00'}, // Night
        {'amount': 1000.0, 'expense_date': '2026-07-21T01:15:00'}, // Night
        {'amount': 500.0, 'expense_date': '2026-07-22T12:00:00'}, // Day
      ];

      final behaviour = PatternAnalyzer.analyze(expenses: expenses, incomes: []);

      // Night transactions count: 2 out of 3 = 66% (> 20%)
      expect(behaviour.isNightSpender, isTrue);
    });
  });

  group('ForecastEngine Tests', () {
    test('projects future expenses and goal completion dates correctly', () {
      final now = DateTime.now();
      final incomes = [
        {'amount': 50000.0, 'income_date': now.toIso8601String()}
      ];
      final expenses = [
        {'amount': 1000.0, 'expense_date': now.toIso8601String(), 'category': 'food'}
      ];
      final goals = [
        {'targetAmount': 20000.0, 'currentAmount': 5000.0, 'name': 'New Laptop'}
      ];

      final forecast = ForecastEngine.run(
        expenses: expenses,
        incomes: incomes,
        budgets: [],
        goals: goals,
      );

      // Remaining budget should equal 0 if budgets is empty
      expect(forecast.remainingBudget, 0.0);
      expect(forecast.endOfMonthExpenses, greaterThan(0.0));
      expect(forecast.goalCompletionDate, isNotNull);
    });
  });

  group('AchievementEngine Tests', () {
    test('unlocks achievement when goals are completed', () {
      final goals = [
        {'targetAmount': 5000.0, 'currentAmount': 5000.0, 'name': 'Savings Goal'}
      ];

      final achievements = AchievementEngine.evaluate(
        expenses: [],
        incomes: [],
        budgets: [],
        goals: goals,
        currentStreak: 0,
      );

      final dreamBuilder = achievements.firstWhere((a) => a.id == 'completed_goal');
      expect(dreamBuilder.isUnlocked, isTrue);
    });

    test('locks achievement when savings goal is incomplete', () {
      final goals = [
        {'targetAmount': 10000.0, 'currentAmount': 4000.0, 'name': 'Savings Goal'}
      ];

      final achievements = AchievementEngine.evaluate(
        expenses: [],
        incomes: [],
        budgets: [],
        goals: goals,
        currentStreak: 0,
      );

      final dreamBuilder = achievements.firstWhere((a) => a.id == 'completed_goal');
      expect(dreamBuilder.isUnlocked, isFalse);
    });
  });
}
