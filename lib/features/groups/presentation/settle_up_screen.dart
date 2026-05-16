import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_provider.dart';
import '../data/group_service.dart';

class SettleUpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? settlementData;
  const SettleUpScreen({super.key, this.settlementData});

  @override
  ConsumerState<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends ConsumerState<SettleUpScreen> {
  final _noteController = TextEditingController();
  bool _isSaving = false;

  Future<void> _confirmSettlement() async {
    if (widget.settlementData == null) return;
    
    setState(() => _isSaving = true);
    try {
      await ref.read(groupServiceProvider).createSettlement(
        groupId: widget.settlementData!['groupId'],
        paidTo: widget.settlementData!['paidTo'],
        amount: widget.settlementData!['amount'],
        note: _noteController.text.trim(),
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successfully recorded!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentRose));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.settlementData;
    final amount = data?['amount'] ?? 0.0;
    final name = data?['name'] ?? 'Recipient';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.x, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('SETTLE UP', style: TextStyle(fontSize: 12, color: AppColors.accentEmerald, fontWeight: FontWeight.w700, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40, 
                backgroundColor: AppColors.accentEmerald.withValues(alpha: 0.1),
                child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.accentEmerald, fontSize: 32, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 16),
              Text('You are paying $name', style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 8),
              Text('₹${amount.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(color: AppColors.accentEmerald, fontSize: 40)),
              const SizedBox(height: 32),
              GlassCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(LucideIcons.landmark, color: AppColors.accentPurple),
                      ),
                      title: const Text('Pay via UPI', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: const Text('GPay, PhonePe, Paytm', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
                      onTap: () {},
                    ),
                    Divider(color: AppColors.borderSubtle),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(LucideIcons.checkCircle, color: AppColors.accentEmerald),
                      ),
                      title: const Text('Record cash payment', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Mark as settled offline', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GlassCard(
                margin: EdgeInsets.zero,
                child: TextField(
                  controller: _noteController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Add a note (e.g. for Goa trip)',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    border: InputBorder.none,
                    icon: Icon(LucideIcons.messageSquare, color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              GradientButton(
                text: 'Confirm Payment',
                icon: LucideIcons.shieldCheck,
                isLoading: _isSaving,
                onPressed: _confirmSettlement,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
