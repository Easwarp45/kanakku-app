import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/income_service.dart';
import '../../../core/utils/multi_currency_helper.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/error_mapper.dart';

class EditIncomeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> income;
  const EditIncomeScreen({super.key, required this.income});

  @override
  ConsumerState<EditIncomeScreen> createState() => _EditIncomeScreenState();
}

class _EditIncomeScreenState extends ConsumerState<EditIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late ValueNotifier<String> _selectedSource;
  late ValueNotifier<bool> _isRecurring;
  bool _isSaving = false;
  String _selectedCurrency = 'INR';
  late DateTime _selectedDateTime;

  final _quickAmounts = [1000, 5000, 10000, 25000, 50000];

  @override
  void initState() {
    super.initState();
    final rawDesc = widget.income['description']?.toString() ?? '';
    final mcData = MultiCurrencyData.parse(rawDesc);
    
    if (mcData != null) {
      _selectedCurrency = mcData.currency;
      _amountController = TextEditingController(text: mcData.amount.toStringAsFixed(2));
      _descriptionController = TextEditingController(text: MultiCurrencyData.cleanDescription(rawDesc));
    } else {
      _selectedCurrency = 'INR';
      final amount = widget.income['amount']?.toString() ?? '0.00';
      _amountController = TextEditingController(text: amount);
      _descriptionController = TextEditingController(text: rawDesc);
    }
    
    _selectedSource = ValueNotifier(widget.income['source']?.toString() ?? 'salary');
    _isRecurring = ValueNotifier(widget.income['is_recurring'] == true);

    final dateStr = widget.income['income_date']?.toString() ?? widget.income['created_at']?.toString();
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
              primary: AppColors.accentEmerald,
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
              primary: AppColors.accentEmerald,
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

  Future<void> _updateIncome() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final originalAmount = double.tryParse(_amountController.text) ?? 0.0;
        if (originalAmount <= 0) throw Exception('Please enter a valid amount');

        final prefs = ref.read(preferencesProvider);
        final rate = prefs.rates[_selectedCurrency] ?? 1.0;
        final baseAmount = originalAmount / rate;

        String finalDesc = _descriptionController.text.trim();
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

        await ref.read(incomeServiceProvider).updateIncome(
          widget.income['id'].toString(),
          {
            'amount': _selectedCurrency == 'INR' ? originalAmount : baseAmount,
            'source': _selectedSource.value,
            'description': finalDesc,
            'income_date': _selectedDateTime.toIso8601String().split('T')[0],
            'is_recurring': _isRecurring.value,
          },
        );
        
        // Force refresh the stream
        ref.invalidate(incomeStreamProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Income updated successfully!'), backgroundColor: AppColors.accentEmerald),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorMapper.userMessage(e, fallback: 'Unable to save income.')),
              backgroundColor: AppColors.accentRose,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Income', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amount Input
                _buildAmountInput(),
                const SizedBox(height: 16),
                _buildQuickAmounts(),
                const SizedBox(height: 32),

                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        label: 'Custom Name / Description',
                        hint: 'Enter name (e.g. Monthly Salary)',
                        controller: _descriptionController,
                        prefixIcon: const Icon(LucideIcons.alignLeft, color: AppColors.textTertiary),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      const Text('Source', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      _buildSourceSelector(),
                      const SizedBox(height: 24),
                      _buildDateSelector(),
                      const SizedBox(height: 24),
                      // Recurring toggle
                      ValueListenableBuilder<bool>(
                        valueListenable: _isRecurring,
                        builder: (_, isRecurring, _) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recurring Income', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                            Switch(
                              value: isRecurring,
                              onChanged: (v) => _isRecurring.value = v,
                              activeThumbColor: AppColors.accentEmerald,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  text: 'Update Income',
                  icon: LucideIcons.check,
                  isLoading: _isSaving,
                  onPressed: _updateIncome,
                ),
                const SizedBox(height: 24),
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
                        Icon(c.icon, size: 18, color: AppColors.accentEmerald),
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
                        color: AppColors.accentEmerald,
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
                validator: (v) => v!.isEmpty ? 'Required' : null,
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

  Widget _buildQuickAmounts() {
    final info = supportedCurrencies.firstWhere((c) => c.code == _selectedCurrency, orElse: () => supportedCurrencies[0]);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickAmounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final amt = _quickAmounts[i];
          return GestureDetector(
            onTap: () {
              _amountController.text = amt.toString();
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentEmerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
              ),
              child: Text('${info.symbol}${amt >= 1000 ? '${(amt / 1000).toStringAsFixed(0)}K' : amt}',
                style: const TextStyle(color: AppColors.accentEmerald, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSourceSelector() {
    final sources = incomeSources.entries.toList();
    return SizedBox(
      height: 48,
      child: ValueListenableBuilder<String>(
        valueListenable: _selectedSource,
        builder: (_, selected, _) => ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: sources.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final source = sources[i];
            final isSelected = selected == source.key;
            return GestureDetector(
              onTap: () => _selectedSource.value = source.key,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentEmerald.withValues(alpha: 0.15) : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? AppColors.accentEmerald : AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(source.value.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(source.value.displayName, style: TextStyle(
                      color: isSelected ? AppColors.accentEmerald : AppColors.textSecondary,
                      fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    )),
                  ],
                ),
              ),
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
    _descriptionController.dispose();
    _selectedSource.dispose();
    _isRecurring.dispose();
    super.dispose();
  }
}
