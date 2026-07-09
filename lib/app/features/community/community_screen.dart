import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/components/kpb_empty_state.dart';
import '../../core/ui/components/kpb_refresh.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../alumni/alumni_directory_screen.dart';
import '../parcours/parcours_screen.dart';
import '../salon/salon_screen.dart';
import '../search/search_screen.dart';
import 'forum_category_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Community Screen — App-engagement handoff restyle (navy/blue).
//
// HONEST-DATA NOTE: the design mock depicts a social forum (join-able groups
// with member counts + a member post feed). That layer has NO backend, so it is
// deliberately NOT built here. This screen restyles only what is REAL:
//   • Search bar        → opens SearchScreen
//   • Hashtag chips     → filter published articles by tag (stateful)
//   • WhatsApp CTA      → opens the real WhatsApp group via url_launcher
//   • Article cards     → open a detail bottom sheet (real article content)
//   • Forum categories  → open ForumCategoryScreen (real articles-by-topic;
//                          the in-app forum itself is honestly "launching soon")
// The design's blue "shield" note is kept as a STATIC safety tip (advice, not
// fabricated moderation data).
// ─────────────────────────────────────────────────────────────────────────────

// Local palette — same per-file pattern as the other App-engagement screens.
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const navyGradientEnd = Color(0xFF1E3A8A);
  static const blue = Color(0xFF2563EB);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const subtle = Color(0xFFF1F5F9);
  static const page = Color(0xFFF8FAFC);
  static const chipBg = Color(0xFFEFF6FF);
  static const chipBorder = Color(0xFFBFDBFE);
  static const blueText = Color(0xFF1E40AF);
  static const body = Color(0xFF334155);
  static const green = Color(0xFF16A34A);
  static const gold = Color(0xFFB45309);
  static const sky = Color(0xFF0EA5E9);
  static const red = Color(0xFFDC2626);
  static const whatsapp = Color(0xFF25D366);
}

