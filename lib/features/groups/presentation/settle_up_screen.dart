import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class SettleUpScreen extends StatelessWidget {
  const SettleUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('Settle Up - Executive Ledger', style: TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNetDebtCard(),
              const SizedBox(height: 24),
              _buildPendingSettlements(),
              const SizedBox(height: 24),
              _buildBalanceTrends(),
              const SizedBox(height: 24),
              _buildFinalSettlement(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetDebtCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [AppColors.accentCyan, AppColors.accentPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Net Group Debt', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Finalize the quarterly expenditure ledger for the Global Expansion project team.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          Text('\$1,030.50', style: AppTheme.moneyStyle.copyWith(fontSize: 36, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Total outstanding balance', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPendingSettlements() {
    final members = [
      {'name': 'Marcus Vane', 'role': 'Chief Controller', 'amount': '-\$240.00', 'color': AppColors.accentRose},
      {'name': 'Elena Soros', 'role': 'Operations Director', 'amount': '+\$840.50', 'color': AppColors.accentEmerald},
      {'name': 'Julian Chen', 'role': 'Strategy Lead', 'amount': '-\$120.00', 'color': AppColors.accentRose},
      {'name': 'Shared Reserves', 'role': 'Contingency Fund', 'amount': '+\$550.00', 'color': AppColors.accentCyan},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pending Settlements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        GlassCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.borderSubtle, height: 1),
            itemBuilder: (context, i) {
              final m = members[i];
              final color = m['color'] as Color;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.12),
                    child: Text((m['name'] as String).substring(0, 1), style: TextStyle(color: color, fontWeight: FontWeight.w700))),
                title: Text(m['name'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(m['role'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                trailing: Text(m['amount'] as String, style: AppTheme.moneyStyle.copyWith(fontSize: 16, color: color, fontWeight: FontWeight.w700)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceTrends() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Balance Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTrendItem('This Month', '+\$450', AppColors.accentEmerald),
              const SizedBox(width: 12),
              _buildTrendItem('Last Month', '-\$220', AppColors.accentRose),
              const SizedBox(width: 12),
              _buildTrendItem('3-Month Avg', '+\$130', AppColors.accentCyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value, style: AppTheme.moneyStyle.copyWith(fontSize: 16, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalSettlement() {
    return Builder(builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Final Settlement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Clicking the button below will execute the automated clearing house (ACH) transfers for all pending balances.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 16),
        GradientButton(text: 'Execute Settlement', icon: LucideIcons.zap, onPressed: () => context.pop()),
      ],
    ));
  }
}
