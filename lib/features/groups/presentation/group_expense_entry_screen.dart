import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../data/group_service.dart';

class GroupExpenseEntryScreen extends ConsumerStatefulWidget {
  final String? groupId;
  const GroupExpenseEntryScreen({super.key, this.groupId});

  @override
  ConsumerState<GroupExpenseEntryScreen> createState() => _GroupExpenseEntryScreenState();
}

class _GroupExpenseEntryScreenState extends ConsumerState<GroupExpenseEntryScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSaving = false;
  
  String _selectedCategory = 'other';
  final List<String> _categories = [
    'food',
    'transport',
    'entertainment',
    'housing',
    'shopping',
    'health',
    'other'
  ];

  Future<void> _saveExpense() async {
    if (widget.groupId == null) return;
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid details')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(groupServiceProvider).addGroupExpense(
        groupId: widget.groupId!,
        description: title,
        amount: amount,
        category: _selectedCategory,
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) return const Scaffold(body: Center(child: Text('Error: No Group ID')));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.x, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('ADD EXPENSE', style: TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w700, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                label: 'Description',
                hint: 'What was this for?',
                controller: _titleController,
                prefixIcon: const Icon(LucideIcons.fileText, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Amount',
                hint: '₹ 0.00',
                controller: _amountController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(LucideIcons.indianRupee, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 32),
              
              const Text('Category', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat.toUpperCase()),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedCategory = cat),
                        selectedColor: AppColors.accentCyan,
                        backgroundColor: AppColors.bgSecondary,
                        labelStyle: TextStyle(color: isSelected ? AppColors.bgPrimary : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              const Text('Paid By', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Text('You')),
                title: const Text('You', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
                onTap: () {},
              ),
              Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 16),
              const Text('Split Options', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.split, color: AppColors.accentPurple),
                ),
                title: const Text('Split Equally', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Everyone pays an equal share', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
                onTap: () {},
              ),
              const SizedBox(height: 48),
              GradientButton(
                text: 'Save Expense',
                icon: LucideIcons.check,
                isLoading: _isSaving,
                onPressed: _saveExpense,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
