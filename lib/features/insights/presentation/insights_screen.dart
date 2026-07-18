import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/multi_currency_helper.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../goals/data/financial_goal_service.dart';
import '../services/intelligence_engine.dart';
import '../models/intelligence_models.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> with SingleTickerProviderStateMixin {
  String _selectedCategory = 'Today';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(intelligenceEngineProvider);
    // Also invalidate individual underlying streams
    ref.read(localGoalsProvider.notifier).loadGoals();
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(intelligenceEngineProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentCyan,
          backgroundColor: AppColors.bgElevated,
          onRefresh: _handleRefresh,
          child: reportAsync.when(
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.accentCyan),
                  SizedBox(height: 16),
                  Text(
                    'Synthesizing Financial Brain...',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.alertTriangle, color: AppColors.accentRose, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to compile intelligence report',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _handleRefresh,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan.withValues(alpha: 0.1),
                        foregroundColor: AppColors.accentCyan,
                      ),
                      child: const Text('Retry Analysis'),
                    ),
                  ],
                ),
              ),
            ),
            data: (report) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildCategorySelector()),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        ScaleTransition(
                          scale: CurvedAnimation(
                            parent: _animationController,
                            curve: Curves.easeOutBack,
                          ),
                          child: _buildSelectedContent(report),
                        ),
                        const SizedBox(height: 48),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, color: AppColors.accentCyan, size: 16),
              SizedBox(width: 8),
              Text(
                'FINANCIAL INTELLIGENCE 2.0',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentCyan,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Personal Advisor',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Real-time data interpretation, predictions, alerts, and behavioral patterns.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = ['Today', 'Risk & Budgets', 'Behavior & Goals', 'Milestones'];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = cat;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentCyan.withValues(alpha: 0.12)
                    : AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.3) : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedContent(IntelligenceReport report) {
    switch (_selectedCategory) {
      case 'Today':
        return Column(
          children: [
            _buildDailyInsightHero(report.dailyInsight),
            _buildHealthScoreCard(report.healthScore),
            _buildSmartAlertsBanner(report.smartAlerts),
            _buildWeeklyStoryCard(report.weeklyStory),
            _buildMonthlyReportPreviewCard(report.monthlyReport),
          ],
        );
      case 'Risk & Budgets':
        return Column(
          children: [
            _buildSmartForecastCard(report.forecast),
            _buildBudgetIntelligenceCard(report.budgetIntelligence),
            _buildSavingsOpportunitiesCard(report.savingsOpportunities),
            _buildRecurringPaymentsCard(report.recurringPayments),
          ],
        );
      case 'Behavior & Goals':
        return Column(
          children: [
            _buildSpendingBehaviourCard(report.spendingBehaviour),
            _buildGoalIntelligenceCard(report.goalIntelligence),
            _buildCoachingRecommendationsCard(report.recommendations),
          ],
        );
      case 'Milestones':
        return Column(
          children: [
            _buildChallengesCard(report.challenges),
            _buildAchievementsCard(report.achievements),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // --- SECTION 1: Daily Insight Hero ---
  Widget _buildDailyInsightHero(DailyInsight insight) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCyan.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.sparkles, color: AppColors.accentCyan, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "TODAY'S HIGHLIGHT",
                      style: TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Confidence ${(insight.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            insight.insight,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2.0),
                  child: Icon(LucideIcons.lightbulb, color: AppColors.accentAmber, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight.recommendation,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 2: Financial Health Score ---
  Widget _buildHealthScoreCard(FinancialHealthScore health) {
    final difference = health.currentScore - health.previousScore;
    final isPositive = difference >= 0;
    final healthColor = health.currentScore >= 80
        ? AppColors.accentEmerald
        : (health.currentScore >= 60 ? AppColors.accentCyan : AppColors.accentRose);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FINANCIAL HEALTH SCORE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: health.currentScore / 100.0,
                      strokeWidth: 8,
                      backgroundColor: AppColors.bgPrimary,
                      color: healthColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    '${health.currentScore}',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPositive ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                          color: isPositive ? AppColors.accentEmerald : AppColors.accentRose,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isPositive ? "+" : ""}$difference vs last period',
                          style: TextStyle(
                            color: isPositive ? AppColors.accentEmerald : AppColors.accentRose,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      health.reasonForChange,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          const Text(
            'Suggested Improvements:',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...health.improvementSuggestions.map((sug) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Icon(LucideIcons.checkCircle2, color: AppColors.accentCyan, size: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sug,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // --- SECTION 3: Smart Forecast ---
  Widget _buildSmartForecastCard(ForecastData forecast) {
    final prefs = ref.watch(preferencesProvider);
    final code = supportedCurrencies[prefs.currencyIndex].code;
    final notifier = ref.read(preferencesProvider.notifier);

    final endOfMonthExp = notifier.convertFromBaseline(forecast.endOfMonthExpenses);
    final predictedSav = notifier.convertFromBaseline(forecast.predictedSavings);
    final remBudget = notifier.convertFromBaseline(forecast.remainingBudget);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SMART FORECAST',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Trust ${forecast.confidencePercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(color: AppColors.accentCyan, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildForecastItem(
            'Projected Month-End Bills',
            CurrencyFormatter.format(endOfMonthExp, code),
            'Based on daily burn run-rate.',
            AppColors.accentRose,
          ),
          const SizedBox(height: 16),
          _buildForecastItem(
            'Expected Monthly Savings Surplus',
            CurrencyFormatter.format(predictedSav, code),
            'Calculated from recurring inflow vs spend behavior.',
            AppColors.accentEmerald,
          ),
          const SizedBox(height: 16),
          _buildForecastItem(
            'Remaining Safe Budget Cap',
            CurrencyFormatter.format(remBudget, code),
            'Remaining balance allowed under limits.',
            AppColors.accentCyan,
          ),
          if (forecast.goalCompletionDate != null) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.calendar, color: AppColors.accentAmber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Next Goal Achievement: ${DateFormat('MMMM yyyy').format(forecast.goalCompletionDate!)}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForecastItem(String title, String amount, String explanation, Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(explanation, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount,
            style: AppTheme.moneyStyle.copyWith(fontSize: 16, color: accentColor),
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: Budget Intelligence ---
  Widget _buildBudgetIntelligenceCard(List<BudgetHealth> budgets) {
    final prefs = ref.watch(preferencesProvider);
    final code = supportedCurrencies[prefs.currencyIndex].code;
    final notifier = ref.read(preferencesProvider.notifier);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BUDGET INTELLIGENCE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (budgets.isEmpty)
            const Text(
              'No category budgets defined. Define limits in the budget tab to track overrun risks.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            ...budgets.map((b) {
              final limitPref = notifier.convertFromBaseline(b.limit);
              final spentPref = notifier.convertFromBaseline(b.spent);
              final remainingPref = notifier.convertFromBaseline(b.remainingSafeSpending);
              final dailyRecommendedPref = notifier.convertFromBaseline(b.dailyRecommendedSpending);

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            b.category,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (b.isRisky ? AppColors.accentRose : AppColors.accentEmerald).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            b.isRisky ? 'CRITICAL RISK' : 'HEALTHY',
                            style: TextStyle(
                              color: b.isRisky ? AppColors.accentRose : AppColors.accentEmerald,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: b.limit > 0 ? (b.spent / b.limit).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: AppColors.bgPrimary,
                      color: b.isRisky ? AppColors.accentRose : AppColors.accentEmerald,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Spent: ${CurrencyFormatter.format(spentPref, code)} of ${CurrencyFormatter.format(limitPref, code)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          b.overrunDate ?? '',
                          style: TextStyle(
                            color: b.isRisky ? AppColors.accentRose : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Remaining Margin', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(CurrencyFormatter.format(remainingPref, code), style: AppTheme.moneyStyle.copyWith(fontSize: 12, color: AppColors.textPrimary)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Safe Daily Spending', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(CurrencyFormatter.format(dailyRecommendedPref, code), style: AppTheme.moneyStyle.copyWith(fontSize: 12, color: AppColors.accentCyan)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- SECTION 5: Savings Opportunities ---
  Widget _buildSavingsOpportunitiesCard(List<SavingsOpportunity> opportunities) {
    final prefs = ref.watch(preferencesProvider);
    final code = supportedCurrencies[prefs.currencyIndex].code;
    final notifier = ref.read(preferencesProvider.notifier);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SAVINGS OPPORTUNITIES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...opportunities.map((op) {
            final potentialPref = notifier.convertFromBaseline(op.monthlySavingsPotential);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(op.icon, color: AppColors.accentPurple, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          op.category,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          op.description,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Save/mo', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(potentialPref, code),
                        style: AppTheme.moneyStyle.copyWith(fontSize: 13, color: AppColors.accentEmerald),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- SECTION 6: Spending Behaviour ---
  Widget _buildSpendingBehaviourCard(SpendingBehaviour behavior) {
    final prefs = ref.watch(preferencesProvider);
    final code = supportedCurrencies[prefs.currencyIndex].code;
    final notifier = ref.read(preferencesProvider.notifier);

    final avgTx = notifier.convertFromBaseline(behavior.averageTransactionValue);
    final maxTx = notifier.convertFromBaseline(behavior.largestTransaction);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SPENDING BEHAVIOUR',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (behavior.isWeekendSpender)
                _buildBehaviorBadge('Weekend Spender 🎪', AppColors.accentRose),
              if (behavior.isNightSpender)
                _buildBehaviorBadge('Late Night Spender 🌙', AppColors.accentPurple),
              if (behavior.isImpulseShopper)
                _buildBehaviorBadge('Impulse Shopper 🛍️', AppColors.accentAmber),
              if (behavior.isSalaryDaySpender)
                _buildBehaviorBadge('Salary Day Spikes 💸', AppColors.accentCyan),
              _buildBehaviorBadge('Fav Category: ${behavior.favoriteCategory}', AppColors.accentBlue),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          _buildBehaviorRow('Most Expensive Weekday', behavior.mostExpensiveWeekday, LucideIcons.calendar),
          _buildBehaviorRow(
            'Most Expensive Hour',
            behavior.mostExpensiveHour != -1
                ? '${behavior.mostExpensiveHour}:00'
                : 'None',
            LucideIcons.calendar,
          ),
          _buildBehaviorRow('Average Transaction Value', CurrencyFormatter.format(avgTx, code), LucideIcons.wallet),
          _buildBehaviorRow('Largest Transaction logged', CurrencyFormatter.format(maxTx, code), LucideIcons.trendingUp),
          _buildBehaviorRow('No-Spend Streak Record', '${behavior.longestNoSpendStreak} days', LucideIcons.shieldCheck),
          _buildBehaviorRow('Current Expense Streak', '${behavior.currentExpenseStreak} days', LucideIcons.flame),
        ],
      ),
    );
  }

  Widget _buildBehaviorBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBehaviorRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // --- SECTION 7: Goal Intelligence ---
  Widget _buildGoalIntelligenceCard(List<GoalPrediction> goals) {
    final prefs = ref.watch(preferencesProvider);
    final code = supportedCurrencies[prefs.currencyIndex].code;
    final notifier = ref.read(preferencesProvider.notifier);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GOAL INTELLIGENCE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            const Text(
              'No active savings goals found. Create goals to forecast success probabilities.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            ...goals.map((g) {
              final targetPref = notifier.convertFromBaseline(g.targetAmount);
              final savedPref = notifier.convertFromBaseline(g.currentSaved);
              final dailyPref = notifier.convertFromBaseline(g.dailyAmountRequired);
              final weeklyPref = notifier.convertFromBaseline(g.weeklyAmountRequired);
              final probabilityPct = (g.probabilityOfSuccess * 100).toStringAsFixed(0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            g.name,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (g.milestoneCelebration)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('COMPLETED 🏆', style: TextStyle(color: AppColors.accentEmerald, fontSize: 9, fontWeight: FontWeight.bold)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$probabilityPct% Success Prob', style: const TextStyle(color: AppColors.accentCyan, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: g.targetAmount > 0 ? (g.currentSaved / g.targetAmount).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: AppColors.bgPrimary,
                      color: AppColors.accentCyan,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${CurrencyFormatter.format(savedPref, code)} of ${CurrencyFormatter.format(targetPref, code)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (g.expectedCompletionDate != null)
                          Text(
                            'Est. completion: ${DateFormat('MMM yyyy').format(g.expectedCompletionDate!)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Daily Saved Needed', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(CurrencyFormatter.format(dailyPref, code), style: AppTheme.moneyStyle.copyWith(fontSize: 12, color: AppColors.textPrimary)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Weekly Saved Needed', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(CurrencyFormatter.format(weeklyPref, code), style: AppTheme.moneyStyle.copyWith(fontSize: 12, color: AppColors.textPrimary)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(LucideIcons.zap, color: AppColors.accentAmber, size: 13),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  g.fastestPath,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(LucideIcons.alertCircle, color: AppColors.textTertiary, size: 13),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  g.delayRisk,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- SECTION 8: Weekly Financial Story ---
  Widget _buildWeeklyStoryCard(WeeklyStory story) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEEKLY FINANCIAL STORY',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            story.summary,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...story.bulletPoints.map((pt) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Icon(LucideIcons.chevronRight, color: AppColors.accentCyan, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pt,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // --- SECTION 9: Achievements ---
  Widget _buildAchievementsCard(List<Achievement> achievements) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACHIEVEMENTS UNLOCKED',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final ach = achievements[index];
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ach.isUnlocked
                          ? ach.color.withValues(alpha: 0.15)
                          : AppColors.bgSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ach.isUnlocked ? ach.color : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      ach.icon,
                      color: ach.isUnlocked ? ach.color : AppColors.textTertiary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ach.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ach.isUnlocked ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: ach.isUnlocked ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- SECTION 10: Challenges ---
  Widget _buildChallengesCard(List<FinancialChallenge> challenges) {
    final notifier = ref.read(intelligenceEngineProvider.notifier);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FINANCIAL CHALLENGES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...challenges.map((ch) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ch.isActive
                      ? AppColors.accentPurple.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ch.name,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (ch.isCompleted && ch.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentEmerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('SUCCESS 🎉', style: TextStyle(color: AppColors.accentEmerald, fontSize: 9, fontWeight: FontWeight.bold)),
                        )
                      else if (ch.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentPurple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('ACTIVE ⚡', style: TextStyle(color: AppColors.accentPurple, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(ch.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3)),
                  const SizedBox(height: 12),
                  if (ch.isActive) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ch.targetAmount > 0
                              ? 'Spent: ₹${ch.currentAmount.toStringAsFixed(0)} / Max: ₹${ch.targetAmount.toStringAsFixed(0)}'
                              : 'Current spend: ₹${ch.currentAmount.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                        GestureDetector(
                          onTap: () => notifier.abandonChallenge(ch.id),
                          child: const Text(
                            'Abandon',
                            style: TextStyle(color: AppColors.accentRose, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: ch.targetAmount > 0
                          ? (ch.currentAmount / ch.targetAmount).clamp(0.0, 1.0)
                          : 0.0,
                      backgroundColor: AppColors.bgPrimary,
                      color: ch.isCompleted ? AppColors.accentEmerald : AppColors.accentRose,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: () => notifier.acceptChallenge(ch.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPurple.withValues(alpha: 0.1),
                        foregroundColor: AppColors.accentPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Accept Challenge', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- SECTION 11: Recurring Payments ---
  Widget _buildRecurringPaymentsCard(List<RecurringSubscription> subscriptions) {
    final prefs = ref.watch(preferencesProvider);
    final code = supportedCurrencies[prefs.currencyIndex].code;
    final notifier = ref.read(preferencesProvider.notifier);
    final engineNotifier = ref.read(intelligenceEngineProvider.notifier);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECURRING PAYMENTS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (subscriptions.isEmpty)
            const Text(
              'No recurring subscription profiles detected in transaction history.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            ...subscriptions.map((sub) {
              final amtPref = notifier.convertFromBaseline(sub.amount);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(sub.icon, color: AppColors.accentCyan, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.cleanName,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Latest: ${DateFormat('MMM dd').format(sub.dateDetected)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(amtPref, code),
                          style: AppTheme.moneyStyle.copyWith(fontSize: 13, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        if (sub.isConfirmed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('VERIFIED', style: TextStyle(color: AppColors.accentEmerald, fontSize: 8, fontWeight: FontWeight.bold)),
                          )
                        else
                          GestureDetector(
                            onTap: () => engineNotifier.confirmSubscription(sub.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('CONFIRM?', style: TextStyle(color: AppColors.accentAmber, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- SECTION 12: Smart Alerts ---
  Widget _buildSmartAlertsBanner(List<SmartAlert> alerts) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.map((alert) {
        final alertColor = alert.severity == 'critical'
            ? AppColors.accentRose
            : (alert.severity == 'warning' ? AppColors.accentAmber : AppColors.accentCyan);
        final alertIcon = alert.severity == 'critical'
            ? LucideIcons.alertOctagon
            : (alert.severity == 'warning' ? LucideIcons.alertTriangle : LucideIcons.info);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: alertColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: alertColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(alertIcon, color: alertColor, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(color: alertColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.message,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- SECTION 13: Personal Finance Coach ---
  Widget _buildCoachingRecommendationsCard(List<CoachingRecommendation> recommendations) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COACHING RECOMMENDATIONS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...recommendations.map((rec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: rec.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(rec.icon, color: rec.color, size: 18),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  rec.title,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                rec.category.toUpperCase(),
                                style: TextStyle(color: rec.color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rec.description,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- SECTION 14: Monthly Report Preview ---
  Widget _buildMonthlyReportPreviewCard(MonthlyReportPreview report) {
    final prefs = ref.watch(preferencesProvider);
    final code = supportedCurrencies[prefs.currencyIndex].code;
    final notifier = ref.read(preferencesProvider.notifier);

    final incPref = notifier.convertFromBaseline(report.income);
    final expPref = notifier.convertFromBaseline(report.expense);
    final savPref = notifier.convertFromBaseline(report.savings);
    final forecastPref = notifier.convertFromBaseline(report.endOfMonthForecast);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MONTHLY REPORT PREVIEW',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/monthly-wrap'), // Keep working wrap screen link
                child: const Row(
                  children: [
                    Text(
                      'Open Wrap',
                      style: TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Icon(LucideIcons.chevronRight, color: AppColors.accentCyan, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildReportMetric('Inflow', CurrencyFormatter.format(incPref, code), AppColors.accentEmerald),
              ),
              Expanded(
                child: _buildReportMetric('Outflow', CurrencyFormatter.format(expPref, code), AppColors.accentRose),
              ),
              Expanded(
                child: _buildReportMetric('Reserves', CurrencyFormatter.format(savPref, code), AppColors.accentCyan),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _buildReportDetail('Best Allocations', report.bestCategory, LucideIcons.shieldCheck, AppColors.accentEmerald),
          _buildReportDetail('Highest Outflow', report.worstCategory, LucideIcons.alertTriangle, AppColors.accentRose),
          _buildReportDetail('Health Score', '${report.healthScore}/100', LucideIcons.heartPulse, AppColors.accentCyan),
          _buildReportDetail('Forecast Outflow', CurrencyFormatter.format(forecastPref, code), LucideIcons.trendingUp, AppColors.accentAmber),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              report.oneSentenceSummary,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppTheme.moneyStyle.copyWith(fontSize: 13, color: color)),
        ),
      ],
    );
  }

  Widget _buildReportDetail(String title, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
