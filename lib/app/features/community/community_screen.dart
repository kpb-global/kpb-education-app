import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/ui/kpb_components.dart';
import '../search/search_screen.dart';
import 'forum_category_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Community Screen
//
// Accessible via:
//   • Get.to() from Home "Articles" section
//   • Get.to() from Profile "Moi" quick-access section
//
// All UI elements are functional:
//   • Search bar  → opens SearchScreen
//   • Hashtag chips → filter articles by tag (stateful)
//   • WhatsApp CTA  → opens WhatsApp group via url_launcher
//   • Article cards → open detail bottom sheet
//   • Forum categories → "coming soon" snackbar (honest feedback)
// ─────────────────────────────────────────────────────────────────────────────

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return GetBuilder<AppController>(
      builder: (_) {
        final allArticles = controller.publishedArticles;
        final categories = controller.visibleForumCategories;
        final tags = controller.visibleForumTopicTags;

        // Filter articles by selected tag
        final articles = _selectedTag == null
            ? allArticles.take(10).toList()
            : allArticles
                .where((a) =>
                    (a.tags as List).contains(_selectedTag))
                .toList();

        return KpbRefresh(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            slivers: [
              // ── App Bar ─────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: context.kpb.pageBg,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.canPop(context)
                      ? Navigator.pop(context)
                      : null,
                ),
                title: const Text('Communauté', style: KpbTextStyles.headline),
                actions: [
                  // Search icon opens SearchScreen
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => Get.to(() => const SearchScreen()),
                    tooltip: 'Rechercher',
                  ),
                ],
              ),

              // ── Hero header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: KpbColors.heroGradient,
                  ),
                  padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad, KpbSpacing.lg,
                      KpbSpacing.pagePad, KpbSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Apprendre ensemble 🌍',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Articles, guides et conseils de nos experts pour réussir votre projet d\'études.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Hashtag filter chips ─────────────────────────────────
              if (tags.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    color: context.kpb.cardBg,
                    padding: const EdgeInsets.symmetric(
                        vertical: KpbSpacing.sm),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: KpbSpacing.pagePad),
                      child: Row(
                        children: [
                          // "Tous" chip
                          _TagChip(
                            label: 'Tous',
                            selected: _selectedTag == null,
                            onTap: () =>
                                setState(() => _selectedTag = null),
                          ),
                          const SizedBox(width: 8),
                          ...tags.map((tag) {
                            final label =
                                controller.resolve(tag.label);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _TagChip(
                                label: '#$label',
                                selected: _selectedTag == label,
                                onTap: () => setState(() =>
                                    _selectedTag = _selectedTag == label
                                        ? null
                                        : label),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Articles section ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad, KpbSpacing.lg,
                      KpbSpacing.pagePad, KpbSpacing.sm),
                  child: Row(
                    children: [
                      const Text('Articles', style: KpbTextStyles.title),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.kpb.skyLight,
                          borderRadius: KpbRadius.pillBr,
                        ),
                        child: Text(
                          '${articles.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: KpbColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (articles.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.pagePad,
                        vertical: KpbSpacing.xl),
                    child: KpbEmptyState(
                      icon: Icons.article_outlined,
                      title: 'Aucun article',
                      subtitle: _selectedTag != null
                          ? 'Aucun article pour #$_selectedTag'
                          : 'Les articles arrivent bientôt.',
                      actionLabel: _selectedTag != null
                          ? 'Voir tous les articles'
                          : null,
                      onAction: _selectedTag != null
                          ? () => setState(() => _selectedTag = null)
                          : null,
                    ),
                  ),
                )
              else ...[
                // Featured article (first)
                if (articles.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: KpbSpacing.pagePad),
                      child: _FeaturedArticle(
                        article: articles.first,
                        controller: controller,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: KpbSpacing.sm)),

                // Remaining articles
                if (articles.length > 1)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.pagePad),
                    sliver: SliverList.separated(
                      itemCount: articles.length - 1,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KpbSpacing.sm),
                      itemBuilder: (ctx, i) => _ArticleCard(
                        article: articles[i + 1],
                        controller: controller,
                      ),
                    ),
                  ),
              ],

              // ── Forum categories ──────────────────────────────────────
              if (categories.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        KpbSpacing.pagePad, KpbSpacing.xl,
                        KpbSpacing.pagePad, KpbSpacing.sm),
                    child: Text('Forum', style: KpbTextStyles.title),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.pagePad),
                  sliver: SliverList.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: KpbSpacing.sm),
                    itemBuilder: (ctx, i) {
                      final cat = categories[i];
                      final colors = _categoryColors(i);
                      return KpbCard(
                        onTap: () => Get.to(
                          () => ForumCategoryScreen(
                            category: cat,
                            accentColor: colors.fg,
                            accentBg: colors.bg,
                            icon: colors.icon,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.bg,
                                borderRadius: KpbRadius.mdBr,
                              ),
                              child: Icon(colors.icon,
                                  color: colors.fg, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(controller.resolve(cat.label),
                                      style: KpbTextStyles.titleMd),
                                  const SizedBox(height: 3),
                                  Text(
                                    controller
                                        .resolve(cat.description),
                                    style: KpbTextStyles.caption,
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: context.kpb.gray300, size: 18),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              // ── WhatsApp CTA ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad, KpbSpacing.xl,
                      KpbSpacing.pagePad, KpbSpacing.sm),
                  child: GestureDetector(
                    onTap: _launchWhatsApp,
                    child: GradientHeroCard(
                      padding: const EdgeInsets.all(KpbSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rejoindre le groupe WhatsApp',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+2 000 étudiants — Conseils, entraide & actu',
                                  style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.75),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: KpbRadius.pillBr,
                            ),
                            child: const Text(
                              'Rejoindre →',
                              style: TextStyle(
                                color: KpbColors.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  ({Color bg, Color fg, IconData icon}) _categoryColors(int i) {
    const list = [
      (
        bg: Color(0xFFEEF2FF),
        fg: KpbColors.blue,
        icon: Icons.school_outlined
      ),
      (
        bg: Color(0xFFF0FDF4),
        fg: KpbColors.success,
        icon: Icons.workspace_premium_outlined
      ),
      (
        bg: Color(0xFFFFFBEB),
        fg: KpbColors.gold,
        icon: Icons.home_outlined
      ),
      (
        bg: Color(0xFFEFF6FF),
        fg: KpbColors.sky,
        icon: Icons.language_outlined
      ),
      (
        bg: Color(0xFFFFF1F2),
        fg: KpbColors.error,
        icon: Icons.forum_outlined
      ),
    ];
    return list[i % list.length];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Launch WhatsApp group
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _launchWhatsApp() async {
  // Replace with actual WhatsApp group invite link
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

// ─────────────────────────────────────────────────────────────────────────────
// Hashtag filter chip
// ─────────────────────────────────────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? KpbColors.blue : context.kpb.cardBg,
          borderRadius: KpbRadius.pillBr,
          border: Border.all(
            color:
                selected ? KpbColors.blue : context.kpb.gray200,
          ),
          boxShadow: selected ? KpbShadow.blue : KpbShadow.card,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.kpb.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured article card (large)
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturedArticle extends StatelessWidget {
  const _FeaturedArticle(
      {required this.article, required this.controller});

  final dynamic article;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      onTap: () => _openArticleSheet(context, article, controller),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored header
          Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [KpbColors.blue, KpbColors.sky],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(KpbRadius.lg),
                topRight: Radius.circular(KpbRadius.lg),
              ),
            ),
            child: Center(
              child: Icon(Icons.article_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 56),
            ),
          ),
          const SizedBox(height: 12),
          const KpbBadge(
            label: '📌 À la une',
            color: KpbColors.blue,
          ),
          const SizedBox(height: 8),
          Text(
            controller.resolve(article.title),
            style: KpbTextStyles.title,
          ),
          const SizedBox(height: 6),
          Text(
            controller.resolve(article.summary),
            style: KpbTextStyles.bodySm,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (article.tags as List<String>)
                .take(3)
                .map((tag) => KpbBadgeLight(label: '#$tag'))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Regular article card
// ─────────────────────────────────────────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  const _ArticleCard(
      {required this.article, required this.controller});

  final dynamic article;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      onTap: () => _openArticleSheet(context, article, controller),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.kpb.surfaceBg,
              borderRadius: KpbRadius.mdBr,
            ),
            child: Icon(Icons.article_outlined,
                color: context.kpb.gray300, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.resolve(article.title),
                  style: KpbTextStyles.titleMd,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  controller.resolve(article.summary),
                  style: KpbTextStyles.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((article.tags as List<String>).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  KpbBadgeLight(
                      label:
                          '#${(article.tags as List<String>).first}'),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: context.kpb.gray300, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Article detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
void _openArticleSheet(
  BuildContext context,
  dynamic article,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          // Hero header
          Container(
            height: 140,
            decoration: const BoxDecoration(
              gradient: KpbColors.heroGradient,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(KpbRadius.xl),
              ),
            ),
            child: Center(
              child: Icon(Icons.article_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 72),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                KpbSpacing.lg, KpbSpacing.pagePad, KpbSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tags
                if ((article.tags as List<String>).isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: (article.tags as List<String>)
                        .take(3)
                        .map((tag) => KpbBadgeLight(label: '#$tag'))
                        .toList(),
                  ),
                const SizedBox(height: 12),
                Text(
                  controller.resolve(article.title),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.kpb.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  controller.resolve(article.body ?? article.summary),
                  style: TextStyle(
                    fontSize: 15,
                    color: context.kpb.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                if (article.publishedAt != null)
                  Text(
                    'Publié le ${_formatDate(article.publishedAt as DateTime)}',
                    style: TextStyle(
                        fontSize: 12, color: context.kpb.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime dt) {
  const months = [
    '', 'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
  ];
  return '${dt.day} ${months[dt.month]} ${dt.year}';
}
