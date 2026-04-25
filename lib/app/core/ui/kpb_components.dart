import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KPB Education — Component Library
// ─────────────────────────────────────────────────────────────────────────────

// ── Input Decoration ──────────────────────────────────────────────────────────
class KpbInputDecoration {
  static InputDecoration build(
    BuildContext context, {
    required String label,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      filled: true,
      fillColor: context.kpb.cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KpbRadius.md),
        borderSide: BorderSide(color: context.kpb.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KpbRadius.md),
        borderSide: BorderSide(color: context.kpb.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KpbRadius.md),
        borderSide: const BorderSide(color: KpbColors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KpbRadius.md),
        borderSide: const BorderSide(color: KpbColors.error),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
    this.textColor,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title, 
              style: textColor != null 
                  ? KpbTextStyles.title.copyWith(color: textColor) 
                  : KpbTextStyles.title,
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor == Colors.white ? KpbColors.stitchCyberCyan : KpbColors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── KPB Card (base) ───────────────────────────────────────────────────────────
class KpbCard extends StatelessWidget {
  const KpbCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KpbSpacing.md),
    this.margin,
    this.color = KpbColors.bgCard,
    this.borderRadius = KpbRadius.lgBr,
    this.shadow = KpbShadow.card,
    this.onTap,
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Color color;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadow;
  final VoidCallback? onTap;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final effectiveColor = color == KpbColors.bgCard ? c.cardBg : color;
    final effectiveShadow = identical(shadow, KpbShadow.card) ? c.cardShadow : shadow;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        margin: margin,
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: borderRadius,
          boxShadow: effectiveShadow,
          border: border,
        ),
        child: child,
      ),
    );
  }
}

// ── Gradient Hero Card ────────────────────────────────────────────────────────
class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({
    super.key,
    required this.child,
    this.gradient = KpbColors.heroGradient,
    this.padding = const EdgeInsets.all(KpbSpacing.lg),
    this.borderRadius = KpbRadius.xlBr,
    this.height,
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: KpbShadow.blue,
      ),
      child: child,
    );
  }
}

