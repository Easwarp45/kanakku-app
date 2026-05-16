import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/income_service.dart';

class IncomeListScreen extends ConsumerStatefulWidget {
  const IncomeListScreen({super.key});

  @override
  ConsumerState<IncomeListScreen> createState() => _IncomeListScreenState();
}

class _IncomeListScreenState extends ConsumerState<IncomeListScreen> {
  String _searchQuery = '';
  String _selectedSource = 'All';
  String _selectedDateRange = 'This Month';
  DateTimeRange? _customDateRange;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> list) {
    return list.where((e) {
      // Filter by source (DB column name)
      if (_selectedSource != 'All') {
        if ((e['source']?.toString() ?? '') != _selectedSource) return false;
      }
      
      // Filter by date range
      if (_selectedDateRange != 'All Time') {
        final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
        final date = DateTime.tryParse(dateStr);
        if (date == null) return false;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        if (_selectedDateRange == 'Today') {
          if (date.year != today.year || date.month != today.month || date.day != today.day) return false;
        } else if (_selectedDateRange == 'This Week') {
          final weekStart = today.subtract(Duration(days: today.weekday - 1));
          if (date.isBefore(weekStart)) return false;
        } else if (_selectedDateRange == 'This Month') {
          if (date.year != now.year || date.month != now.month) return false;
        } else if (_selectedDateRange == 'Custom' && _customDateRange != null) {
          final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
          if (date.isBefore(start) || date.isAfter(end)) return false;
        }
      }

      // Filter by search query against description and source
      if (_searchQuery.isNotEmpty) {
        final description = (e['description']?.toString() ?? '').toLowerCase();
        final source = (e['source']?.toString() ?? '').toLowerCase();
        if (!description.contains(_searchQuery) && !source.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final incomeAsync = ref.watch(incomeStreamProvider);
    final totalIncome = ref.watch(totalIncomeAmountProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildTotalCard(totalIncome, monthlyIncome)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionTitle('Visual Analytics')),
            SliverToBoxAdapter(child: _buildAnalyticsCards(incomeAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionTitle('Search & Filters')),
            SliverToBoxAdapter(child: _buildFilterSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSmartInsight(incomeAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSectionTitle('Income History')),
            incomeAsync.when(
              data: (list) {
                final filtered = _filter(list);
                if (filtered.isEmpty) {
                  return SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState());
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildIncomeCard(filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.accentEmerald)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.accentRose))),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-income'),
        backgroundColor: AppColors.accentEmerald,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Income', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary, letterSpacing: 1.5)),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PORTFOLIO MANAGER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentEmerald, letterSpacing: 1.5)),
              SizedBox(height: 4),
              Text('Income Hub', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: const Icon(LucideIcons.landmark, color: AppColors.accentEmerald, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(double total, double monthly) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF065f46), Color(0xFF10b981)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: AppColors.accentEmerald.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12)),
            BoxShadow(color: Colors.white.withValues(alpha: 0.05), blurRadius: 0, offset: const Offset(0, 0), spreadRadius: 1),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Net Income', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Text('ALL TIME', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('₹${total.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(fontSize: 40, color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('THIS MONTH', style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('₹${monthly.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.white24),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AVG. DAILY', style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('₹${(monthly / 30).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCards(AsyncValue<List<Map<String, dynamic>>> incomeAsync) {
    return incomeAsync.maybeWhen(
      data: (list) {
        // Group by source (DB column), not category
        final sourceTotals = <String, double>{};
        for (var e in list) {
          final source = e['source']?.toString() ?? 'other';
          sourceTotals[source] = (sourceTotals[source] ?? 0) + _parseAmt(e['amount']);
        }
        final sorted = sourceTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.isNotEmpty ? sorted[0] : null;
        final topMeta = top != null ? incomeSources[top.key] : null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.trendingUp, color: AppColors.accentEmerald, size: 20),
                      const SizedBox(height: 12),
                      const Text('Top Source', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(topMeta?.displayName ?? top?.key ?? 'None', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.calendarCheck, color: AppColors.accentCyan, size: 20),
                      const SizedBox(height: 12),
                      const Text('Monthly Goal', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('75% Reached', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bgSecondary,
              hintText: 'Search by description or source...',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accentEmerald, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // 'All' + all DB enum keys from incomeSources
                _buildSourceChip('All'),
                ...incomeSources.keys.map((key) => _buildSourceChip(key)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildDateChip('All Time'),
                _buildDateChip('Today'),
                _buildDateChip('This Week'),
                _buildDateChip('This Month'),
                _buildDateChip('Custom'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label) {
    final isSelected = _selectedDateRange == label;
    String displayLabel = label;
    if (label == 'Custom' && _customDateRange != null) {
      displayLabel = '${DateFormat('d MMM').format(_customDateRange!.start)} - ${DateFormat('d MMM').format(_customDateRange!.end)}';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(displayLabel),
        selected: isSelected,
        onSelected: (v) {
          if (label == 'Custom') {
            _showDateRangePicker();
          } else {
            setState(() => _selectedDateRange = label);
          }
        },
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
        selectedColor: AppColors.accentEmerald,
        backgroundColor: AppColors.bgSecondary,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : AppColors.border.withValues(alpha: 0.5))),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentEmerald,
              onPrimary: Colors.white,
              surface: AppColors.bgSecondary,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.bgPrimary,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateRange = 'Custom';
      });
    }
  }

  Widget _buildSourceChip(String sourceKey) {
    final isSelected = _selectedSource == sourceKey;
    final displayName = sourceKey == 'All' ? 'All' : (incomeSources[sourceKey]?.displayName ?? sourceKey);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedSource = sourceKey),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentEmerald.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.accentEmerald : AppColors.border),
          ),
          child: Text(displayName, style: TextStyle(color: isSelected ? AppColors.accentEmerald : AppColors.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildSmartInsight(AsyncValue<List<Map<String, dynamic>>> incomeAsync) {
    return incomeAsync.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentEmerald.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.sparkles, color: AppColors.accentEmerald, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Track all income sources for personalized financial insights!',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildIncomeCard(Map<String, dynamic> t) {
    final amount = _parseAmt(t['amount']);
    // Read DB columns: 'description' (not 'title'), 'source' (not 'category')
    final description = t['description']?.toString() ?? '';
    final source = t['source']?.toString() ?? 'other';
    final meta = incomeSources[source] ?? const IncomeSourceMeta('Other', '📦');
    
    // Use income_date for display (the actual DB column)
    DateTime? d = DateTime.tryParse(t['income_date']?.toString() ?? t['created_at']?.toString() ?? '');
    String dateStr = d != null ? DateFormat('MMM dd, yyyy').format(d) : 'Unknown';

    // Show description if available, otherwise show the source display name
    final displayTitle = description.isNotEmpty ? description : meta.displayName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          height: 48, width: 48,
          decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(meta.emoji, style: const TextStyle(fontSize: 20))),
        ),
        title: Text(displayTitle, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text('$dateStr • ${meta.displayName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('+₹${amount.toStringAsFixed(0)}', style: AppTheme.moneyStyle.copyWith(color: AppColors.accentEmerald, fontSize: 16, fontWeight: FontWeight.w800)),
            const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary, size: 14),
          ],
        ),
        onTap: () => _showIncomeDetails(context, t),
      ),
    );
  }

  void _showIncomeDetails(BuildContext context, Map<String, dynamic> t) {
    final amount = _parseAmt(t['amount']);
    final description = t['description']?.toString() ?? 'No description';
    final source = t['source']?.toString() ?? 'other';
    final meta = incomeSources[source] ?? const IncomeSourceMeta('Other', '📦');
    final isRecurring = t['is_recurring'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: const BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 40, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            const Text('TRANSACTION DETAILS', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 16),
            Text(meta.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('₹${amount.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(color: AppColors.accentEmerald, fontSize: 32)),
            const SizedBox(height: 32),
            GlassCard(
              padding: const EdgeInsets.all(20),
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _detailItem(LucideIcons.tag, 'Source', meta.displayName),
                  const Divider(color: AppColors.border, height: 24),
                  _detailItem(LucideIcons.repeat, 'Recurring', isRecurring ? 'Yes' : 'No'),
                  const Divider(color: AppColors.border, height: 24),
                  _detailItem(LucideIcons.alignLeft, 'Description', description),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/edit-income', extra: t);
                    },
                    icon: const Icon(LucideIcons.edit3, color: AppColors.accentCyan, size: 20),
                    label: const Text('Edit Entry', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.accentCyan.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(incomeServiceProvider).deleteIncome(t['id'].toString());
                      // Refresh the stream
                      ref.invalidate(incomeStreamProvider);
                    },
                    icon: const Icon(LucideIcons.trash2, color: AppColors.accentRose, size: 20),
                    label: const Text('Delete Entry', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.accentRose.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
            Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  double _parseAmt(dynamic a) => a is num ? a.toDouble() : double.tryParse(a?.toString() ?? '0') ?? 0.0;

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.info, size: 48, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text('No matching income entries found', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
