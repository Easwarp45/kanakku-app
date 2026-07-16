import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int>? onTapOverride;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    this.onTapOverride,
  });

  static const _routes = ['/dashboard', '/transactions', '/income-list', '/groups', '/insights', '/settings'];

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  void _handleTap(BuildContext context, int index, String route) {
    HapticFeedback.selectionClick();

    if (index == widget.currentIndex) {
      return;
    }

    if (widget.onTapOverride != null) {
      widget.onTapOverride!(index);
    } else {
      context.go(route);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.bgTertiary.withValues(alpha: 0.95),
                    AppColors.bgSecondary.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.15), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    _NavItem(
                      icon: LucideIcons.home,
                      label: 'Home',
                      index: 0,
                      currentIndex: widget.currentIndex,
                      onTap: () => _handleTap(context, 0, AppBottomNav._routes[0]),
                    ),
                    _NavItem(
                      icon: LucideIcons.receipt,
                      label: 'Expenses',
                      index: 1,
                      currentIndex: widget.currentIndex,
                      onTap: () => _handleTap(context, 1, AppBottomNav._routes[1]),
                    ),
                    _NavItem(
                      icon: LucideIcons.wallet,
                      label: 'Income',
                      index: 2,
                      currentIndex: widget.currentIndex,
                      onTap: () => _handleTap(context, 2, AppBottomNav._routes[2]),
                    ),
                    _NavItem(
                      icon: LucideIcons.users,
                      label: 'Groups',
                      index: 3,
                      currentIndex: widget.currentIndex,
                      onTap: () => _handleTap(context, 3, AppBottomNav._routes[3]),
                    ),
                    _NavItem(
                      icon: LucideIcons.brain,
                      label: 'Intel',
                      index: 4,
                      currentIndex: widget.currentIndex,
                      onTap: () => _handleTap(context, 4, AppBottomNav._routes[4]),
                    ),
                    _NavItem(
                      icon: LucideIcons.user,
                      label: 'Me',
                      index: 5,
                      currentIndex: widget.currentIndex,
                      onTap: () => _handleTap(context, 5, AppBottomNav._routes[5]),
                    ),
                  ],
                ),
              ),
            ),
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final activeColor = AppColors.accentPurple;
    final color = isActive ? activeColor : AppColors.textSecondary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        width: isActive ? 44 : 0,
                        height: isActive ? 44 : 0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentPurple.withValues(alpha: 0.35),
                              AppColors.accentCyan.withValues(alpha: 0.22),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppColors.accentPurple.withValues(alpha: 0.55),
                            width: 1,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.accentPurple.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      AnimatedScale(
                        scale: isActive ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: Icon(icon, color: color, size: isActive ? 22 : 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: isActive ? 10.5 : 9.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                    height: 1.0,
                  ),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
