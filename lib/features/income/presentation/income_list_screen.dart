import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/multi_currency_helper.dart';
import '../../../core/utils/custom_source_helper.dart';
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
    final prefs = ref.watch(preferencesProvider);
    final preferredCurrencyCode = supportedCurrencies[prefs.currencyIndex].code;

    Future<void> handleRefresh() async {
      ref.invalidate(incomeStreamProvider);
      ref.invalidate(totalIncomeAmountProvider);
      ref.invalidate(monthlyIncomeProvider);
      await ref.read(preferencesProvider.notifier).fetchRates(force: true);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentEmerald,
          backgroundColor: AppColors.bgElevated,
          onRefresh: handleRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, totalIncome, monthlyIncome, preferredCurrencyCode)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildFilterSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
                        (_, i) => RepaintBoundary(
                          child: _buildIncomeCard(filtered[i]),
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.accentEmerald, strokeWidth: 2)),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.accentRose, fontSize: 13))),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-income'),
        backgroundColor: AppColors.accentEmerald,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(LucideIcons.plus, size: 24),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double total, double monthly, String currencyCode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Income Hub',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: const Icon(LucideIcons.landmark, color: AppColors.accentEmerald, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTHLY INCOME',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(monthly, currencyCode),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.border.withValues(alpha: 0.5)),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ALL TIME TOTAL',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(total, currencyCode),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bgSecondary.withValues(alpha: 0.5),
              hintText: 'Search description...',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.textSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accentEmerald, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSourceChip('All'),
                ...incomeSources.keys.map((key) => _buildSourceChip(key)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
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
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
        selectedColor: AppColors.accentEmerald,
        backgroundColor: AppColors.bgSecondary.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isSelected ? Colors.transparent : AppColors.border.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            dialogTheme: const DialogThemeData(backgroundColor: AppColors.bgPrimary),
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
    final displayName = sourceKey == 'All' ? 'All Sources' : (incomeSources[sourceKey]?.displayName ?? sourceKey);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedSource = sourceKey),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentEmerald.withValues(alpha: 0.12) : AppColors.bgSecondary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.accentEmerald.withValues(alpha: 0.4) : AppColors.border.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            displayName,
            style: TextStyle(
              color: isSelected ? AppColors.accentEmerald : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeCard(Map<String, dynamic> t) {
    final baseAmount = _parseAmt(t['amount']);
    final rawDesc = t['description']?.toString() ?? '';
    final customSrc = CustomSourceData.parse(rawDesc);
    final cleanDescAfterSrc = CustomSourceData.cleanDescription(rawDesc);
    final cleanDesc = MultiCurrencyData.cleanDescription(cleanDescAfterSrc);
    final source = t['source']?.toString() ?? 'other';
    final meta = customSrc != null
        ? IncomeSourceMeta(customSrc.name, '💰')
        : (incomeSources[source] ?? const IncomeSourceMeta('Other', '📦'));
    
    DateTime? d = DateTime.tryParse(t['income_date']?.toString() ?? t['created_at']?.toString() ?? '');
    String dateStr = d != null ? DateFormat('MMM dd, yyyy').format(d) : 'Unknown';

    final displayTitle = cleanDesc.isNotEmpty ? cleanDesc : meta.displayName;

    final prefs = ref.watch(preferencesProvider);
    final preferredCurrencyCode = supportedCurrencies[prefs.currencyIndex].code;
    final mcData = MultiCurrencyData.parse(rawDesc);

    String formattedAmount = '';
    String sublabel = '';

    if (mcData != null) {
      formattedAmount = '+${CurrencyFormatter.format(mcData.amount, mcData.currency)}';
      if (preferredCurrencyCode != mcData.currency) {
        final preferredVal = prefs.convertFromBaseline(baseAmount);
        sublabel = '≈ ${CurrencyFormatter.format(preferredVal, preferredCurrencyCode)}';
      }
    } else {
      final converted = prefs.convertFromBaseline(baseAmount);
      formattedAmount = '+${CurrencyFormatter.format(converted, preferredCurrencyCode)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(meta.emoji, style: const TextStyle(fontSize: 16))),
        ),
        title: Text(
          displayTitle,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '$dateStr  •  ${meta.displayName}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedAmount,
                  style: AppTheme.moneyStyle.copyWith(
                    color: AppColors.accentEmerald,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sublabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary, size: 14),
          ],
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          _showIncomeDetails(context, t);
        },
      ),
    );
  }

  void _showIncomeDetails(BuildContext context, Map<String, dynamic> t) {
    final baseAmount = _parseAmt(t['amount']);
    final rawDesc = t['description']?.toString() ?? '';
    final customSrc = CustomSourceData.parse(rawDesc);
    final cleanDescAfterSrc = CustomSourceData.cleanDescription(rawDesc);
    final cleanDesc = MultiCurrencyData.cleanDescription(cleanDescAfterSrc);
    final displayDescription = cleanDesc.isNotEmpty ? cleanDesc : 'No description';
    final source = t['source']?.toString() ?? 'other';
    final meta = customSrc != null
        ? IncomeSourceMeta(customSrc.name, '💰')
        : (incomeSources[source] ?? const IncomeSourceMeta('Other', '📦'));
    final isRecurring = t['is_recurring'] == true;

    final prefs = ref.read(preferencesProvider);
    final preferredCurrencyCode = supportedCurrencies[prefs.currencyIndex].code;
    final mcData = MultiCurrencyData.parse(rawDesc);

    String formattedAmount = '';
    String sublabel = '';

    if (mcData != null) {
      formattedAmount = CurrencyFormatter.format(mcData.amount, mcData.currency);
      if (preferredCurrencyCode != mcData.currency) {
        final preferredVal = prefs.convertFromBaseline(baseAmount);
        sublabel = '≈ ${CurrencyFormatter.format(preferredVal, preferredCurrencyCode)}';
      } else if (mcData.currency != 'INR') {
        sublabel = '≈ ₹${baseAmount.toStringAsFixed(2)}';
      }
    } else {
      final converted = prefs.convertFromBaseline(baseAmount);
      formattedAmount = CurrencyFormatter.format(converted, preferredCurrencyCode);
      if (preferredCurrencyCode != 'INR') {
        sublabel = '≈ ₹${baseAmount.toStringAsFixed(2)}';
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 40, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text(
              'TRANSACTION DETAILS',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
            ),
            const SizedBox(height: 16),
            Text(meta.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              displayDescription,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              formattedAmount,
              style: AppTheme.moneyStyle.copyWith(color: AppColors.accentEmerald, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            if (sublabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(sublabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _detailItem(LucideIcons.tag, 'Source', meta.displayName),
                  const Divider(color: AppColors.border, height: 20),
                  _detailItem(LucideIcons.repeat, 'Recurring', isRecurring ? 'Yes' : 'No'),
                  const Divider(color: AppColors.border, height: 20),
                  _detailItem(LucideIcons.alignLeft, 'Description', displayDescription),
                  if (mcData != null) ...[
                    const Divider(color: AppColors.border, height: 20),
                    _detailItem(LucideIcons.trendingUp, 'Exchange Rate', '1 INR = ${mcData.rate.toStringAsFixed(4)} ${mcData.currency}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/edit-income', extra: t);
                    },
                    icon: const Icon(LucideIcons.edit3, color: AppColors.accentCyan, size: 18),
                    label: const Text('Edit', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.accentCyan.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(incomeServiceProvider).deleteIncome(t['id'].toString());
                      ref.invalidate(incomeStreamProvider);
                    },
                    icon: const Icon(LucideIcons.trash2, color: AppColors.accentRose, size: 18),
                    label: const Text('Delete', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.accentRose.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        Icon(icon, color: AppColors.textTertiary, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  double _parseAmt(dynamic a) => a is num ? a.toDouble() : double.tryParse(a?.toString() ?? '0') ?? 0.0;

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.info, size: 40, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              'No matching income entries found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
