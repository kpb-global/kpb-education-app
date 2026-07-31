import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbAppBar — barre de titre unifiée (architecture §9, primitives L3)
// ─────────────────────────────────────────────────────────────────────────────
// Un seul rendu pour le titre, le retour et la safe-area : plus de one-off
// AppBar/SliverAppBar stylés à la main dans chaque écran. Les couleurs et le
// titre viennent du thème ; `subtitle` ajoute une ligne de contexte.
class KpbAppBar extends StatelessWidget implements PreferredSizeWidget {
  const KpbAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final subtitleHeight = subtitle != null ? 20.0 : 0.0;
    return Size.fromHeight(kToolbarHeight + subtitleHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final fg = foregroundColor ?? c.textPrimary;
    final baseTitle = Theme.of(context).appBarTheme.titleTextStyle ??
        KpbTextStyles.headlineSm;

    final Widget titleWidget = subtitle == null
        ? Text(
            title,
            style: baseTitle.copyWith(color: fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: baseTitle.copyWith(color: fg, fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: KpbTextStyles.caption.copyWith(color: c.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );

    return AppBar(
      title: Semantics(header: true, child: titleWidget),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      bottom: bottom,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }
}
