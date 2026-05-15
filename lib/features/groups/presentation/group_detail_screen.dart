import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('EXECUTIVE', style: TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w700, letterSpacing: 2)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(LucideIcons.plus, color: AppColors.accentCyan), onPressed: () => context.push('/group-expense-entry')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGroupHeader(),
              const SizedBox(height: 24),
              _buildMemberLedger(),
              const SizedBox(height: 24),
              _buildEfficiencyBadge(),
              const SizedBox(height: 24),
              _buildRecentTransactions(context),
              const SizedBox(height: 24),
              GradientButton(text: 'Settle Up', icon: LucideIcons.check, onPressed: () => context.push('/settle-up')),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('The Vane Family', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Shared Trust & Household', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      ],
    );
  }

  Widget _buildMemberLedger() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GROUP MEMBER LEDGER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _buildMemberRow('Marcus Vane', 'OWED TO GROUP', '\$2,150', AppColors.accentCyan),
          Divider(color: AppColors.borderSubtle, height: 24),
          _buildMemberRow('Elena Vane', 'OWES YOU', '\$840.50', AppColors.accentEmerald),
          Divider(color: AppColors.borderSubtle, height: 24),
          _buildMemberRow('Julian Vane', 'YOU OWE', '\$120.00', AppColors.accentRose),
        ],
      ),
    );
  }

  Widget _buildMemberRow(String name, String status, String amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.12),
                child: Text(name.substring(0, 1), style: TextStyle(color: color, fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
        Text(amount, style: AppTheme.moneyStyle.copyWith(fontSize: 16, color: color)),
      ],
    );
  }

  Widget _buildEfficiencyBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.zap, color: AppColors.accentEmerald, size: 18),
          const SizedBox(width: 8),
          const Text('GROUP EFFICIENCY', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Text('94.2%', style: AppTheme.moneyStyle.copyWith(fontSize: 20, color: AppColors.accentEmerald)),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    final txns = [
      {'name': 'Le Bernardin Dinner', 'paid': 'Paid by Marcus Vane • Oct 24, 2023', 'amount': '\$1,480.00'},
      {'name': 'Alpine Lodge Booking', 'paid': 'Paid by Elena Vane • Oct 22, 2023', 'amount': '\$4,200.00'},
      {'name': 'Luxury Provisioning', 'paid': 'Paid by You • Oct 20, 2023', 'amount': '\$890.45'},
      {'name': 'Chauffeur Service Fuel', 'paid': 'Paid by Julian Vane • Oct 18, 2023', 'amount': '\$312.00'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            TextButton.icon(
              onPressed: () => context.push('/group-expense-entry'),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: txns.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.borderSubtle, height: 1),
            itemBuilder: (context, i) {
              final t = txns[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.accentRose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.receipt, color: AppColors.accentRose, size: 18),
                ),
                title: Text(t['name']!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
                subtitle: Text(t['paid']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                trailing: Text(t['amount']!, style: AppTheme.moneyStyle.copyWith(fontSize: 14, color: AppColors.textPrimary)),
                onTap: () => context.push('/edit-group-expense'),
              );
            },
          ),
        ),
      ],
    );
  }
}
