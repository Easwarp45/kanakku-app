import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/expense_service.dart';
import '../../../../core/utils/multi_currency_helper.dart';
import '../../../../core/utils/custom_category_helper.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../../core/database/schema_constants.dart';
import '../../../../core/utils/error_mapper.dart';
import '../../../../core/utils/feedback_helper.dart';
import '../../../../core/utils/validators.dart';

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
  late final TextEditingController _customCategoryController;
  late final ValueNotifier<String> _selectedCategory;
  late final ValueNotifier<String> _selectedPaymentMethod;
  bool _isSaving = false;
  String _selectedCurrency = 'INR';
  late DateTime _selectedDateTime;

  final List<String> _baseCategories = [
    'Food & Dining',
    'Transportation',
    'Housing',
    'Entertainment',
    'Health',
    'Shopping',
    'Utilities',
  ];

  final List<String> _paymentMethods = [
    'UPI',
    'Cash',
    'Card',
    'Bank Transfer',
    'Other',
  ];

  // Maps display names → DB expense_category enum values
  static const _categoryToEnum = expenseCategoryToEnum;

  // Reverse map: DB enum → display name
  static const _enumToCategory = expenseEnumToCategory;

  static const _paymentMethodToEnum = {
    'UPI': 'upi',
    'Cash': 'cash',
    'Card': 'card',
    'Bank Transfer': 'bank_transfer',
    'Other': 'other',
  };

  static const _enumToPaymentMethod = {
    'upi': 'UPI',
    'cash': 'Cash',
    'card': 'Card',
    'bank_transfer': 'Bank Transfer',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    final rawDesc = widget.expense['description']?.toString() ?? '';
    final mcData = MultiCurrencyData.parse(rawDesc);
    final customCat = CustomCategoryData.parse(rawDesc);

    // Extract custom category name if present
    String cleanDescText = rawDesc;
    if (customCat != null) {
      cleanDescText = CustomCategoryData.cleanDescription(cleanDescText);
      _customCategoryController = TextEditingController(text: customCat.name);
    } else {
      _customCategoryController = TextEditingController();
    }

    if (mcData != null) {
      _selectedCurrency = mcData.currency;
      _amountController = TextEditingController(text: mcData.amount.toStringAsFixed(2));
      _descController = TextEditingController(text: MultiCurrencyData.cleanDescription(cleanDescText));
    } else {
      _selectedCurrency = 'INR';
      final amount = widget.expense['amount']?.toString() ?? '0.00';
      _amountController = TextEditingController(text: amount);
      _descController = TextEditingController(text: cleanDescText);
    }
    
    // Map DB enum value back to display name
    String dbCat = widget.expense['category']?.toString() ?? 'other';
    String displayCat = 'Food & Dining';
    if (customCat != null) {
      displayCat = customCat.name;
    } else {
      displayCat = _enumToCategory[dbCat] ?? _baseCategories.first;
    }
    _selectedCategory = ValueNotifier<String>(displayCat);

    // Initialize Payment Method
    String dbPaymentMethod = widget.expense['payment_method']?.toString() ?? 'upi';
    String displayPaymentMethod = _enumToPaymentMethod[dbPaymentMethod] ?? 'UPI';
    _selectedPaymentMethod = ValueNotifier<String>(displayPaymentMethod);

    final dateStr = widget.expense['expense_date']?.toString() ?? widget.expense['created_at']?.toString();
    _selectedDateTime = dateStr != null ? (DateTime.tryParse(dateStr) ?? DateTime.now()) : DateTime.now();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentCyan,
              surface: AppColors.bgElevated,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentCyan,
              surface: AppColors.bgElevated,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    } else {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _updateExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      
      try {
        final originalAmount = double.tryParse(_amountController.text) ?? 0.0;
        if (originalAmount <= 0) throw Exception('Please enter a valid amount');

        final prefs = ref.read(preferencesProvider);
        final rate = prefs.rates[_selectedCurrency] ?? 1.0;
        final baseAmount = originalAmount / rate;

        String finalDesc = _descController.text.trim();
        final isCustom = _selectedCategory.value == 'Custom...' || !_baseCategories.contains(_selectedCategory.value);

        // Handle Custom Category serialization inside the description field.
        if (isCustom) {
          final customName = _selectedCategory.value == 'Custom...'
              ? _customCategoryController.text.trim()
              : _selectedCategory.value;
          final categoryToken = CustomCategoryData(name: customName.isNotEmpty ? customName : 'Other').toToken();
          finalDesc = '$categoryToken $finalDesc';
        }

        if (_selectedCurrency != 'INR') {
          final mcData = MultiCurrencyData(
            amount: originalAmount,
            currency: _selectedCurrency,
            rate: rate,
            baseAmount: baseAmount,
            baseCurrency: 'INR',
          );
          finalDesc = '${mcData.toToken()} $finalDesc';
        }

        await ref.read(expenseServiceProvider).updateExpense(
          widget.expense['id'].toString(),
          {
            'description': finalDesc,
            'amount': _selectedCurrency == 'INR' ? originalAmount : baseAmount,
            'category': isCustom ? 'other' : (_categoryToEnum[_selectedCategory.value] ?? 'other'),
            'payment_method': _paymentMethodToEnum[_selectedPaymentMethod.value] ?? 'upi',
            'expense_date': _selectedDateTime.toIso8601String().split('T')[0],
          }
        );
        
        // Refresh the stream to show updated data
        ref.invalidate(expensesStreamProvider);
        
        if (mounted) {
          FeedbackHelper.showSuccess(context, 'Expense updated successfully!');
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          FeedbackHelper.showError(context, ErrorMapper.userMessage(e, fallback: 'Unable to save expense.'));
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
    // Watch current transaction list to retrieve previously used custom categories
    final expensesAsync = ref.watch(expensesStreamProvider);
    final Set<String> customCategories = {};
    expensesAsync.whenData((expenses) {
      for (var e in expenses) {
        final desc = e['description']?.toString() ?? '';
        final customCat = CustomCategoryData.parse(desc);
        if (customCat != null && customCat.name.trim().isNotEmpty) {
          customCategories.add(customCat.name.trim());
        }
      }
    });

    final currentSelection = _selectedCategory.value;
    if (currentSelection != 'Custom...' && !_baseCategories.contains(currentSelection)) {
      customCategories.add(currentSelection);
    }

    final allCategories = [
      ..._baseCategories,
      ...customCategories.where((c) => !_baseCategories.contains(c)),
      'Custom...',
    ];

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
                        label: 'Custom Name / Description',
                        hint: 'Enter name (e.g. McDonald\'s)',
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
                      _buildCategorySelector(allCategories),
                      ValueListenableBuilder<String>(
                        valueListenable: _selectedCategory,
                        builder: (context, selectedCategory, _) {
                          if (selectedCategory == 'Custom...') {
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: CustomTextField(
                                label: 'Custom Category Name',
                                hint: 'Enter category name (e.g. Subscriptions)',
                                controller: _customCategoryController,
                                prefixIcon: const Icon(LucideIcons.tag, color: AppColors.textTertiary),
                                validator: (v) => _selectedCategory.value == 'Custom...' && v!.isEmpty ? 'Required' : null,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentMethodSelector(),
                      const SizedBox(height: 24),
                      _buildDateSelector(),
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
    final prefs = ref.watch(preferencesProvider);
    final preferredCurrencyCode = supportedCurrencies[prefs.currencyIndex].code;
    
    final amountText = _amountController.text;
    final originalAmount = double.tryParse(amountText) ?? 0.0;
    String conversionLabel = '';
    
    if (originalAmount > 0 && _selectedCurrency != preferredCurrencyCode) {
      final rate = prefs.rates[_selectedCurrency] ?? 1.0;
      final baseAmount = originalAmount / rate;
      final prefRate = prefs.rates[preferredCurrencyCode] ?? 1.0;
      final convertedAmount = baseAmount * prefRate;
      conversionLabel = '≈ ${CurrencyFormatter.format(convertedAmount, preferredCurrencyCode)}';
    }

    final info = supportedCurrencies.firstWhere((c) => c.code == _selectedCurrency, orElse: () => supportedCurrencies[0]);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PopupMenuButton<String>(
              initialValue: _selectedCurrency,
              tooltip: 'Select Currency',
              color: AppColors.bgElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (code) {
                setState(() {
                  _selectedCurrency = code;
                });
              },
              itemBuilder: (context) {
                return supportedCurrencies.map((c) {
                  return PopupMenuItem<String>(
                    value: c.code,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 18, color: AppColors.accentCyan),
                        const SizedBox(width: 10),
                        Text('${c.code} (${c.symbol})', style: const TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      info.symbol,
                      style: AppTheme.moneyStyle.copyWith(
                        fontSize: 24,
                        color: AppColors.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.chevronDown, color: AppColors.textSecondary, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            IntrinsicWidth(
              child: TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTheme.moneyStyle.copyWith(
                  fontSize: 48,
                  color: AppColors.textPrimary,
                ),
                onChanged: (_) {
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
                validator: Validators.validateAmount,
              ),
            ),
          ],
        ),
        if (conversionLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            conversionLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySelector(List<String> categories) {
    final categoryMeta = <String, ({IconData icon, String emoji})>{
      'Food & Dining': (icon: LucideIcons.utensilsCrossed, emoji: '🍽'),
      'Transportation': (icon: LucideIcons.car, emoji: '🚗'),
      'Housing': (icon: LucideIcons.home, emoji: '🏠'),
      'Entertainment': (icon: LucideIcons.play, emoji: '🎬'),
      'Health': (icon: LucideIcons.heartPulse, emoji: '💊'),
      'Shopping': (icon: LucideIcons.shoppingBag, emoji: '🛍'),
      'Utilities': (icon: LucideIcons.zap, emoji: '⚡'),
      'Custom...': (icon: LucideIcons.tag, emoji: '🏷'),
    };

    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ValueListenableBuilder<String>(
          valueListenable: _selectedCategory,
          builder: (context, selectedCategory, _) {
            return Row(
              children: categories.map((category) {
                final isSelected = selectedCategory == category;
                final meta = categoryMeta[category] ?? (icon: LucideIcons.tag, emoji: '🏷');
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

  Widget _buildPaymentMethodSelector() {
    final methodMeta = <String, ({IconData icon, String label})>{
      'UPI': (icon: LucideIcons.smartphone, label: 'UPI'),
      'Cash': (icon: LucideIcons.coins, label: 'Cash'),
      'Card': (icon: LucideIcons.creditCard, label: 'Card'),
      'Bank Transfer': (icon: LucideIcons.wallet, label: 'Bank Transfer'),
      'Other': (icon: LucideIcons.helpCircle, label: 'Other'),
    };

    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ValueListenableBuilder<String>(
          valueListenable: _selectedPaymentMethod,
          builder: (context, selectedMethod, _) {
            return Row(
              children: _paymentMethods.map((method) {
                final isSelected = selectedMethod == method;
                final meta = methodMeta[method] ?? (icon: LucideIcons.circle, label: method);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _selectedPaymentMethod.value = method,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.15) : AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? AppColors.accentCyan : AppColors.border, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(meta.icon, color: isSelected ? AppColors.accentCyan : AppColors.textSecondary, size: 16),
                          const SizedBox(width: 8),
                          Text(method, style: TextStyle(color: isSelected ? AppColors.accentCyan : AppColors.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
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

  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: _selectDateTime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Date & Time', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, color: AppColors.textTertiary, size: 20),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM dd, yyyy  •  hh:mm a').format(_selectedDateTime),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _customCategoryController.dispose();
    _selectedCategory.dispose();
    _selectedPaymentMethod.dispose();
    super.dispose();
  }
}
