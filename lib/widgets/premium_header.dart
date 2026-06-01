import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';

class PremiumHeader extends StatelessWidget {
  final String? category;
  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final bool showBackButton;
  final double bottomRadius;
  final Widget? bottomChild;

  const PremiumHeader({
    super.key,
    this.category,
    required this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.showBackButton = true,
    this.bottomRadius = 28,
    this.bottomChild,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton && context.canPop();
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        bottomChild != null ? 16 : 28,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
      ),
      child: FadeInEntrance(
        delay: const Duration(milliseconds: 80),
        offset: const Offset(0, -16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (canPop) ...[
                  TapBounce(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category != null)
                        Text(
                          category!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 2.5,
                            color: Colors.white60,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (category != null) const SizedBox(height: 2),
                      titleWidget ??
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      if (subtitleWidget != null) ...[
                        const SizedBox(height: 4),
                        subtitleWidget!,
                      ] else if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            if (bottomChild != null) ...[
              const SizedBox(height: 16),
              bottomChild!,
            ],
          ],
        ),
      ),
    );
  }
}
