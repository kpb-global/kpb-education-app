import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/utils/whatsapp_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Forum Category — App-engagement handoff restyle (navy/blue).
//
// HONEST-DATA NOTE: the design mock for a group shows a member post feed with
// replies, report buttons and moderation-masked messages. None of that is
// backed, so it is NOT built. This screen shows what is REAL: the category's
// related published articles + topic-tag filter, and an honest "the in-app
// forum is launching soon → talk on WhatsApp now" call to action.
// ─────────────────────────────────────────────────────────────────────────────

// Local palette — same per-file pattern as the other App-engagement screens.
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const navyGradientEnd = Color(0xFF1E3A8A);
  static const blue = Color(0xFF2563EB);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const page = Color(0xFFF8FAFC);
  static const chipBg = Color(0xFFEFF6FF);
  static const chipBorder = Color(0xFFBFDBFE);
  static const blueText = Color(0xFF1E40AF);
  static const body = Color(0xFF334155);
  static const whatsapp = Color(0xFF25D366);
}

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

    return Scaffold(
      backgroundColor: _Palette.page,
      body: GetBuilder<AppController>(
        builder: (_) {
          final tags = controller.visibleForumTopicTags;
          final articles = _relatedArticles(controller);

          return CustomScrollView(
            slivers: [
              // ── Navy hero app bar ────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 184,
                backgroundColor: _Palette.navy,
                surfaceTintColor: Colors.transparent,
                foregroundColor: Colors.white,
                leading: IconButton(
                  tooltip: 'a11y_back'.tr,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
                  title: Text(
                    controller.resolve(widget.category.label),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_Palette.navy, _Palette.navyGradientEnd],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Icon(
                          widget.icon,
                          size: 92,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Description + join CTA ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.resolve(widget.category.description),
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: _Palette.body,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _JoinCtaCard(onWhatsApp: _launchWhatsApp),
                    ],
                  ),
                ),
              ),

              // ── Topic-tag filter ─────────────────────────────────────
              if (tags.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      Get.locale?.languageCode == 'en'
                          ? 'Filter by topic'
                          : 'Filtrer par sujet',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _Palette.navy,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: tags.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return _TagChip(
                            label: Get.locale?.languageCode == 'en'
                                ? 'All'
                                : 'Tous',
                            selected: _selectedTag == null,
                            onTap: () => setState(() => _selectedTag = null),
                          );
                        }
                        final tag = tags[i - 1];
                        return _TagChip(
                          label: controller.resolve(tag.label),
                          selected: _selectedTag == tag.id,
                          onTap: () => setState(() => _selectedTag = tag.id),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
              ],

              // ── Related articles ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    Get.locale?.languageCode == 'en'
                        ? 'Related articles'
                        : 'Articles liés',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _Palette.navy,
                    ),
                  ),
                ),
              ),
              if (articles.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _Palette.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.article_outlined,
                              size: 44, color: _Palette.slate400),
                          const SizedBox(height: 12),
                          Text(
                            Get.locale?.languageCode == 'en'
                                ? 'No articles tagged yet. Join the WhatsApp group to ask questions.'
                                : 'forum_no_articles_tagged'.tr,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: _Palette.slate,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _ArticleRow(
                      article: articles[i],
                      controller: controller,
                      accent: widget.accentColor,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  List<ArticleModel> _relatedArticles(AppController controller) {
    final all = controller.publishedArticles;
    final tags = controller.visibleForumTopicTags.map((t) => t.id).toSet();
    // Prefer articles matching the selected tag; else match category-level tags.
    return all
        .where((a) {
          if (_selectedTag != null) return a.tags.contains(_selectedTag);
          if (a.category == widget.category.id) return true;
          return a.tags.any(tags.contains);
        })
        .take(10)
        .toList();
  }
}

Future<void> _launchWhatsApp() async {
  await openWhatsAppOrToast(
    group: true,
    source: 'forum_category',
    contextType: 'community_group',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Honest "forum launching soon → WhatsApp now" call to action.
// ─────────────────────────────────────────────────────────────────────────────
class _JoinCtaCard extends StatelessWidget {
  const _JoinCtaCard({required this.onWhatsApp});
  final Future<void> Function() onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.chipBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.chipBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _Palette.blue.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.forum_rounded, color: _Palette.blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Get.locale?.languageCode == 'en'
                          ? 'Join the conversation'
                          : 'Rejoins la conversation',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _Palette.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Get.locale?.languageCode == 'en'
                          ? 'The in-app forum is launching soon. Connect on WhatsApp to discuss with other students and KPB counselors now.'
                          : "Le forum in-app arrive bientôt. Rejoins WhatsApp pour discuter avec d'autres étudiants et les conseillers KPB dès maintenant.",
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: _Palette.blueText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onWhatsApp,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _Palette.whatsapp,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_rounded, size: 17, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    Get.locale?.languageCode == 'en'
                        ? 'Open WhatsApp group'
                        : 'Ouvrir le groupe WhatsApp',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic-tag filter chip.
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
        alignment: Alignment.center,
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
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : _Palette.slate,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Related-article row (real article; display only, matching prior behavior).
// ─────────────────────────────────────────────────────────────────────────────
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.article_rounded, color: accent, size: 22),
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
                const SizedBox(height: 4),
                Text(
                  controller.resolve(article.summary),
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
        ],
      ),
    );
  }
}
