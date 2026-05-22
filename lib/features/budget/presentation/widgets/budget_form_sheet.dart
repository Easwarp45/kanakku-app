import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../core/utils/multi_currency_helper.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../data/budget_service.dart';

class BudgetFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? budget;

  const BudgetFormSheet({super.key, this.budget});

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _amountController = TextEditingController();
  String _selectedCategory = 'Food & Dining';
  String _selectedPeriod = 'monthly';
  bool _isLoading = false;

  final List<String> _categories = [
    'Food & Dining',
    'Transportation',
    'Housing',
    'Entertainment',
    'Health',
    'Shopping',
    'Utilities',
    'Investment',
    'Education',
    'Others',
  ];

  final List<Map<String, String>> _periods = [
    {'label': 'Daily', 'value': 'daily'},
    {'label': 'Weekly', 'value': 'weekly'},
    {'label': 'Monthly', 'value': 'monthly'},
    {'label': 'Yearly', 'value': 'yearly'},
  ];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.budget != null) {
      final baseAmount = double.tryParse(widget.budget!['amount']?.toString() ?? '0') ?? 0.0;
      final notifier = ref.read(preferencesProvider.notifier);
      final converted = notifier.convertFromBaseline(baseAmount);
      _amountController.text = converted.toStringAsFixed(2);
      _selectedCategory = widget.budget!['category'] ?? 'Food & Dining';
      _selectedPeriod = widget.budget!['period'] ?? 'monthly';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_amountController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final prefState = ref.read(preferencesProvider);
      final prefCurrency = supportedCurrencies[prefState.currencyIndex];
      final notifier = ref.read(preferencesProvider.notifier);

      final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
      final baseAmount = notifier.convertToBaseline(enteredAmount, prefCurrency.code);

      final data = {
        'category': _selectedCategory,
        'amount': baseAmount,
        'period': _selectedPeriod,
      };

      if (widget.budget != null) {
        data['id'] = widget.budget!['id'];
      }

      await ref.read(budgetServiceProvider).upsertBudget(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _delete() async {
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
      setState(() => _isLoading = true);
      try {
        await ref.read(budgetServiceProvider).deleteBudget(widget.budget!['id']);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentRose),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefState = ref.watch(preferencesProvider);
    final prefCurrency = supportedCurrencies[prefState.currencyIndex];
    final notifier = ref.read(preferencesProvider.notifier);

    final amountText = _amountController.text;
    final enteredAmount = double.tryParse(amountText) ?? 0.0;
    String conversionLabel = '';

    if (enteredAmount > 0 && prefCurrency.code != 'INR') {
      final baseAmount = notifier.convertToBaseline(enteredAmount, prefCurrency.code);
      conversionLabel = '≈ ${CurrencyFormatter.format(baseAmount, 'INR')}';
    }

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.budget == null ? 'Establish New Budget' : 'Refine Budget Logic',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Define your category constraints and period cycles.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            
            // Category Selection
            const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                      selectedColor: AppColors.accentPurple,
                      backgroundColor: AppColors.bgSecondary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? Colors.transparent : AppColors.border)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Amount Input
            CustomTextField(
              label: 'Budget Amount',
              hint: '0.00',
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icon(prefCurrency.icon, color: AppColors.textTertiary, size: 18),
            ),
            if (conversionLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  conversionLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Period Selection
            const Text('Reporting Cycle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
            const SizedBox(height: 12),
            Row(
              children: _periods.map((p) {
                final isSelected = _selectedPeriod == p['value'];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = p['value']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.15) : AppColors.bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? AppColors.accentCyan : AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            p['label']!,
                            style: TextStyle(
                              color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            if (widget.budget != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  label: const Text('Purge Constraint'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRose,
                    side: const BorderSide(color: AppColors.accentRose),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            GradientButton(
              text: widget.budget == null ? 'Authorize Budget' : 'Update Parameters',
              icon: widget.budget == null ? LucideIcons.plus : LucideIcons.check,
              onPressed: _submit,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
