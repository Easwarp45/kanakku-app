import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intelligence_models.dart';

class RecommendationEngine {
  static double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
  }

  static List<CoachingRecommendation> evaluate({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> incomes,
    required List<Map<String, dynamic>> budgets,
    required List<Map<String, dynamic>> goals,
  }) {
    final recommendations = <CoachingRecommendation>[];
    final now = DateTime.now();

    // Current month actuals
    final currentMonthExpenses = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
    final monthlyExpense = currentMonthExpenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));


    final totalIncome = incomes.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final totalExpense = expenses.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final reserves = totalIncome - totalExpense;

    final avgMonthlyExpense = monthlyExpense > 0 ? monthlyExpense : 15000.0;
    final runway = avgMonthlyExpense > 0 ? (reserves / avgMonthlyExpense) : 0.0;

    // 1. Check runway (Emergency Fund)
    if (runway < 3.0) {
      recommendations.add(
        const CoachingRecommendation(
          id: 'rec_runway',
          title: 'Establish Emergency Fund',
          description: 'Your capital runway is less than 3 months. Redirect 15% of monthly income to a liquid savings buffer.',
          category: 'Reserves',
          icon: LucideIcons.shieldAlert,
          color: Color(0xFFF43F5E),
        ),
      );
    }

    // 2. Check budgets configuration
    if (budgets.isEmpty) {
      recommendations.add(
        const CoachingRecommendation(
          id: 'rec_no_budget',
          title: 'Create Your First Budget',
          description: 'You do not have any spending limits set. Create a monthly category budget to prevent impulse bleed.',
          category: 'Planning',
          icon: LucideIcons.target,
          color: Color(0xFFFBBF24),
        ),
      );
    }

    // 3. Food Category check
    double foodSpend = 0.0;
    for (final e in currentMonthExpenses) {
      final cat = e['category']?.toString().toLowerCase() ?? '';
      if (cat.contains('food') || cat.contains('dine') || cat.contains('restaurant')) {
        foodSpend += _parseAmount(e['amount']);
      }
    }
    final double foodRatio = monthlyExpense > 0 ? (foodSpend / monthlyExpense) : 0.0;
    if (foodRatio > 0.25) {
      recommendations.add(
        const CoachingRecommendation(
          id: 'rec_food',
          title: 'Optimize Food Delivery',
          description: 'Dining out and food orders make up over 25% of your expenses. Cook at home on weekdays to save up to ₹3,500/month.',
          category: 'Lifestyle',
          icon: LucideIcons.pizza,
          color: Color(0xFFF97316),
        ),
      );
    }

    // 4. Subscriptions ratio check
    final keywords = ['spotify', 'netflix', 'youtube', 'prime', 'gym', 'rent', 'broadband', 'adobe'];
    final subs = expenses.where((e) {
      final desc = e['description']?.toString().toLowerCase() ?? '';
      return keywords.any((kw) => desc.contains(kw));
    }).toList();
    final double subTotal = subs.fold<double>(0, (sum, e) => sum + _parseAmount(e['amount']));
    final double subRatio = monthlyExpense > 0 ? (subTotal / monthlyExpense) : 0.0;

    if (subRatio > 0.15 && subTotal > 1500) {
      recommendations.add(
        const CoachingRecommendation(
          id: 'rec_subs',
          title: 'Consolidate Subscriptions',
          description: 'Recurring payments consume over 15% of your cash outflow. Cancel unused memberships or group subscriptions.',
          category: 'Bills',
          icon: LucideIcons.refreshCcw,
          color: Color(0xFFA855F7),
        ),
      );
    }

    // 5. Surplus cash investment check
    final hasInvestment = expenses.any((e) {
      final desc = e['description']?.toString().toLowerCase() ?? '';
      final cat = e['category']?.toString().toLowerCase() ?? '';
      return cat.contains('invest') || desc.contains('invest') || desc.contains('sip') || desc.contains('mutual fund');
    });
    if (reserves > 20000.0 && !hasInvestment) {
      recommendations.add(
        const CoachingRecommendation(
          id: 'rec_invest',
          title: 'Deploy Idle Capital',
          description: 'You have a healthy surplus of cash. Set up a mutual fund SIP or index fund transfer to beat inflation.',
          category: 'Investing',
          icon: LucideIcons.trendingUp,
          color: Color(0xFF10B981),
        ),
      );
    }

    // Default fallbacks to guarantee at least 2 personalized coaching items
    if (recommendations.length < 2) {
      recommendations.add(
        const CoachingRecommendation(
          id: 'rec_savings_rate',
          title: 'Aim for 30% Savings Rate',
          description: 'Try saving 30% of your earnings next month. Set up automated savings on salary day.',
          category: 'Wealth',
          icon: LucideIcons.piggyBank,
          color: Color(0xFF06B6D4),
        ),
      );
      recommendations.add(
        const CoachingRecommendation(
          id: 'rec_no_spend',
          title: 'Plan a No-Spend Weekend',
          description: 'Try a weekend with zero non-essential spending. Explore parks or read books to refresh without spending.',
          category: 'Discipline',
          icon: LucideIcons.calendar,
          color: Color(0xFF6366F1),
        ),
      );
    }

    return recommendations;
  }
}
