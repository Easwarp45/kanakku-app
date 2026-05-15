import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class GroupExpenseEntryScreen extends StatefulWidget {
  const GroupExpenseEntryScreen({super.key});

  @override
  State<GroupExpenseEntryScreen> createState() => _GroupExpenseEntryScreenState();
}

class _GroupExpenseEntryScreenState extends State<GroupExpenseEntryScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedPaidBy = 'You (Marcus)';

  final _members = [
    {'name': 'You (Marcus)', 'amount': '\$450.00', 'checked': true},
    {'name': 'Elena Vance', 'role': 'Controller', 'amount': '\$450.00', 'checked': true},
    {'name': 'Julian Thorne', 'role': 'Director', 'amount': '\$450.00', 'checked': true},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Column(
          children: [
            Text('EXECUTIVE', style: TextStyle(fontSize: 10, color: AppColors.accentCyan, fontWeight: FontWeight.w700, letterSpacing: 2)),
            Text('Group Expense Entry', style: TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildGroupTag(),
              const SizedBox(height: 24),
              _buildAmountInput(),
              const SizedBox(height: 24),
              GlassCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    CustomTextField(
                      label: 'Description',
                      hint: 'e.g. Team Dinner',
                      controller: _descController,
                      prefixIcon: const Icon(LucideIcons.alignLeft, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildPaidBySection(),
              const SizedBox(height: 20),
              _buildSplitSection(),
              const SizedBox(height: 32),
              GradientButton(text: 'Log Group Expense', icon: LucideIcons.check, onPressed: () => context.pop()),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupTag() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentCyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.users, color: AppColors.accentCyan, size: 14),
              const SizedBox(width: 6),
              const Text('Alpha Venture Club', style: TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Text('12 Active Members', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('\$', style: AppTheme.moneyStyle.copyWith(fontSize: 32, color: AppColors.textSecondary)),
        const SizedBox(width: 4),
        IntrinsicWidth(
          child: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTheme.moneyStyle.copyWith(fontSize: 52, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 52),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaidBySection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paid by', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          _buildMemberRow('You (Marcus)', 'Paid the total', true),
          const SizedBox(height: 12),
          _buildMemberRow('Elena Vance', 'Controller', false),
          const SizedBox(height: 12),
          _buildMemberRow('Julian Thorne', 'Director', false),
        ],
      ),
    );
  }

  Widget _buildMemberRow(String name, String role, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPaidBy = name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentCyan.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.accentCyan.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 16, backgroundColor: AppColors.accentCyan.withValues(alpha: 0.15),
                child: Text(name.substring(0, 1), style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700, fontSize: 13))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              Text(role, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ])),
            if (selected) const Icon(LucideIcons.checkCircle, color: AppColors.accentCyan, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Split Equally', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ..._members.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                CircleAvatar(radius: 16, backgroundColor: AppColors.accentPurple.withValues(alpha: 0.12),
                    child: Text((m['name'] as String).substring(0, 1), style: const TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.w700, fontSize: 13))),
                const SizedBox(width: 10),
                Expanded(child: Text(m['name'] as String, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                Text(m['amount'] as String, style: AppTheme.moneyStyle.copyWith(fontSize: 14, color: AppColors.accentCyan)),
                const SizedBox(width: 8),
                Icon(LucideIcons.checkCircle, color: (m['checked'] as bool) ? AppColors.accentCyan : AppColors.textTertiary, size: 18),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
