import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../expenses/data/expense_service.dart';
import '../data/budget_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';

import '../../expenses/data/expense_service.dart';
import '../data/budget_service.dart';
import 'widgets/budget_form_sheet.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  String _selectedFilter = 'All'; // All, Over Budget, On Track

  void _showAddBudget() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BudgetFormSheet(),
    );
  }

  void _editBudget(Map<String, dynamic> budget) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BudgetFormSheet(budget: budget),
    );
  }

  Future<void> _deleteBudget(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Deauthorize Budget', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to terminate this budget constraint?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminate', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(budgetServiceProvider).deleteBudget(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget constraint purged.'), backgroundColor: AppColors.bgSecondary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.bgSecondary.withValues(alpha: 0.5), shape: BoxShape.circle),
            child: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text('Budget Intelligence', style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.bgSecondary.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: const Icon(LucideIcons.settings2, color: AppColors.textSecondary, size: 20),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudget,
        backgroundColor: AppColors.accentPurple,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgPrimary, Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: budgetsAsync.when(
          data: (budgets) {
            return expensesAsync.when(
              data: (expenses) {
                return _buildContent(budgets, expenses);
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentPurple)),
              error: (e, s) => Center(child: Text('Data Breach: $e', style: const TextStyle(color: AppColors.accentRose))),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentPurple)),
          error: (e, s) => Center(child: Text('System Error: $e', style: const TextStyle(color: AppColors.accentRose))),
        ),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> budgets, List<Map<String, dynamic>> expenses) {
    // Current month context
    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final date = DateTime.tryParse(dateStr);
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();

    // Map category spending
    final Map<String, double> spendingMap = {};
    for (var e in currentMonthExpenses) {
      final cat = e['category']?.toString() ?? 'Others';
      final amt = double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0;
      spendingMap[cat] = (spendingMap[cat] ?? 0) + amt;
    }

    double totalBudget = budgets.fold(0.0, (sum, b) => sum + (double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0));
    double totalSpent = spendingMap.values.fold(0.0, (sum, amt) => sum + amt);
    
    // Filtered budgets
    final filteredBudgets = budgets.where((b) {
      if (_selectedFilter == 'All') return true;
      final spent = spendingMap[b['category']] ?? 0.0;
      final limit = double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0;
      if (_selectedFilter == 'Over Budget') return spent > limit;
      if (_selectedFilter == 'On Track') return spent <= limit;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(budgetsStreamProvider);
        ref.invalidate(expensesStreamProvider);
      },
      color: AppColors.accentPurple,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
          
          // 1. Overview Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSummaryCard(totalBudget, totalSpent),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 2. Health & Daily Limit
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _buildHealthCard(totalBudget, totalSpent, budgets.length)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDailyLimitCard(totalBudget, totalSpent)),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 3. Insights Section
          SliverToBoxAdapter(
            child: _buildInsightsSection(totalBudget, totalSpent, budgets, spendingMap),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 4. Budget List Header & Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildListHeader(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // 5. Category Budget List
          if (filteredBudgets.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState(budgets.isEmpty))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final budget = filteredBudgets[index];
                    final spent = spendingMap[budget['category']] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCategoryCard(budget, spent),
                    );
                  },
                  childCount: filteredBudgets.length,
                ),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double totalBudget, double totalSpent) {
    final progress = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final remaining = totalBudget - totalSpent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accentPurple, AppColors.accentPurple.withValues(alpha: 0.8), const Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppColors.accentPurple.withValues(alpha: 0.35), blurRadius: 25, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL MONTHLY LIMIT', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                child: Text('${DateFormat('MMMM').format(DateTime.now()).toUpperCase()} CYCLE', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('₹${totalBudget.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(fontSize: 42, color: Colors.white, height: 1.0)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildMiniSummary('SPENT', '₹${totalSpent.toStringAsFixed(2)}', AppColors.accentRose)),
              Container(width: 1, height: 30, color: Colors.white12),
              Expanded(child: _buildMiniSummary('REMAINING', '₹${remaining.clamp(0, double.infinity).toStringAsFixed(2)}', AppColors.accentCyan)),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(height: 10, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                width: MediaQuery.of(context).size.width * 0.75 * progress,
                height: 10,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.accentCyan, AppColors.accentEmerald]),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.4), blurRadius: 8)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toInt()}% UTILIZED', style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('SAFE SPENDING ZONE', style: TextStyle(color: progress > 0.9 ? AppColors.accentRose : AppColors.accentEmerald, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSummary(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.moneyStyle.copyWith(fontSize: 18, color: Colors.white)),
      ],
    );
  }

  Widget _buildHealthCard(double totalBudget, double totalSpent, int budgetCount) {
    double score = 100;
    if (totalBudget > 0) {
      score = (100 - (totalSpent / totalBudget * 100)).clamp(0, 100);
    }
    final color = score > 70 ? AppColors.accentEmerald : (score > 40 ? AppColors.accentCyan : AppColors.accentRose);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DISCIPLINE SCORE', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(width: 44, height: 44, child: CircularProgressIndicator(value: score / 100, strokeWidth: 4, backgroundColor: AppColors.bgSecondary, valueColor: AlwaysStoppedAnimation<Color>(color))),
                  Text('${score.toInt()}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(score > 70 ? 'Excellent' : 'Risk Alert', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('$budgetCount Active', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyLimitCard(double totalBudget, double totalSpent) {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = (lastDay - now.day) + 1;
    final dailyLimit = (totalBudget - totalSpent).clamp(0, double.infinity) / remainingDays;

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SAFE DAILY LIMIT', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.accentCyan.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(LucideIcons.shieldCheck, color: AppColors.accentCyan, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${dailyLimit.toStringAsFixed(0)}/day', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('$remainingDays Days left', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(double totalBudget, double totalSpent, List<Map<String, dynamic>> budgets, Map<String, double> spendingMap) {
    final insights = <Map<String, dynamic>>[];
    
    if (totalBudget > 0 && totalSpent > totalBudget) {
      insights.add({'text': 'System Alert: Total budget threshold exceeded.', 'icon': LucideIcons.alertOctagon, 'color': AppColors.accentRose});
    }
    
    for (var b in budgets) {
      final spent = spendingMap[b['category']] ?? 0.0;
      final limit = double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0;
      if (limit > 0 && spent > limit * 0.9) {
        insights.add({'text': '${b['category']} utilization reached ${((spent/limit)*100).toInt()}%.', 'icon': LucideIcons.trendingUp, 'color': AppColors.accentRose});
      }
    }

    if (insights.isEmpty) {
      insights.add({'text': 'Operational Efficiency: All spending within parameters.', 'icon': LucideIcons.checkCircle, 'color': AppColors.accentEmerald});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('SMART INSIGHTS', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: insights.length,
            itemBuilder: (context, index) {
              final insight = insights[index];
              final color = insight['color'] as Color;
              return Container(
                width: 280,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: 0.2))),
                child: Row(
                  children: [
                    Icon(insight['icon'] as IconData, color: color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(insight['text'] as String, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('CATEGORIES', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        Row(
          children: ['All', 'Over Budget'].map((f) {
            final isSelected = _selectedFilter == f;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = f),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: isSelected ? AppColors.accentPurple.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? AppColors.accentPurple : AppColors.border)),
                child: Text(f, style: TextStyle(color: isSelected ? AppColors.accentPurple : AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> budget, double spent) {
    final limit = double.tryParse(budget['amount']?.toString() ?? '0') ?? 0.0;
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOver = spent > limit;
    final color = isOver ? AppColors.accentRose : AppColors.accentEmerald;

    return Dismissible(
      key: Key(budget['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.accentRose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24)),
        child: const Icon(LucideIcons.trash2, color: AppColors.accentRose),
      ),
      onDismissed: (_) => _deleteBudget(budget['id']),
      child: GlassCard(
        margin: EdgeInsets.zero,
        borderColor: isOver ? AppColors.accentRose.withValues(alpha: 0.4) : AppColors.border,
        child: InkWell(
          onTap: () => _editBudget(budget),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(_getCategoryIcon(budget['category']), color: color, size: 20)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(budget['category'] ?? 'Others', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                          Text('Limit: ₹${limit.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${spent.toStringAsFixed(0)}', style: AppTheme.moneyStyle.copyWith(fontSize: 18, color: isOver ? AppColors.accentRose : AppColors.textPrimary)),
                        Text(isOver ? 'OVER BUDGET' : 'UTILIZED', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    Container(height: 6, decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(3))),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      width: (MediaQuery.of(context).size.width - 80) * progress,
                      height: 6,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Dining': return LucideIcons.utensils;
      case 'Transportation': return LucideIcons.car;
      case 'Housing': return LucideIcons.home;
      case 'Entertainment': return LucideIcons.clapperboard;
      case 'Health': return LucideIcons.activity;
      case 'Shopping': return LucideIcons.shoppingBag;
      case 'Utilities': return LucideIcons.zap;
      case 'Investment': return LucideIcons.trendingUp;
      case 'Education': return LucideIcons.bookOpen;
      default: return LucideIcons.box;
    }
  }

  Widget _buildEmptyState(bool noBudgetsAtAll) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(noBudgetsAtAll ? LucideIcons.pieChart : LucideIcons.searchX, size: 60, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(noBudgetsAtAll ? 'NO BUDGET ARCHITECTURE DETECTED' : 'NO MATCHING CONSTRAINTS', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(noBudgetsAtAll ? 'Initiate your first spending constraint to begin monitoring.' : 'Try adjusting your filters.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}
