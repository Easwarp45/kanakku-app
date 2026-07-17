import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

import '../data/expense_service.dart';
import '../../../core/utils/multi_currency_helper.dart';
import '../../../core/providers/preferences_provider.dart';

class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends ConsumerState<TransactionsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedDateRange = 'This month';
  DateTimeRange? _customDateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<String> _categories = [
    'All Categories',
    'Food & Dining',
    'Transportation',
    'Housing',
    'Entertainment',
    'Health',
    'Shopping',
    'Utilities',
    'Others',
  ];

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Select Category', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _categories.length,
                itemBuilder: (ctx, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.3) : Colors.transparent),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? AppColors.accentCyan : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (isSelected) const Icon(LucideIcons.check, color: AppColors.accentCyan, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentCyan,
              onPrimary: AppColors.bgPrimary,
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

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final prefs = ref.watch(preferencesProvider);
    final currencyCode = supportedCurrencies[prefs.currencyIndex].code;

    Future<void> handleRefresh() async {
      ref.invalidate(expensesStreamProvider);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentCyan,
          backgroundColor: AppColors.bgElevated,
          onRefresh: handleRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              expensesAsync.when(
                data: (expenses) {
                  final filtered = _filterExpenses(expenses);
                  double total = filtered.fold(0.0, (sum, e) {
                    final amount = e['amount'] is num ? (e['amount'] as num).toDouble() : double.tryParse(e['amount'].toString()) ?? 0.0;
                    return sum + amount;
                  });
                  final convertedTotal = prefs.convertFromBaseline(total);
                  return SliverToBoxAdapter(
                    child: _buildHeader(context, convertedTotal, currencyCode),
                  );
                },
                loading: () => SliverToBoxAdapter(child: _buildHeader(context, 0.0, currencyCode)),
                error: (_, _) => SliverToBoxAdapter(child: _buildHeader(context, 0.0, currencyCode)),
              ),
              SliverToBoxAdapter(child: _buildFilterSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: expensesAsync.maybeWhen(
                  data: (expenses) {
                    final filtered = _filterExpenses(expenses);
                    if (filtered.isNotEmpty) {
                      return Column(
                        children: [
                          _buildSpendingBreakdown(filtered),
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
              SliverToBoxAdapter(child: _buildSectionTitle('Expense History')),
              expensesAsync.when(
                data: (expenses) {
                  final filtered = _filterExpenses(expenses);
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState());
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return RepaintBoundary(
                            child: _buildTransactionCard(filtered[index]),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2)),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.accentRose, fontSize: 13))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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

  Widget _buildHeader(BuildContext context, double total, String currencyCode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Expenses',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.download, color: AppColors.accentCyan, size: 18),
                    onPressed: _exportToCSV,
                    tooltip: 'Export CSV',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'TOTAL SPENT',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                CurrencyFormatter.format(total, currencyCode),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedDateRange == 'Custom' ? 'Custom Range' : _selectedDateRange,
                  style: const TextStyle(color: AppColors.accentCyan, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterExpenses(List<Map<String, dynamic>> expenses) {
    return expenses.where((e) {
      final isIncome = e['is_income'] == true;
      if (isIncome) return false;

      // Category match
      if (_selectedCategory != 'All Categories') {
        final cat = (e['category']?.toString() ?? 'Others').toLowerCase();
        final selected = _selectedCategory.toLowerCase();
        
        bool isMatch = false;
        if (selected.contains('food') && (cat.contains('food') || cat.contains('dining') || cat.contains('drink'))) {
          isMatch = true;
        } else if (selected.contains('transport') && (cat.contains('transport') || cat.contains('car') || cat.contains('bike'))) {
          isMatch = true;
        } else if (selected.contains('other') && cat.contains('other')) {
          isMatch = true;
        } else if (cat.contains(selected) || selected.contains(cat)) {
          isMatch = true;
        }
        
        if (!isMatch) return false;
      }

      // Date match
      if (_selectedDateRange != 'All time') {
        final dateStr = e['expense_date']?.toString() ?? e['created_at'];
        if (dateStr == null) return false;
        final date = DateTime.tryParse(dateStr);
        if (date == null) return false;

        if (_selectedDateRange == 'This month') {
          final now = DateTime.now();
          if (date.year != now.year || date.month != now.month) return false;
        } else if (_selectedDateRange == 'Custom' && _customDateRange != null) {
          final end = _customDateRange!.end.add(const Duration(days: 1));
          if (date.isBefore(_customDateRange!.start) || date.isAfter(end)) return false;
        }
      }

      // Search match
      final desc = (e['description']?.toString() ?? '').toLowerCase();
      final catName = (e['category']?.toString() ?? '').toLowerCase();
      if (_searchQuery.isNotEmpty) {
        if (!desc.contains(_searchQuery) && !catName.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bgSecondary.withValues(alpha: 0.5),
              hintText: 'Search description...',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.textSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showCategoryPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _selectedCategory != 'All Categories' ? AppColors.accentCyan.withValues(alpha: 0.4) : AppColors.border.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedCategory,
                          style: TextStyle(
                            color: _selectedCategory != 'All Categories' ? AppColors.accentCyan : AppColors.textSecondary,
                            fontWeight: _selectedCategory != 'All Categories' ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        Icon(LucideIcons.chevronDown, color: _selectedCategory != 'All Categories' ? AppColors.accentCyan : AppColors.textTertiary, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateChip(
                  label: 'All time',
                  isSelected: _selectedDateRange == 'All time',
                  onTap: () => setState(() => _selectedDateRange = 'All time'),
                ),
                _buildDateChip(
                  label: 'This month',
                  isSelected: _selectedDateRange == 'This month',
                  onTap: () => setState(() => _selectedDateRange = 'This month'),
                ),
                _buildDateChip(
                  label: _customDateRange == null ? 'Custom Date' : '${_customDateRange!.start.day} ${_getMonthString(_customDateRange!.start.month)} - ${_customDateRange!.end.day} ${_getMonthString(_customDateRange!.end.month)}',
                  isSelected: _selectedDateRange == 'Custom',
                  onTap: _pickDateRange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) => onTap(),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
        selectedColor: AppColors.accentCyan,
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

  Widget _buildTransactionCard(Map<String, dynamic> t) {
    final baseAmount = t['amount'] is num ? (t['amount'] as num).toDouble() : double.tryParse(t['amount'].toString()) ?? 0.0;
    String rawTitle = _cleanDescription(t['description']?.toString() ?? '');
    String rawCategory = t['category']?.toString() ?? 'Expense';
    
    bool hasTitle = rawTitle.isNotEmpty && rawTitle.toLowerCase() != 'unknown';
    String displayTitle = hasTitle ? rawTitle : _capitalize(rawCategory);
    
    String formattedDate = '';
    final dateStr = t['expense_date']?.toString() ?? t['created_at']?.toString();
    if (dateStr != null) {
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        final hour = date.hour;
        final min = date.minute.toString().padLeft(2, '0');
        final ampm = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour % 12 == 0 ? 12 : hour % 12;
        formattedDate = '${date.day} ${_getMonthString(date.month)}, $hour12:$min $ampm';
      }
    }

    String displaySubtitle = hasTitle ? '$formattedDate  •  ${_capitalize(rawCategory)}' : formattedDate;

    final prefs = ref.watch(preferencesProvider);
    final preferredCurrencyCode = supportedCurrencies[prefs.currencyIndex].code;
    final mcData = MultiCurrencyData.parse(t['description']?.toString() ?? '');
    
    String formattedAmount = '';
    String sublabel = '';

    if (mcData != null) {
      formattedAmount = CurrencyFormatter.format(mcData.amount, mcData.currency);
      if (preferredCurrencyCode != mcData.currency) {
        final preferredVal = prefs.convertFromBaseline(baseAmount);
        sublabel = '≈ ${CurrencyFormatter.format(preferredVal, preferredCurrencyCode)}';
      }
    } else {
      final converted = prefs.convertFromBaseline(baseAmount);
      formattedAmount = CurrencyFormatter.format(converted, preferredCurrencyCode);
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
          child: Icon(_getCategoryIcon(rawCategory), color: _getCategoryColor(rawCategory), size: 16),
        ),
        title: Text(
          displayTitle,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          displaySubtitle,
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
                    color: AppColors.textPrimary,
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
          _showExpenseDetails(t);
        },
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _cleanDescription(String raw) {
    final cleanGroup = raw.replaceFirst(RegExp(r'^\[GroupExpense:[^\]]+\]\s*'), '').trim();
    return MultiCurrencyData.cleanDescription(cleanGroup);
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('dining') || cat.contains('drink')) return LucideIcons.utensilsCrossed;
    if (cat.contains('transport') || cat.contains('car') || cat.contains('bike')) return LucideIcons.car;
    if (cat.contains('shop')) return LucideIcons.shoppingBag;
    if (cat.contains('entertainment') || cat.contains('movie') || cat.contains('play')) return LucideIcons.play;
    if (cat.contains('health') || cat.contains('med')) return LucideIcons.heartPulse;
    if (cat.contains('bill') || cat.contains('utility') || cat.contains('zap')) return LucideIcons.zap;
    if (cat.contains('house') || cat.contains('rent')) return LucideIcons.home;
    return LucideIcons.receipt;
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food')) return Colors.orange;
    if (cat.contains('transport')) return Colors.blue;
    if (cat.contains('shop')) return Colors.pink;
    if (cat.contains('entertainment')) return Colors.purple;
    if (cat.contains('health')) return Colors.red;
    if (cat.contains('bill') || cat.contains('utility')) return Colors.yellow;
    if (cat.contains('house')) return Colors.green;
    return AppColors.textSecondary;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.wallet, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text(
              'No expenses found',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start tracking your spending by adding your first expense.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/add-expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Add Expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> t) {
    final baseAmount = t['amount'] is num ? (t['amount'] as num).toDouble() : double.tryParse(t['amount'].toString()) ?? 0.0;
    String rawTitle = _cleanDescription(t['description']?.toString() ?? '');
    String rawCategory = t['category']?.toString() ?? 'Expense';
    
    bool hasTitle = rawTitle.isNotEmpty && rawTitle.toLowerCase() != 'unknown';
    String displayTitle = hasTitle ? rawTitle : _capitalize(rawCategory);

    final dateStr = t['expense_date']?.toString() ?? t['created_at']?.toString();
    DateTime? date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    String formattedFullDate = date != null ? '${date.day} ${_getMonthString(date.month)} ${date.year}, ${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}' : 'Unknown Date';

    final prefs = ref.read(preferencesProvider);
    final preferredCurrencyCode = supportedCurrencies[prefs.currencyIndex].code;
    final mcData = MultiCurrencyData.parse(t['description']?.toString() ?? '');

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
      builder: (context) => Container(
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
            const Text('TRANSACTION DETAILS', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: _getCategoryColor(rawCategory).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getCategoryIcon(rawCategory), color: _getCategoryColor(rawCategory), size: 24),
            ),
            const SizedBox(height: 16),
            Text(displayTitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(formattedAmount, style: AppTheme.moneyStyle.copyWith(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
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
                  _detailItem(LucideIcons.calendar, 'Date', formattedFullDate),
                  const Divider(color: AppColors.border, height: 20),
                  _detailItem(LucideIcons.tag, 'Category', _capitalize(rawCategory)),
                  const Divider(color: AppColors.border, height: 20),
                  _detailItem(LucideIcons.alignLeft, 'Description', rawTitle.isNotEmpty ? rawTitle : 'No description provided'),
                  if (mcData != null) ...[
                    const Divider(color: AppColors.border, height: 20),
                    _detailItem(LucideIcons.trendingUp, 'Exchange Rate', '1 INR = ${mcData.rate.toStringAsFixed(4)} ${mcData.currency}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildBudgetGuardSection(rawCategory, baseAmount),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/edit-expense', extra: t);
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
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(t['id'].toString());
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

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('This will permanently remove this transaction from your history.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(expenseServiceProvider).deleteExpense(id);
              ref.invalidate(expensesStreamProvider);
            }, 
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingBreakdown(List<Map<String, dynamic>> expenses) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    final categoryTotals = <String, double>{};
    double totalAll = 0;

    for (var e in expenses) {
      final amt = e['amount'] is num ? (e['amount'] as num).toDouble() : double.tryParse(e['amount'].toString()) ?? 0.0;
      final cat = e['category']?.toString() ?? 'Others';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
      totalAll += amt;
    }

    final sortedCats = categoryTotals.keys.toList()..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.pieChart, color: AppColors.accentCyan, size: 14),
                SizedBox(width: 8),
                Text('Spending Distribution', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: sortedCats.map((cat) {
                    final percent = categoryTotals[cat]! / totalAll;
                    if (percent < 0.01) return const SizedBox.shrink();
                    return Flexible(
                      flex: (percent * 100).round(),
                      child: Container(color: _getCategoryColor(cat)),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: sortedCats.take(4).map((cat) {
                final percent = (categoryTotals[cat]! / totalAll * 100).toStringAsFixed(0);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: _getCategoryColor(cat), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('$cat ($percent%)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetGuardSection(String category, double currentAmount) {
    const double monthlyGoal = 5000.0;
    final expensesAsync = ref.watch(expensesStreamProvider);
    
    return expensesAsync.maybeWhen(
      data: (expenses) {
        double catTotal = expenses
            .where((e) => e['category']?.toString().toLowerCase() == category.toLowerCase())
            .fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
        
        double progress = catTotal / monthlyGoal;
        if (progress > 1.0) progress = 1.0;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentCyan.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Budget Guard', style: TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w700)),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.bgPrimary,
                  color: progress > 0.8 ? AppColors.accentRose : AppColors.accentCyan,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You have ₹${(monthlyGoal - catTotal).toStringAsFixed(2)} left for ${_capitalize(category)} this month.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _exportToCSV() async {
    final expensesAsync = ref.read(expensesStreamProvider);
    expensesAsync.whenData((expenses) async {
      final filtered = _filterExpenses(expenses);
      if (filtered.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
        return;
      }

      String csv = 'Date,Category,Description,Amount\n';
      for (var e in filtered) {
        final date = e['expense_date']?.toString() ?? e['created_at']?.toString().substring(0, 10) ?? '';
        final cat = e['category'] ?? '';
        final desc = _cleanDescription((e['description'] ?? '').toString()).replaceAll(',', ' ');
        final amt = e['amount'] ?? '';
        csv += '$date,$cat,"$desc",$amt\n';
      }

      try {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/Kanakku_Expenses_${DateTime.now().millisecondsSinceEpoch}.csv';
        final file = File(filePath);
        await file.writeAsString(csv);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(filePath)],
            subject: 'Kanakku Expense Report',
            text: 'Here is your expense report exported from Kanakku.',
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.accentRose),
          );
        }
      }
    });
  }

  String _getMonthString(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
