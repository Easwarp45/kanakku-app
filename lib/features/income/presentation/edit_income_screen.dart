import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/income_service.dart';

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

  final _quickAmounts = [1000, 5000, 10000, 25000, 50000];

  @override
  void initState() {
    super.initState();
    final amount = widget.income['amount']?.toString() ?? '0';
    _amountController = TextEditingController(text: amount);
    _descriptionController = TextEditingController(text: widget.income['description']?.toString() ?? '');
    _selectedSource = ValueNotifier(widget.income['source']?.toString() ?? 'salary');
    _isRecurring = ValueNotifier(widget.income['is_recurring'] == true);
  }

  Future<void> _updateIncome() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final amount = double.tryParse(_amountController.text) ?? 0.0;
        if (amount <= 0) throw Exception('Please enter a valid amount');

        await ref.read(incomeServiceProvider).updateIncome(
          widget.income['id'].toString(),
          {
            'amount': amount,
            'source': _selectedSource.value,
            'description': _descriptionController.text.trim(),
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
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentRose),
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
                        label: 'Description',
                        hint: 'e.g. Monthly Salary, Freelance Project',
                        controller: _descriptionController,
                        prefixIcon: const Icon(LucideIcons.alignLeft, color: AppColors.textTertiary),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      const Text('Source', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      _buildSourceSelector(),
                      const SizedBox(height: 24),
                      // Recurring toggle
                      ValueListenableBuilder<bool>(
                        valueListenable: _isRecurring,
                        builder: (_, isRecurring, __) => Row(
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('₹', style: AppTheme.moneyStyle.copyWith(fontSize: 32, color: AppColors.accentEmerald)),
        const SizedBox(width: 8),
        IntrinsicWidth(
          child: TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTheme.moneyStyle.copyWith(fontSize: 48, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              border: InputBorder.none, enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none, contentPadding: EdgeInsets.zero, filled: false,
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAmounts() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickAmounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final amt = _quickAmounts[i];
          return GestureDetector(
            onTap: () => _amountController.text = amt.toString(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentEmerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
              ),
              child: Text('₹${amt >= 1000 ? '${(amt / 1000).toStringAsFixed(0)}K' : amt}',
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
        builder: (_, selected, __) => ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: sources.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
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

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _selectedSource.dispose();
    _isRecurring.dispose();
    super.dispose();
  }
}
