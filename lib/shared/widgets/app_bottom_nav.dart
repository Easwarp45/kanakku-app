import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  static const _routes = ['/dashboard', '/income-list', '/groups', '/insights', '/settings'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: LucideIcons.layoutDashboard, label: 'Dash', index: 0, currentIndex: currentIndex, route: _routes[0]),
              _NavItem(icon: LucideIcons.trendingUp, label: 'Ledger', index: 1, currentIndex: currentIndex, route: _routes[1]),
              _NavItem(icon: LucideIcons.lock, label: 'Vault', index: 2, currentIndex: currentIndex, route: _routes[2]),
              _NavItem(icon: LucideIcons.barChart2, label: 'Stats', index: 3, currentIndex: currentIndex, route: _routes[3]),
              _NavItem(icon: LucideIcons.monitor, label: 'Assets', index: 4, currentIndex: currentIndex, route: _routes[4]),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentCyan.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppColors.accentCyan : AppColors.textTertiary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.accentCyan : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