// ── Status / Category Badge ───────────────────────────────────────────────────
class KpbBadge extends StatelessWidget {
  const KpbBadge({
    super.key,
    required this.label,
    this.color = KpbColors.blue,
    this.textColor = Colors.white,
    this.icon,
    this.small = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final double px = small ? 8 : 10;
    final double py = small ? 3 : 5;
    final double fs = small ? 10 : 11;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
      decoration: BoxDecoration(
        color: color,
        borderRadius: KpbRadius.pillBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fs + 2, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Outlined Badge (light bg) ─────────────────────────────────────────────────
class KpbBadgeLight extends StatelessWidget {
  const KpbBadgeLight({
    super.key,
    required this.label,
    this.bgColor = KpbColors.skyLight,
    this.textColor = KpbColors.blue,
    this.icon,
  });

  final String label;
  final Color bgColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: KpbRadius.pillBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Match Score Badge ─────────────────────────────────────────────────────────
class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (score >= 80) {
      color = KpbColors.success;
    } else if (score >= 60) {
      color = KpbColors.gold;
    } else {
      color = KpbColors.sky;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KpbRadius.pillBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal Scroll Section ─────────────────────────────────────────────────
class HScrollSection extends StatelessWidget {
  const HScrollSection({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.actionLabel,
    this.onAction,
    this.itemWidth = 180,
    this.height = 200,
    this.textColor,
  });

  final String title;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double itemWidth;
  final double height;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          actionLabel: actionLabel,
          onAction: onAction,
          textColor: textColor,
        ),
        const SizedBox(height: KpbSpacing.sm),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.pagePad,
            ),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: KpbSpacing.sm),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

// ── Quick Action Button ───────────────────────────────────────────────────────
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return GestureDetector(
      onTap: onTap,
      child: KpbCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: KpbRadius.mdBr,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Country Card ──────────────────────────────────────────────────────────────
class CountryCard extends StatelessWidget {
  const CountryCard({
    super.key,
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.width = 160,
    this.isSaved = false,
    this.onSave,
  });

  final String flag;
  final String name;
  final String subtitle;
  final VoidCallback onTap;
  final double width;
  final bool isSaved;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: KpbRadius.lgBr,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flag area
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.surfaceBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KpbRadius.lg),
                ),
              ),
              child: Center(
                child: Text(flag, style: const TextStyle(fontSize: 44)),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: KpbTextStyles.caption.copyWith(color: c.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

// ── Field Card ────────────────────────────────────────────────────────────────
class FieldCard extends StatelessWidget {
  const FieldCard({
    super.key,
    required this.name,
    required this.description,
    required this.accentColor,
    required this.onTap,
    this.width = 180,
    this.careers = const [],
    this.isSaved = false,
    this.onSave,
    this.matchScore,
  });

  final String name;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;
  final double width;
  final List<String> careers;
  final bool isSaved;
  final VoidCallback? onSave;
  final int? matchScore;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: KpbRadius.lgBr,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color header
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KpbRadius.lg),
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                  ),
                  if (matchScore != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: KpbRadius.pillBr,
                        ),
                        child: Text(
                          '$matchScore%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Description
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  description,
                  style: KpbTextStyles.bodySm,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scholarship Card ──────────────────────────────────────────────────────────
class ScholarshipMiniCard extends StatelessWidget {
  const ScholarshipMiniCard({
    super.key,
    required this.name,
    required this.countryFlag,
    required this.amount,
    required this.matchScore,
    required this.onTap,
    this.width = 200,
  });

  final String name;
  final String countryFlag;
  final String amount;
  final int matchScore;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KpbColors.bgDarkCard,
          borderRadius: KpbRadius.lgBr,
          border: Border.all(color: KpbColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(countryFlag, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                MatchBadge(score: matchScore),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KpbColors.textDarkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Institution Mini Card ──────────────────────────────────────────────────────
class InstitutionMiniCard extends StatelessWidget {
  const InstitutionMiniCard({
    super.key,
    required this.name,
    required this.countryFlag,
    required this.location,
    required this.tuitionLabel,
    required this.onTap,
    this.isPartner = false,
    required this.score,
    this.width = 200,
  });

  final String name;
  final String countryFlag;
  final String location;
  final String tuitionLabel;
  final bool isPartner;
  final int score;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KpbColors.bgDarkCard,
          borderRadius: KpbRadius.lgBr,
          border: Border.all(color: KpbColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(countryFlag, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                AdmissionMeter(score: score, size: 28, strokeWidth: 3, showLabel: false),
                if (isPartner) ...[
                   const SizedBox(width: 8),
                   const KpbBadge(label: 'Partenaire', color: KpbColors.stitchDeepPurple, small: true),
                ]
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              location,
              style: const TextStyle(
                fontSize: 11,
                color: KpbColors.textDarkSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Keep locations from bleeding
            ),
            const Spacer(),
            Text(
              tuitionLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KpbColors.textDarkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Completion Ring ───────────────────────────────────────────────────
class CompletionRing extends StatelessWidget {
  const CompletionRing({
    super.key,
    required this.value,
    this.size = 64,
    this.strokeWidth = 6,
    this.color = Colors.white,
  });

  final double value; // 0.0 – 1.0
  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: strokeWidth,
            backgroundColor: color.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation(color),
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class KpbEmptyState extends StatelessWidget {
  const KpbEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.action,
    this.iconColor,
    this.iconBgColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  /// Optional fully custom action widget (takes priority over actionLabel+onAction).
  final Widget? action;
  final Color? iconColor;
  final Color? iconBgColor;

  @override
  Widget build(BuildContext context) {
    final tc = context.kpb;
    final effectiveIconColor = iconColor ?? KpbColors.blue;
    final effectiveIconBg = iconBgColor ?? tc.skyLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: effectiveIconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: effectiveIconColor),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: tc.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Info Row (label + value) ──────────────────────────────────────────────────
class KpbInfoRow extends StatelessWidget {
  const KpbInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = KpbColors.blue,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: KpbRadius.smBr,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KpbTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.kpb.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thin Divider ─────────────────────────────────────────────────────────────
class KpbDivider extends StatelessWidget {
  const KpbDivider({super.key, this.height = 1, this.indent = 0});
  final double height;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      thickness: height,
      indent: indent,
      color: context.kpb.divider,
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
// ── Pull-to-refresh wrapper ───────────────────────────────────────────────────
/// Wraps a scrollable child with a styled RefreshIndicator.
class KpbRefresh extends StatelessWidget {
  const KpbRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: KpbColors.blue,
      backgroundColor: Theme.of(context).cardColor,
      displacement: 60,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KpbErrorState — full-screen error with retry button
//
// Use when: data required to render the screen could not be loaded AND
// no cached data is available (e.g. profile == null after sync failure).
// ─────────────────────────────────────────────────────────────────────────────
class KpbErrorState extends StatelessWidget {
  const KpbErrorState({
    super.key,
    this.title = 'Connexion impossible',
    this.subtitle =
        'Vérifiez votre connexion internet et réessayez.',
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KpbSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.kpb.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 34,
                color: KpbColors.error,
              ),
            ),
            const SizedBox(height: KpbSpacing.lg),
            Text(
              title,
              style: KpbTextStyles.title.copyWith(color: context.kpb.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              subtitle,
              style: KpbTextStyles.bodySm.copyWith(
                color: context.kpb.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: KpbSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KpbSyncErrorBanner — subtle top banner for connectivity issues
//
// Use when: catalog data is always available (MockCatalog) but remote
// sync failed. User can still use the screen; banner informs them that
// personalised data may be outdated.
// ─────────────────────────────────────────────────────────────────────────────
class KpbSyncErrorBanner extends StatelessWidget {
  const KpbSyncErrorBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.kpb.warningLight,
      padding: const EdgeInsets.symmetric(
          horizontal: KpbSpacing.pagePad, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 16, color: KpbColors.warning),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Données potentiellement obsolètes — hors ligne',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: KpbColors.warning,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'Réessayer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KpbColors.warning,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ── Admission Meter Gauge ───────────────────────────────────────────────────
class AdmissionMeter extends StatelessWidget {
  const AdmissionMeter({
    super.key,
    required this.score,
    this.size = 46,
    this.strokeWidth = 4,
    this.showLabel = true,
  });

  final int score;
  final double size;
  final double strokeWidth;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutExpo,
      tween: Tween(begin: 0, end: score.toDouble()),
      builder: (context, value, child) {
        final currentScore = value.toInt();
        Color currentColor;
        if (value < 50) {
          currentColor = KpbColors.error;
        } else if (value < 80) {
          currentColor = KpbColors.warning;
        } else {
          currentColor = KpbColors.success;
        }

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: strokeWidth,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              CircularProgressIndicator(
                value: value / 100,
                strokeWidth: strokeWidth,
                color: currentColor,
                strokeCap: StrokeCap.round,
              ),
              if (showLabel)
                Text(
                  '$currentScore%',
                  style: TextStyle(
                    color: currentColor,
                    fontSize: size * 0.28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staggered Slide Animation — Jobs Edition
// ─────────────────────────────────────────────────────────────────────────────
class StaggeredSlide extends StatelessWidget {
  const StaggeredSlide({
    super.key, 
    required this.child, 
    this.index = 0,
    this.delayMs = 80,
  });

  final Widget child;
  final int index;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutExpo,
      tween: Tween(begin: 0.0, end: 1.0),
      // Logic for staggered delay
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KpbButton — Jobs Edition
// ─────────────────────────────────────────────────────────────────────────────
class KpbButton extends StatelessWidget {
  const KpbButton({
    super.key,
    this.label,
    this.text,
    this.onTap,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.secondary = false,
    this.loading = false,
    this.backgroundColor,
    this.bgColor,
  });

  final String? label;
  final String? text;
  final VoidCallback? onTap;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool secondary;
  final bool loading;
  final Color? backgroundColor;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? text ?? '';
    final effectiveOnTap = onTap ?? onPressed;
    final effectiveBg = backgroundColor ?? bgColor ?? (secondary ? context.kpb.surfaceBg : KpbColors.blue);
    final effectiveFg = secondary ? KpbColors.blue : Colors.white;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: effectiveFg,
              ),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 18, color: effectiveFg),
          ),
        Text(
          effectiveLabel,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: effectiveFg,
          ),
        ),
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: effectiveBg,
        borderRadius: KpbRadius.mdBr,
        child: InkWell(
          onTap: loading ? null : effectiveOnTap,
          borderRadius: KpbRadius.mdBr,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: content,
          ),
        ),
      ),
    );
  }
}
