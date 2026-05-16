import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class IncomeDetailScreen extends StatelessWidget {
  const IncomeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('Transaction Detail', style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAmountHero(),
              const SizedBox(height: 24),
              _buildPerformanceCard(),
              const SizedBox(height: 24),
              _buildTransactionProfile(),
              const SizedBox(height: 24),
              _buildReceiptCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF065f46), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.accentEmerald.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.briefcase, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Global Tech Solutions Inc.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Salary Deposit', style: TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('+₹16,500.00', style: AppTheme.moneyStyle.copyWith(fontSize: 38, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Oct 30, 2023 • 09:00 AM', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Income Performance', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Text('Last 6 months trend analysis', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          // Mini bar chart (visual approximation)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [14000, 15000, 15500, 16000, 16000, 16500].map((val) {
              final height = (val / 16500) * 60;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 28,
                    height: height,
                    decoration: BoxDecoration(
                      color: val == 16500 ? AppColors.accentEmerald : AppColors.accentEmerald.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct']
                .map((m) => Text(m, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionProfile() {
    final rows = [
      {'label': 'Source', 'value': 'Global Tech Solutions Inc.'},
      {'label': 'Category', 'value': 'Salary'},
      {'label': 'Frequency', 'value': 'Monthly'},
      {'label': 'Account', 'value': 'HDFC Premium •••• 9002'},
      {'label': 'Reference ID', 'value': 'TXN-2023-OCT-GTS-001'},
    ];
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transaction Profile', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          ...rows.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r['label']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text(r['value']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReceiptCard() {
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
          const Icon(LucideIcons.checkCircle, color: AppColors.accentEmerald, size: 20),
          const SizedBox(width: 10),
          const Text('Digital Receipt Verified', style: TextStyle(color: AppColors.accentEmerald, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
