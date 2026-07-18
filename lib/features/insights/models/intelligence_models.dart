import 'package:flutter/material.dart';

class DailyInsight {
  final String title;
  final String insight;
  final String recommendation;
  final double confidence; // 0.0 to 1.0

  const DailyInsight({
    required this.title,
    required this.insight,
    required this.recommendation,
    required this.confidence,
  });
}

class FinancialHealthScore {
  final int currentScore; // 0-100
  final int previousScore;
  final String reasonForChange;
  final List<String> improvementSuggestions;

  const FinancialHealthScore({
    required this.currentScore,
    required this.previousScore,
    required this.reasonForChange,
    required this.improvementSuggestions,
  });
}

class ForecastData {
  final double endOfMonthExpenses;
  final double predictedSavings;
  final double remainingBudget;
  final DateTime? goalCompletionDate;
  final Map<String, double> expectedCategorySpending;
  final double confidencePercentage; // e.g. 85.0

  const ForecastData({
    required this.endOfMonthExpenses,
    required this.predictedSavings,
    required this.remainingBudget,
    this.goalCompletionDate,
    required this.expectedCategorySpending,
    required this.confidencePercentage,
  });
}

class BudgetHealth {
  final String category;
  final bool isRisky;
  final double limit;
  final double spent;
  final String? overrunDate; // String representation or date
  final double remainingSafeSpending;
  final double dailyRecommendedSpending;

  const BudgetHealth({
    required this.category,
    required this.isRisky,
    required this.limit,
    required this.spent,
    this.overrunDate,
    required this.remainingSafeSpending,
    required this.dailyRecommendedSpending,
  });
}

class SavingsOpportunity {
  final String category;
  final String description;
  final double monthlySavingsPotential;
  final IconData icon;

  const SavingsOpportunity({
    required this.category,
    required this.description,
    required this.monthlySavingsPotential,
    required this.icon,
  });
}

class SpendingBehaviour {
  final bool isWeekendSpender;
  final bool isNightSpender;
  final bool isImpulseShopper;
  final bool isSalaryDaySpender;
  final String mostExpensiveWeekday;
  final int mostExpensiveHour; // 0-23
  final String favoriteCategory;
  final double averageTransactionValue;
  final double largestTransaction;
  final int longestNoSpendStreak;
  final int currentExpenseStreak;

  const SpendingBehaviour({
    required this.isWeekendSpender,
    required this.isNightSpender,
    required this.isImpulseShopper,
    required this.isSalaryDaySpender,
    required this.mostExpensiveWeekday,
    required this.mostExpensiveHour,
    required this.favoriteCategory,
    required this.averageTransactionValue,
    required this.largestTransaction,
    required this.longestNoSpendStreak,
    required this.currentExpenseStreak,
  });
}

class GoalPrediction {
  final String name;
  final double targetAmount;
  final double currentSaved;
  final DateTime? expectedCompletionDate;
  final double dailyAmountRequired;
  final double weeklyAmountRequired;
  final double probabilityOfSuccess; // 0.0 to 1.0
  final String fastestPath;
  final String delayRisk;
  final bool milestoneCelebration;

  const GoalPrediction({
    required this.name,
    required this.targetAmount,
    required this.currentSaved,
    this.expectedCompletionDate,
    required this.dailyAmountRequired,
    required this.weeklyAmountRequired,
    required this.probabilityOfSuccess,
    required this.fastestPath,
    required this.delayRisk,
    required this.milestoneCelebration,
  });
}

class WeeklyStory {
  final double earned;
  final double spent;
  final double netSavings;
  final String summary;
  final List<String> bulletPoints;

  const WeeklyStory({
    required this.earned,
    required this.spent,
    required this.netSavings,
    required this.summary,
    required this.bulletPoints,
  });
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final bool isUnlocked;
  final IconData icon;
  final Color color;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.isUnlocked,
    required this.icon,
    required this.color,
  });
}

class FinancialChallenge {
  final String id;
  final String name;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final bool isCompleted;
  final bool isActive;

  const FinancialChallenge({
    required this.id,
    required this.name,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    required this.isCompleted,
    required this.isActive,
  });
}

class RecurringSubscription {
  final String id;
  final String description;
  final String cleanName;
  final double amount;
  final DateTime dateDetected;
  final bool isConfirmed;
  final IconData icon;

  const RecurringSubscription({
    required this.id,
    required this.description,
    required this.cleanName,
    required this.amount,
    required this.dateDetected,
    required this.isConfirmed,
    required this.icon,
  });
}

class SmartAlert {
  final String id;
  final String title;
  final String message;
  final String type; // e.g. 'spending', 'budget', 'income', 'goal'
  final String severity; // 'info', 'warning', 'critical'

  const SmartAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
  });
}

class CoachingRecommendation {
  final String id;
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final Color color;

  const CoachingRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
  });
}

class MonthlyReportPreview {
  final double income;
  final double expense;
  final double savings;
  final String bestCategory;
  final String worstCategory;
  final int healthScore;
  final double endOfMonthForecast;
  final String oneSentenceSummary;

  const MonthlyReportPreview({
    required this.income,
    required this.expense,
    required this.savings,
    required this.bestCategory,
    required this.worstCategory,
    required this.healthScore,
    required this.endOfMonthForecast,
    required this.oneSentenceSummary,
  });
}
