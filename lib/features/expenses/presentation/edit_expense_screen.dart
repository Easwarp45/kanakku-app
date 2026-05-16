import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/expense_service.dart';

class EditExpenseScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> expense;
  const EditExpenseScreen({super.key, required this.expense});

  @override
  ConsumerState<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends ConsumerState<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descController;
  late final ValueNotifier<String> _selectedCategory;
  bool _isSaving = false;

  final List<String> _categories = [
    'Food & Dining',
    'Transportation',
    'Housing',
    'Entertainment',
    'Health',
    'Shopping',
    'Utilities',
  ];

  // Maps display names → DB expense_category enum values
  static const _categoryToEnum = <String, String>{
    'Food & Dining': 'food',
    'Transportation': 'transport',
    'Housing': 'housing',
    'Entertainment': 'entertainment',
    'Health': 'healthcare',
    'Shopping': 'shopping',
    'Utilities': 'utilities',
  };

  // Reverse map: DB enum → display name
  static const _enumToCategory = <String, String>{
    'food': 'Food & Dining',
    'transport': 'Transportation',
    'housing': 'Housing',
    'entertainment': 'Entertainment',
    'healthcare': 'Health',
    'shopping': 'Shopping',
    'utilities': 'Utilities',
    'other': 'Food & Dining',
  };

  @override
  void initState() {
    super.initState();
    final amount = widget.expense['amount']?.toString() ?? '0.00';
    _amountController = TextEditingController(text: amount);
    // DB column is 'description', not 'title'
    _descController = TextEditingController(
      text: widget.expense['description']?.toString() ?? ''
    );
    
    // Map DB enum value back to display name
    String dbCat = widget.expense['category']?.toString() ?? 'other';
    String displayCat = _enumToCategory[dbCat] ?? _categories.first;
    _selectedCategory = ValueNotifier<String>(displayCat);
  }

  Future<void> _updateExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      
      try {
        final amount = double.tryParse(_amountController.text) ?? 0.0;
        await ref.read(expenseServiceProvider).updateExpense(
          widget.expense['id'].toString(),
          {
            'description': _descController.text.trim(),
            'amount': amount,
            'category': _categoryToEnum[_selectedCategory.value] ?? 'other',
          }
        );
        
        // Refresh the stream to show updated data
        ref.invalidate(expensesStreamProvider);
        
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating expense: $e'), backgroundColor: AppColors.accentRose),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Expense',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAmountInput(),
                const SizedBox(height: 32),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        label: 'Description',
                        hint: 'What was this for?',
                        controller: _descController,
                        prefixIcon: const Icon(LucideIcons.alignLeft, color: AppColors.textTertiary),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Category',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCategorySelector(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  text: 'Update Expense',
                  icon: LucideIcons.save,
                  isLoading: _isSaving,
                  onPressed: _updateExpense,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '₹',
              style: AppTheme.moneyStyle.copyWith(
                fontSize: 32,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            IntrinsicWidth(
              child: TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTheme.moneyStyle.copyWith(
                  fontSize: 48,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categoryMeta = <String, ({IconData icon, String emoji})>{
      'Food & Dining': (icon: LucideIcons.utensilsCrossed, emoji: '🍽'),
      'Transportation': (icon: LucideIcons.car, emoji: '🚗'),
      'Housing': (icon: LucideIcons.home, emoji: '🏠'),
      'Entertainment': (icon: LucideIcons.play, emoji: '🎬'),
      'Health': (icon: LucideIcons.heartPulse, emoji: '💊'),
      'Shopping': (icon: LucideIcons.shoppingBag, emoji: '🛍'),
      'Utilities': (icon: LucideIcons.zap, emoji: '⚡'),
    };

    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
      child: ValueListenableBuilder<String>(
        valueListenable: _selectedCategory,
        builder: (context, selectedCategory, _) {
          return Row(
            children: _categories.map((category) {
              final isSelected = selectedCategory == category;
              final meta = categoryMeta[category] ?? (icon: LucideIcons.circle, emoji: '•');
              return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _selectedCategory.value = category,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accentPurple.withValues(alpha: 0.15) : AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppColors.accentPurple : AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Text(meta.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(category, style: TextStyle(color: isSelected ? AppColors.accentPurple : AppColors.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            );
            }).toList(),
          );
        },
      ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _selectedCategory.dispose();
    super.dispose();
  }
}
