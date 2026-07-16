import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.borderRadius = 16.0,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Why Ink: Using a standard Container with background decoration inside an InkWell 
    // causes the Container's background to be drawn over the Material ink splash. 
    // Replacing Container with Ink paints the decoration onto the Material, ensuring the 
    // custom cyan splash/ripple animation is drawn on top of the card background.
    Widget cardContent = Ink(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.bgTertiary.withValues(alpha: 0.8), // Darker base for mobile glass
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AppColors.accentCyan.withValues(alpha: 0.1),
          highlightColor: AppColors.accentCyan.withValues(alpha: 0.05),
          child: cardContent,
        ),
      ),
    );
  }
}
