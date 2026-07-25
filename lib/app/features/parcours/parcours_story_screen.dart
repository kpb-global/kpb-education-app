// Written-testimonial reader (kind == text) for the Parcours section.
//
// Renders a legacy Q&A interview imported from the first KPB app: a gradient
// header with the person's monogram + role, an optional summary, then the
// question/answer pairs. Localized (FR-first, EN when available).

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';

// Couleurs : tokens sémantiques centraux (KpbColors — architecture §10.2).
class ParcoursStoryScreen extends StatefulWidget {
  const ParcoursStoryScreen({
    super.key,
    required this.story,
    this.analyticsSource = 'library',
  });

  final ParcoursStory story;

  /// Surface this reader was opened from ('library', 'feed', 'story_of_week'),
  /// so completion can be read per surface rather than as one blended number.
  final String analyticsSource;

  @override
  State<ParcoursStoryScreen> createState() => _ParcoursStoryScreenState();
}

class _ParcoursStoryScreenState extends State<ParcoursStoryScreen> {
  final _scrollController = ScrollController();
  bool _completeLogged = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logParcoursView(
      slug: widget.story.slug,
      kind: 'text',
      source: widget.analyticsSource,
    );
    _scrollController.addListener(_onScroll);
    // A short interview can fit on one screen — there is no scroll to reach the
    // end, and it is read all the same. Settle the first frame, then check.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// "Read" = the last answer is on screen. Measured, never assumed from a
  /// simple open.
  void _onScroll() {
    if (_completeLogged || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atEnd = position.pixels >= position.maxScrollExtent - 24;
    if (!atEnd) return;
    _completeLogged = true;
    AnalyticsService.instance.logParcoursComplete(
      slug: widget.story.slug,
      kind: 'text',
      source: widget.analyticsSource,
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final localeCode = Get.find<AppController>().localeCode;
    final role = story.role.resolve(localeCode);
    final summary = story.summary.resolve(localeCode);
    final qa = story.interview(localeCode);

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text('parcours_story_appbar'.tr),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          KpbSpacing.md,
          KpbSpacing.pagePad,
          100,
        ),
        children: [
          _Header(name: story.personName, role: role),
          const SizedBox(height: KpbSpacing.lg),
          Text(
            story.title.resolve(localeCode),
            style:
                KpbTextStyles.headline.copyWith(color: context.kpb.textPrimary),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.sm),
            Text(
              summary,
              style:
                  KpbTextStyles.body.copyWith(color: context.kpb.textSecondary),
            ),
          ],
          if (story.tags.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in story.tags)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.kpb.gray100,
                      borderRadius: BorderRadius.circular(KpbRadius.pill),
                    ),
                    child: Text(tag,
                        style: KpbTextStyles.caption
                            .copyWith(color: context.kpb.textSecondary)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: KpbSpacing.lg),
          for (final pair in qa) ...[
            _QaBlock(question: pair.question, answer: pair.answer),
            const SizedBox(height: KpbSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        gradient: KpbColors.heroGradient,
        borderRadius: KpbRadius.lgBr,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: KpbSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    role,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '★';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _QaBlock extends StatelessWidget {
  const _QaBlock({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.isNotEmpty)
            Text(
              question,
              style: KpbTextStyles.titleMd
                  .copyWith(color: KpbColors.actionPrimary),
            ),
          if (question.isNotEmpty && answer.isNotEmpty)
            const SizedBox(height: KpbSpacing.sm),
          if (answer.isNotEmpty)
            Text(
              answer,
              style: KpbTextStyles.body
                  .copyWith(color: context.kpb.textPrimary, height: 1.5),
            ),
        ],
      ),
    );
  }
}
