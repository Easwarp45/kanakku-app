import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';

class EditGroupExpenseScreen extends StatefulWidget {
  const EditGroupExpenseScreen({super.key});

  @override
  State<EditGroupExpenseScreen> createState() => _EditGroupExpenseScreenState();
}

class _EditGroupExpenseScreenState extends State<EditGroupExpenseScreen> {
  final _amountController = TextEditingController(text: '1480.00');
  final _descController = TextEditingController(text: 'Taj Hotel Dinner');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('Edit Group Expense', style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Delete', style: TextStyle(color: AppColors.accentRose)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildAmountSection(),
              const SizedBox(height: 24),
              _buildDetailsCard(),
              const SizedBox(height: 24),
              _buildSplitSection(),
              const SizedBox(height: 32),
              GradientButton(text: 'Update Expense', icon: LucideIcons.save, onPressed: () => context.pop()),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('\$', style: TextStyle(color: AppColors.textSecondary, fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              IntrinsicWidth(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 48, fontWeight: FontWeight.w800, fontFamily: 'JetBrainsMono'),
                  decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                ),
              ),
            ],
          ),
          Divider(color: AppColors.borderSubtle),
          const Text('Paid by Marcus Vane • Oct 24, 2023', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EXPENSE DETAILS', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Description',
              prefixIcon: const Icon(LucideIcons.alignLeft, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(LucideIcons.calendar, 'Date', 'Oct 24, 2023'),
          const SizedBox(height: 12),
          _buildDetailRow(LucideIcons.tag, 'Category', 'Food & Dining'),
          const SizedBox(height: 12),
          _buildDetailRow(LucideIcons.users, 'Group', 'The Vane Family'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSplitSection() {
    final splits = [
      {'name': 'Marcus Vane', 'share': '₹493.33', 'paid': true},
      {'name': 'Elena Vane', 'share': '₹493.33', 'paid': false},
      {'name': 'Julian Vane', 'share': '₹493.34', 'paid': false}
    ];
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SPLIT BREAKDOWN', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          ...splits.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: AppColors.accentCyan.withValues(alpha: 0.12),
                    child: Text((s['name'] as String).substring(0, 1), style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                Expanded(child: Text(s['name'] as String, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                Text(s['share'] as String, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Icon(s['paid'] as bool ? LucideIcons.checkCircle : LucideIcons.circle,
                    color: s['paid'] as bool ? AppColors.accentEmerald : AppColors.textTertiary, size: 18),
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
