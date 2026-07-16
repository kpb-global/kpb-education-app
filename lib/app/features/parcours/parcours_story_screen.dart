// Written-testimonial reader (kind == text) for the Parcours section.
//
// Renders a legacy Q&A interview imported from the first KPB app: a gradient
// header with the person's monogram + role, an optional summary, then the
// question/answer pairs. Localized (FR-first, EN when available).

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';

// Palette (App-engagement handoff) — mirrors parcours_screen.dart's local
// palette, replacing the legacy KpbColors #004AAD accents.
class _P {
  static const navy = Color(0xFF0F172A);
  static const heroEnd = Color(0xFF1E3A8A);
  static const blue = Color(0xFF2563EB);

  static const heroGradient = LinearGradient(
    colors: [navy, heroEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ParcoursStoryScreen extends StatelessWidget {
  const ParcoursStoryScreen({super.key, required this.story});

  final ParcoursStory story;

  @override
  Widget build(BuildContext context) {
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
        gradient: _P.heroGradient,
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
              style: KpbTextStyles.titleMd.copyWith(color: _P.blue),
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
