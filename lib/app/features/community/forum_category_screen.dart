import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/kpb_theme_ext.dart';

class ForumCategoryScreen extends StatefulWidget {
  const ForumCategoryScreen({
    super.key,
    required this.category,
    required this.accentColor,
    required this.accentBg,
    required this.icon,
  });

  final ForumCategoryModel category;
  final Color accentColor;
  final Color accentBg;
  final IconData icon;

  @override
  State<ForumCategoryScreen> createState() => _ForumCategoryScreenState();
}

class _ForumCategoryScreenState extends State<ForumCategoryScreen> {
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: GetBuilder<AppController>(
        builder: (_) {
          final tags = controller.visibleForumTopicTags;
          final articles = _relatedArticles(controller);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: isDark ? context.kpb.cardBg : widget.accentColor,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    controller.resolve(widget.category.label),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark 
                           ? [widget.accentColor.withValues(alpha: 0.8), widget.accentColor.withValues(alpha: 0.3)]
                           : [widget.accentColor, widget.accentColor.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Icon(widget.icon,
                            size: 96, color: Colors.white.withValues(alpha: 0.15)),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(KpbSpacing.pagePad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.resolve(widget.category.description),
                        style: KpbTextStyles.body.copyWith(color: context.kpb.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: KpbSpacing.xl),
                      _JoinCtaCard(
                        accent: widget.accentColor,
                        onWhatsApp: _launchWhatsApp,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              if (tags.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        KpbSpacing.pagePad, 0, KpbSpacing.pagePad, KpbSpacing.sm),
                    child: Text(
                      Get.locale?.languageCode == 'en'
                          ? 'Filter by topic'
                          : 'Filtrer par sujet',
                      style: KpbTextStyles.titleMd.copyWith(color: context.kpb.textPrimary),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: KpbSpacing.pagePad),
                      itemCount: tags.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return _TagChip(
                            label: Get.locale?.languageCode == 'en'
                                ? 'All'
                                : 'Tous',
                            selected: _selectedTag == null,
                            accent: widget.accentColor,
                            isDark: isDark,
                            onTap: () => setState(() => _selectedTag = null),
                          );
                        }
                        final tag = tags[i - 1];
                        return _TagChip(
                          label: controller.resolve(tag.label),
                          selected: _selectedTag == tag.id,
                          accent: widget.accentColor,
                          isDark: isDark,
                          onTap: () =>
                              setState(() => _selectedTag = tag.id),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: KpbSpacing.lg)),
              ],

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad, 0, KpbSpacing.pagePad, KpbSpacing.sm),
                  child: Text(
                    Get.locale?.languageCode == 'en'
                        ? 'Related articles'
                        : 'Articles liés',
                    style: KpbTextStyles.titleMd.copyWith(color: context.kpb.textPrimary),
                  ),
                ),
              ),

              if (articles.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(KpbSpacing.pagePad),
                    child: KpbCard(
                      child: Column(
                        children: [
                          Icon(Icons.article_outlined,
                              size: 48, color: context.kpb.gray300),
                          const SizedBox(height: 12),
                          Text(
                            Get.locale?.languageCode == 'en'
                                ? 'No articles tagged yet. Join the WhatsApp group to ask questions.'
                                : 'Aucun article marqué pour l\'instant. Rejoins le groupe WhatsApp pour poser tes questions.',
                            style: KpbTextStyles.caption.copyWith(color: context.kpb.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.pagePad),
                  sliver: SliverList.separated(
                    itemCount: articles.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: KpbSpacing.sm),
                    itemBuilder: (ctx, i) => _ArticleRow(
                      article: articles[i],
                      controller: controller,
                      accent: widget.accentColor,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: KpbSpacing.xl)),
            ],
          );
        },
      ),
    );
  }

  List<ArticleModel> _relatedArticles(AppController controller) {
    final all = controller.publishedArticles;
    final tags = controller.visibleForumTopicTags.map((t) => t.id).toSet();
    // Prefer articles matching the selected tag; else match category-level tags
    return all.where((a) {
      if (_selectedTag != null) return a.tags.contains(_selectedTag);
      if (a.category == widget.category.id) return true;
      return a.tags.any(tags.contains);
    }).take(10).toList();
  }
}

Future<void> _launchWhatsApp() async {
  const url = 'https://chat.whatsapp.com/KPBEducation';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    Get.snackbar(
      'WhatsApp',
      'Impossible d\'ouvrir WhatsApp. Vérifiez que l\'app est installée.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    );
  }
}

class _JoinCtaCard extends StatelessWidget {
  const _JoinCtaCard({required this.accent, required this.onWhatsApp, required this.isDark});
  final Color accent;
  final Future<void> Function() onWhatsApp;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = isDark ? KpbColors.stitchCyberCyan : accent;
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        color: resolvedAccent.withValues(alpha: 0.10),
        borderRadius: KpbRadius.xlBr,
        border: Border.all(color: resolvedAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: resolvedAccent.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.forum_rounded, color: resolvedAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Get.locale?.languageCode == 'en'
                          ? 'Join the conversation'
                          : 'Rejoins la conversation',
                      style: KpbTextStyles.titleLg.copyWith(color: context.kpb.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Get.locale?.languageCode == 'en'
                          ? 'The in-app forum is launching soon. Connect on WhatsApp to discuss with other students and KPB counselors now.'
                          : "Le forum in-app arrive bientôt. Rejoins WhatsApp pour discuter avec d'autres étudiants et les conseillers KPB dès maintenant.",
                      style: KpbTextStyles.bodySm.copyWith(color: context.kpb.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          KpbButton(
            text: Get.locale?.languageCode == 'en' ? 'Open WhatsApp group' : 'Ouvrir le groupe WhatsApp',
            onPressed: onWhatsApp,
            bgColor: resolvedAccent,
            icon: Icons.chat_bubble_rounded,
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = isDark ? KpbColors.stitchCyberCyan : accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? resolvedAccent : context.kpb.cardBg,
          borderRadius: KpbRadius.pillBr,
          border: Border.all(
            color: selected ? resolvedAccent : context.kpb.gray200,
          ),
          boxShadow: selected ? (isDark ? null : KpbShadow.soft) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : context.kpb.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({
    required this.article,
    required this.controller,
    required this.accent,
  });
  final ArticleModel article;
  final AppController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: KpbRadius.mdBr,
            ),
            child: Icon(Icons.article_rounded, color: accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.resolve(article.title),
                  style: KpbTextStyles.titleMd.copyWith(color: context.kpb.textPrimary, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  controller.resolve(article.summary),
                  style: KpbTextStyles.caption.copyWith(color: context.kpb.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: context.kpb.gray300, size: 22),
        ],
      ),
    );
  }
}
