import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/expense_service.dart';

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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, -10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              height: 4,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Select Category', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
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
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.4) : Colors.transparent),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? AppColors.accentCyan : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            if (isSelected) const Icon(LucideIcons.checkCircle2, color: AppColors.accentCyan, size: 22),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
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
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.accentCyan),
            ),
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

    Future<void> handleRefresh() async {
      ref.invalidate(expensesStreamProvider);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Expenses', style: TextStyle(fontSize: 22, color: AppColors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download, color: AppColors.accentCyan),
            onPressed: _exportToCSV,
            tooltip: 'Export CSV',
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentCyan,
          backgroundColor: AppColors.bgElevated,
          onRefresh: handleRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [

            // Smart Filters Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.bgSecondary.withValues(alpha: 0.5),
                        hintText: 'Search expenses...',
                        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 15),
                        prefixIcon: const Icon(LucideIcons.search, size: 20, color: AppColors.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(LucideIcons.xCircle, size: 18, color: AppColors.textTertiary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ) 
                          : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    GestureDetector(
                      onTap: _showCategoryPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSecondary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _selectedCategory != 'All Categories' ? AppColors.accentCyan : AppColors.border.withValues(alpha: 0.8)),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.filter, color: _selectedCategory != 'All Categories' ? AppColors.accentCyan : AppColors.textSecondary, size: 18),
                            Expanded(
                              child: Text(
                                _selectedCategory,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _selectedCategory != 'All Categories' ? AppColors.accentCyan : AppColors.textSecondary,
                                  fontWeight: _selectedCategory != 'All Categories' ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Icon(LucideIcons.chevronDown, color: _selectedCategory != 'All Categories' ? AppColors.accentCyan : AppColors.textSecondary, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildDateChip(
                            icon: LucideIcons.calendar,
                            label: _customDateRange == null ? 'Custom Date' : '${_customDateRange!.start.day} ${_getMonthString(_customDateRange!.start.month)} - ${_customDateRange!.end.day} ${_getMonthString(_customDateRange!.end.month)}',
                            isSelected: _selectedDateRange == 'Custom',
                            onTap: _pickDateRange,
                          ),
                          const SizedBox(width: 12),
                          _buildDateChip(
                            label: 'All time',
                            isSelected: _selectedDateRange == 'All time',
                            onTap: () => setState(() => _selectedDateRange = 'All time'),
                          ),
                          const SizedBox(width: 12),
                          _buildDateChip(
                            label: 'This month',
                            isSelected: _selectedDateRange == 'This month',
                            onTap: () => setState(() => _selectedDateRange = 'This month'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SliverToBoxAdapter(
              child: expensesAsync.when(
                data: (expenses) {
                   final filtered = _filterExpenses(expenses);
                   double total = filtered.fold(0.0, (sum, e) {
                     final amount = e['amount'] is num ? (e['amount'] as num).toDouble() : double.tryParse(e['amount'].toString()) ?? 0.0;
                     return sum + amount;
                   });
                   return Column(
                     children: [
                       _buildPremiumTotalHeader(total),
                       if (filtered.isNotEmpty) _buildSpendingBreakdown(filtered),
                     ],
                   );
                },
                loading: () => _buildPremiumTotalHeader(0.0),
                error: (_, __) => _buildPremiumTotalHeader(0.0),
              ),
            ),

            expensesAsync.when(
              data: (expenses) {
                var filtered = _filterExpenses(expenses);

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildTransactionCard(filtered[index]),
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
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

      // Search match — DB column is 'description', not 'title'
      final desc = (e['description']?.toString() ?? '').toLowerCase();
      final catName = (e['category']?.toString() ?? '').toLowerCase();
      if (_searchQuery.isNotEmpty) {
        if (!desc.contains(_searchQuery) && !catName.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildDateChip({IconData? icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSecondary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.accentCyan : AppColors.border.withValues(alpha: 0.8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? AppColors.accentCyan : AppColors.textSecondary),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumTotalHeader(double total) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF231A3A).withValues(alpha: 0.8),
            const Color(0xFF140D22).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAD52FF).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFAD52FF).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Spent', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFAD52FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedDateRange == 'Custom' ? 'Custom Range' : _selectedDateRange,
                  style: const TextStyle(color: Color(0xFFAD52FF), fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('₹${total.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(color: Colors.white, fontSize: 42, letterSpacing: -1.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> t) {
    final amount = t['amount'] is num ? (t['amount'] as num).toDouble() : double.tryParse(t['amount'].toString()) ?? 0.0;
    
    // DB column is 'description', not 'title'
    String rawTitle = t['description']?.toString() ?? '';
    String rawCategory = t['category']?.toString() ?? 'Expense';
    
    bool hasTitle = rawTitle.isNotEmpty && rawTitle.toLowerCase() != 'unknown';
    String displayTitle = hasTitle ? rawTitle : _capitalize(rawCategory);
    
    // Use expense_date for display, fallback to created_at
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

    String displaySubtitle = hasTitle ? '$formattedDate • ${_capitalize(rawCategory)}' : formattedDate;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showExpenseDetails(t), 
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(rawCategory).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getCategoryColor(rawCategory).withValues(alpha: 0.2)),
                  ),
                  child: Icon(_getCategoryIcon(rawCategory), color: _getCategoryColor(rawCategory), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayTitle, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(displaySubtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: AppTheme.moneyStyle.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.wallet, size: 64, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 32),
          const Text(
            'No expenses found',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          const Text(
            'Start tracking your spending by adding your first expense.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/add-expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAD52FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Add Expense',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'Inter', letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> t) {
    final amount = t['amount'] is num ? (t['amount'] as num).toDouble() : double.tryParse(t['amount'].toString()) ?? 0.0;
    
    // DB column is 'description', not 'title'
    String rawTitle = t['description']?.toString() ?? '';
    String rawCategory = t['category']?.toString() ?? 'Expense';
    
    bool hasTitle = rawTitle.isNotEmpty && rawTitle.toLowerCase() != 'unknown';
    String displayTitle = hasTitle ? rawTitle : _capitalize(rawCategory);

    final dateStr = t['expense_date']?.toString() ?? t['created_at']?.toString();
    DateTime? date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    String formattedFullDate = date != null ? '${date.day} ${_getMonthString(date.month)} ${date.year}, ${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}' : 'Unknown Date';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4, width: 40,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 32),
                Container(
                  height: 72, width: 72,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(rawCategory).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: _getCategoryColor(rawCategory).withValues(alpha: 0.2), width: 2),
                  ),
                  child: Icon(_getCategoryIcon(rawCategory), color: _getCategoryColor(rawCategory), size: 32),
                ),
                const SizedBox(height: 20),
                Text(displayTitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('₹${amount.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 32),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(LucideIcons.calendar, 'Date', formattedFullDate),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: AppColors.border, height: 1),
                      ),
                      _buildDetailRow(LucideIcons.tag, 'Category', _capitalize(rawCategory)),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: AppColors.border, height: 1),
                      ),
                      _buildDetailRow(
                        LucideIcons.alignLeft, 
                        'Description', 
                        rawTitle.isNotEmpty ? rawTitle : 'No description provided'
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: AppColors.border, height: 1),
                      ),
                      _buildDetailRow(LucideIcons.hash, 'ID', t['id'].toString().substring(0, 8).toUpperCase()),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildBudgetGuardSection(rawCategory, amount),
                
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/edit-expense', extra: t);
                        },
                        icon: const Icon(LucideIcons.edit3, color: AppColors.accentCyan, size: 20),
                        label: const Text('Edit', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w800, fontSize: 16)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: AppColors.accentCyan.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDelete(t['id'].toString());
                        },
                        icon: const Icon(LucideIcons.trash2, color: AppColors.accentRose, size: 20),
                        label: const Text('Delete', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.w800, fontSize: 16)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: AppColors.accentRose.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              value, 
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Expense?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: const Text('This will permanently remove this transaction from your history. This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(expenseServiceProvider).deleteExpense(id);
              // Refresh the stream
              ref.invalidate(expensesStreamProvider);
            }, 
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
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

    // Sort categories by total descending
    final sortedCats = categoryTotals.keys.toList()..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.pieChart, color: AppColors.accentPurple, size: 16),
                SizedBox(width: 8),
                Text('Spending Distribution', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 20),
            // Distribution Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
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
            const SizedBox(height: 20),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: sortedCats.take(4).map((cat) {
                final percent = (categoryTotals[cat]! / totalAll * 100).toStringAsFixed(0);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _getCategoryColor(cat), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('$cat ($percent%)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
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
    // Mock budget logic (Feature 4)
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.accentCyan.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Budget Guard', style: TextStyle(color: AppColors.accentCyan, fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.bgPrimary,
                  color: progress > 0.8 ? AppColors.accentRose : AppColors.accentCyan,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You have ₹${(monthlyGoal - catTotal).toStringAsFixed(2)} left for ${_capitalize(category)} this month.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
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
        final desc = (e['description'] ?? '').toString().replaceAll(',', ' ');
        final amt = e['amount'] ?? '';
        csv += '$date,$cat,"$desc",$amt\n';
      }

      try {
        // Create a temporary file
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/Kanakku_Expenses_${DateTime.now().millisecondsSinceEpoch}.csv';
        final file = File(filePath);
        await file.writeAsString(csv);

        // Share the file (Universal Download)
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