const _heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_Palette.navy, _Palette.navyGradientEnd],
);

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

    return Scaffold(
      backgroundColor: _Palette.page,
      body: GetBuilder<AppController>(
        builder: (_) {
          final allArticles = controller.publishedArticles;
          final categories = controller.visibleForumCategories;
          final tags = controller.visibleForumTopicTags;

          // Filter articles by selected tag.
          final articles = _selectedTag == null
              ? allArticles.take(10).toList()
              : allArticles
                  .where((a) => a.tags.contains(_selectedTag))
                  .toList();

          return KpbRefresh(
            onRefresh: controller.pullToRefresh,
            child: CustomScrollView(
              slivers: [
                // ── App bar ──────────────────────────────────────────────
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: _Palette.page,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    tooltip: 'a11y_back'.tr,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: _Palette.navy),
                    onPressed: () => Navigator.canPop(context)
                        ? Navigator.pop(context)
                        : null,
                  ),
                  title: Text(
                    'nav_community'.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: _Palette.navy,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search_rounded,
                          color: _Palette.navy),
                      onPressed: () => Get.to(() => const SearchScreen()),
                      tooltip: 'community_search_tooltip'.tr,
                    ),
                  ],
                ),

                // ── Hero header ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(gradient: _heroGradient),
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'community_hero_title'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'community_intro'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Community hub: mentors · salons · parcours (KPB-70) ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HubTile(
                            icon: Icons.school_rounded,
                            label: 'community_hub_alumni'.tr,
                            color: _Palette.green,
                            onTap: () =>
                                Get.to(() => const AlumniDirectoryScreen()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HubTile(
                            icon: Icons.event_rounded,
                            label: 'community_hub_salon'.tr,
                            color: _Palette.blue,
                            onTap: () => Get.to(() => const SalonScreen()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HubTile(
                            icon: Icons.route_rounded,
                            label: 'community_hub_parcours'.tr,
                            color: _Palette.gold,
                            onTap: () => Get.to(() => const ParcoursScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Hashtag filter chips ─────────────────────────────────
                if (tags.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _TagChip(
                              label: 'leads_filter_all'.tr,
                              selected: _selectedTag == null,
                              onTap: () => setState(() => _selectedTag = null),
                            ),
                            const SizedBox(width: 8),
                            ...tags.map((tag) {
                              final label = controller.resolve(tag.label);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _TagChip(
                                  label: '#$label',
                                  selected: _selectedTag == label,
                                  onTap: () => setState(() => _selectedTag =
                                      _selectedTag == label ? null : label),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Articles section heading ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          'community_articles_section'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: _Palette.navy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _Palette.chipBg,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '${articles.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _Palette.blue,
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
                          horizontal: 16, vertical: 24),
                      child: KpbEmptyState(
                        icon: Icons.article_outlined,
                        title: 'community_empty_articles_title'.tr,
                        subtitle: _selectedTag != null
                            ? 'community_empty_articles_for_tag'
                                .trParams({'tag': '$_selectedTag'})
                            : 'community_articles_coming_soon'.tr,
                        actionLabel: _selectedTag != null
                            ? 'community_see_all_articles'.tr
                            : null,
                        onAction: _selectedTag != null
                            ? () => setState(() => _selectedTag = null)
                            : null,
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _FeaturedArticle(
                        article: articles.first,
                        controller: controller,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  if (articles.length > 1)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: articles.length - 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _ArticleCard(
                          article: articles[i + 1],
                          controller: controller,
                        ),
                      ),
                    ),
                ],

                // ── Forum categories (real articles-by-topic) ────────────
                if (categories.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                      child: Text(
                        'community_forum_section'.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: _Palette.navy,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final cat = categories[i];
                        final colors = _categoryColors(i);
                        return _ForumCategoryCard(
                          title: controller.resolve(cat.label),
                          description: controller.resolve(cat.description),
                          accent: colors.fg,
                          accentBg: colors.bg,
                          icon: colors.icon,
                          onTap: () => Get.to(
                            () => ForumCategoryScreen(
                              category: cat,
                              accentColor: colors.fg,
                              accentBg: colors.bg,
                              icon: colors.icon,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ── Static safety note (advice, not fabricated data) ─────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: _SafetyNote(),
                  ),
                ),

                // ── WhatsApp group CTA ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: _WhatsAppCta(onTap: _launchWhatsApp),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          );
        },
      ),
    );
  }

  ({Color bg, Color fg, IconData icon}) _categoryColors(int i) {
    const list = [
      (bg: Color(0xFFEEF2FF), fg: _Palette.blue, icon: Icons.school_outlined),
      (
        bg: Color(0xFFF0FDF4),
        fg: _Palette.green,
        icon: Icons.workspace_premium_outlined
      ),
      (bg: Color(0xFFFFFBEB), fg: _Palette.gold, icon: Icons.home_outlined),
      (bg: Color(0xFFEFF6FF), fg: _Palette.sky, icon: Icons.language_outlined),
      (bg: Color(0xFFFFF1F2), fg: _Palette.red, icon: Icons.forum_outlined),
    ];
    return list[i % list.length];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Launch the real WhatsApp group.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _launchWhatsApp() async {
  await openWhatsAppOrToast(
    group: true,
    source: 'community',
    contextType: 'community_group',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hashtag filter chip.
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _Palette.blue : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? _Palette.blue : _Palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : _Palette.slate,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured article card (large).
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturedArticle extends StatelessWidget {
  const _FeaturedArticle({required this.article, required this.controller});

  final ArticleModel article;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openArticleSheet(context, article, controller),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 128,
              decoration: const BoxDecoration(gradient: _heroGradient),
              child: Center(
                child: Icon(Icons.article_rounded,
                    color: Colors.white.withValues(alpha: 0.3), size: 60),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pill(
                    label: 'community_featured_badge'.tr,
                    bg: _Palette.chipBg,
                    fg: _Palette.blue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.resolve(article.title),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.25,
                      color: _Palette.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.resolve(article.summary),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: _Palette.body,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article.tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: article.tags
                          .take(3)
                          .map((tag) => _Pill(
                                label: '#$tag',
                                bg: _Palette.subtle,
                                fg: _Palette.slate,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Regular article card.
// ─────────────────────────────────────────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.controller});

  final ArticleModel article;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openArticleSheet(context, article, controller),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _Palette.subtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.article_outlined,
                  color: _Palette.slate400, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.resolve(article.title),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: _Palette.navy,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    controller.resolve(article.summary),
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: _Palette.slate,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _Pill(
                      label: '#${article.tags.first}',
                      bg: _Palette.subtle,
                      fg: _Palette.slate,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: _Palette.slate400, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Forum category card → opens ForumCategoryScreen (real articles-by-topic).
// ─────────────────────────────────────────────────────────────────────────────
class _ForumCategoryCard extends StatelessWidget {
  const _ForumCategoryCard({
    required this.title,
    required this.description,
    required this.accent,
    required this.accentBg,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final Color accent;
  final Color accentBg;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _Palette.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: _Palette.slate,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: _Palette.slate400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Static safety note (design's blue "shield" tip — advice, not fake data).
// ─────────────────────────────────────────────────────────────────────────────
class _SafetyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _Palette.chipBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.chipBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, size: 16, color: _Palette.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'community_safety_note'.tr,
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: _Palette.blueText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WhatsApp group CTA (real group link).
// ─────────────────────────────────────────────────────────────────────────────
class _WhatsAppCta extends StatelessWidget {
  const _WhatsAppCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: _heroGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _Palette.navy.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'community_join_whatsapp_group'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'community_members'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: _Palette.whatsapp,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'salon_join'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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

// ─────────────────────────────────────────────────────────────────────────────
// Community hub tile — compact tappable entry to a community surface.
// ─────────────────────────────────────────────────────────────────────────────
class _HubTile extends StatelessWidget {
  const _HubTile({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Palette.border),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _Palette.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small pill/badge.
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Article detail bottom sheet (real article content).
// ─────────────────────────────────────────────────────────────────────────────
void _openArticleSheet(
  BuildContext context,
  ArticleModel article,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 156,
              decoration: const BoxDecoration(gradient: _heroGradient),
              child: Center(
                child: Icon(Icons.article_rounded,
                    color: Colors.white.withValues(alpha: 0.3), size: 68),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: article.tags
                          .take(3)
                          .map((tag) => _Pill(
                                label: '#$tag',
                                bg: _Palette.subtle,
                                fg: _Palette.slate,
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    controller.resolve(article.title),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.2,
                      color: _Palette.navy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _articleBody(controller, article),
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      color: _Palette.body,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (article.publishedAt != null)
                    Text(
                      '${'published_on'.tr} '
                      '${_formatDate(article.publishedAt!)}',
                      style: const TextStyle(
                          fontSize: 12.5, color: _Palette.slate400),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Real article body, falling back to the summary when the long-form content
/// is empty (never a non-existent field).
String _articleBody(AppController controller, ArticleModel article) {
  final content = controller.resolve(article.content);
  return content.trim().isNotEmpty
      ? content
      : controller.resolve(article.summary);
}

String _formatDate(DateTime dt) {
  final ctrl = Get.find<AppController>();
  return DateFormat('d MMM yyyy', ctrl.localeCode).format(dt);
}
