import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class GroupsListScreen extends StatelessWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text('SHARED PORTFOLIOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentPurple, letterSpacing: 2)),
            )),
            SliverToBoxAdapter(child: const SizedBox(height: 12)),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text('Financial Collectives', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            )),
            SliverToBoxAdapter(child: const SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildGroupCard(context, 'The Vane Family', 'Shared Trust & Household', 'AGGREGATE BALANCE', '\$2,480,120.00', '+12.4% this month', true, AppColors.accentCyan)),
            SliverToBoxAdapter(child: _buildGroupCard(context, 'Swiss Alps \'24', 'Luxury Expedition Fund', 'GROUP CONTRIBUTION', '\$45,200 of \$60k', null, false, AppColors.accentPurple)),
            SliverToBoxAdapter(child: _buildGroupCard(context, 'Executive Loft', 'Shared Utilities & Rent', 'OWED BY YOU', '-\$1,840.12', null, false, AppColors.accentRose)),
            SliverToBoxAdapter(child: _buildGroupCard(context, 'Alpha Venture Club', 'High-yield collective investment pool\nwith 12 partners.', 'MY EQUITY / TOTAL POOL', '\$342K / \$4.2M', null, false, AppColors.accentEmerald)),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.accentPurple,
        foregroundColor: Colors.white,
        child: const Icon(LucideIcons.plus),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('EXECUTIVE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          IconButton(
            icon: const Icon(LucideIcons.search, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, String name, String subtitle, String label, String value, String? badge, bool showTrend, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: GlassCard(
        margin: EdgeInsets.zero,
        onTap: () => context.push('/group-detail'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: accent.withValues(alpha: 0.15),
                    child: Text(name.substring(0, 1), style: TextStyle(color: accent, fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary, size: 18),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(value, style: AppTheme.moneyStyle.copyWith(fontSize: 16, color: AppColors.textPrimary)),
                    ],
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.trendingUp, color: AppColors.accentEmerald, size: 12),
                          const SizedBox(width: 4),
                          Text(badge, style: const TextStyle(color: AppColors.accentEmerald, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
