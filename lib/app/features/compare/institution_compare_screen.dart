import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';

const _flags = <String, String>{
  'usa': '🇺🇸',
  'canada': '🇨🇦',
  'france': '🇫🇷',
  'uk': '🇬🇧',
  'morocco': '🇲🇦',
  'turkey': '🇹🇷',
  'germany': '🇩🇪',
  'spain': '🇪🇸',
  'china': '🇨🇳',
  'belgium': '🇧🇪',
  'italy': '🇮🇹',
  'portugal': '🇵🇹',
};

String _flag(String id) => _flags[id] ?? '🌍';

class InstitutionCompareScreen extends StatelessWidget {
  const InstitutionCompareScreen({
    super.key,
    required this.institutionId1,
    required this.institutionId2,
  });

  final String institutionId1;
  final String institutionId2;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final inst1 = controller.institutionById(institutionId1);
    final inst2 = controller.institutionById(institutionId2);
    final score1 = controller.institutionMatch(inst1);
    final score2 = controller.institutionMatch(inst2);

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        backgroundColor: context.kpb.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.kpb.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Comparaison',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.kpb.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: context.kpb.textSecondary),
            onPressed: () => _shareComparison(controller, inst1, inst2),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        child: Column(
          children: [
            // ── Institution headers ─────────────────────────────────────
            Row(
              children: [
                _InstitutionHeader(
                  institution: inst1,
                  score: score1,
                  controller: controller,
                ),
                const SizedBox(width: 10),
                _InstitutionHeader(
                  institution: inst2,
                  score: score2,
                  controller: controller,
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.md),

            // ── Comparison table ────────────────────────────────────────
            KpbCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _CompareRow(
                    label: 'Compatibilité',
                    icon: Icons.auto_awesome_rounded,
                    iconColor: KpbColors.gold,
                    value1: _ScoreWidget(score: score1),
                    value2: _ScoreWidget(score: score2),
                  ),
                  const _RowDivider(),
                  _CompareRow(
                    label: 'Pays',
                    icon: Icons.public_rounded,
                    iconColor: KpbColors.sky,
                    value1: _TextCell(
                      '${_flag(inst1.countryId)} ${_resolveCountry(controller, inst1.countryId)}',
                    ),
                    value2: _TextCell(
                      '${_flag(inst2.countryId)} ${_resolveCountry(controller, inst2.countryId)}',
                    ),
                  ),
                  const _RowDivider(),
                  _CompareRow(
                    label: 'Localisation',
                    icon: Icons.location_on_outlined,
                    iconColor: KpbColors.error,
                    value1: _TextCell(controller.resolve(inst1.location)),
                    value2: _TextCell(controller.resolve(inst2.location)),
                  ),
                  const _RowDivider(),
                  _CompareRow(
                    label: 'Frais',
                    icon: Icons.euro_rounded,
                    iconColor: KpbColors.financeGreen,
                    value1: _TextCell(controller.resolve(inst1.tuitionLabel)),
                    value2: _TextCell(controller.resolve(inst2.tuitionLabel)),
                  ),
                  const _RowDivider(),
                  _CompareRow(
                    label: 'Langue',
                    icon: Icons.translate_rounded,
                    iconColor: KpbColors.lawPurple,
                    value1: _TextCell(
                        controller.resolve(inst1.languageRequirements)),
                    value2: _TextCell(
                        controller.resolve(inst2.languageRequirements)),
                  ),
                  const _RowDivider(),
                  _CompareRow(
                    label: 'Niveaux',
                    icon: Icons.school_outlined,
                    iconColor: KpbColors.blue,
                    value1: _TagsCell(inst1.studyLevels),
                    value2: _TagsCell(inst2.studyLevels),
                  ),
                  const _RowDivider(),
                  _CompareRow(
                    label: 'Inscriptions',
                    icon: Icons.calendar_month_outlined,
                    iconColor: KpbColors.businessSky,
                    value1: _TagsCell(inst1.intakePeriods),
                    value2: _TagsCell(inst2.intakePeriods),
                  ),
                  const _RowDivider(),
                  _CompareRow(
                    label: 'Programmes',
                    icon: Icons.menu_book_outlined,
                    iconColor: KpbColors.designOrange,
                    value1: _TextCell('${inst1.programIds.length} programmes'),
                    value2: _TextCell('${inst2.programIds.length} programmes'),
                  ),
                  const _RowDivider(),
                  _CompareRow(
                    label: 'Partenaire KPB',
                    icon: Icons.verified_outlined,
                    iconColor: KpbColors.gold,
                    value1: _BoolCell(value: inst1.isPartner),
                    value2: _BoolCell(value: inst2.isPartner),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KpbSpacing.lg),

            // ── CTA ─────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => CaseComposerSheet(
                        caseType: CaseType.applicationSupport,
                        title: controller.resolve(inst1.name),
                        contextLabel: controller.resolve(inst1.location),
                      ),
                    ),
                    child: Text(
                      controller.resolve(inst1.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => CaseComposerSheet(
                        caseType: CaseType.applicationSupport,
                        title: controller.resolve(inst2.name),
                        contextLabel: controller.resolve(inst2.location),
                      ),
                    ),
                    child: Text(
                      controller.resolve(inst2.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            FilledButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => CaseComposerSheet(
                  caseType: CaseType.consultation,
                  title: 'Aide au choix d\'université',
                  contextLabel:
                      '${controller.resolve(inst1.name)} vs ${controller.resolve(inst2.name)}',
                ),
              ),
              child: const Text('Aide au choix'),
            ),
            const SizedBox(height: KpbSpacing.xl),
          ],
        ),
      ),
    );
  }

  String _resolveCountry(AppController ctrl, String countryId) {
    try {
      return ctrl.resolve(ctrl.countryById(countryId).name);
    } catch (_) {
      return countryId;
    }
  }

  void _shareComparison(
    AppController ctrl,
    InstitutionModel inst1,
    InstitutionModel inst2,
  ) {
    final name1 = ctrl.resolve(inst1.name);
    final name2 = ctrl.resolve(inst2.name);
    final score1 = ctrl.institutionMatch(inst1);
    final score2 = ctrl.institutionMatch(inst2);
    SharePlus.instance.share(ShareParams(
      text: 'Comparaison d\'universités avec KPB Education :\n\n'
          '🏛 $name1 — compatibilité $score1%\n'
          '   Frais : ${ctrl.resolve(inst1.tuitionLabel)}\n'
          '   Langue : ${ctrl.resolve(inst1.languageRequirements)}\n\n'
          '🏛 $name2 — compatibilité $score2%\n'
          '   Frais : ${ctrl.resolve(inst2.tuitionLabel)}\n'
          '   Langue : ${ctrl.resolve(inst2.languageRequirements)}\n\n'
          'Découvrez KPB Education pour votre orientation universitaire.',
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Institution header card
// ─────────────────────────────────────────────────────────────────────────────
class _InstitutionHeader extends StatelessWidget {
  const _InstitutionHeader({
    required this.institution,
    required this.score,
    required this.controller,
  });

  final InstitutionModel institution;
  final int score;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(KpbSpacing.md),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [KpbColors.navy, KpbColors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: KpbRadius.lgBr,
          boxShadow: KpbShadow.blue,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: KpbRadius.mdBr,
              ),
              child: Center(
                child: Text(
                  _flag(institution.countryId),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              controller.resolve(institution.name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            Text(
              controller.resolve(institution.location),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (institution.isPartner) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: KpbColors.gold.withValues(alpha: 0.25),
                  borderRadius: KpbRadius.pillBr,
                ),
                child: const Text(
                  'Partenaire',
                  style: TextStyle(
                    color: KpbColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comparison row layout
// ─────────────────────────────────────────────────────────────────────────────
class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value1,
    required this.value2,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Widget value1;
  final Widget value2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: KpbSpacing.md, vertical: KpbSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: KpbTextStyles.label.copyWith(
                  color: context.kpb.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: value1),
              const SizedBox(width: 10),
              Expanded(child: value2),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 1, color: context.kpb.gray100, indent: 16, endIndent: 16);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cell widgets
// ─────────────────────────────────────────────────────────────────────────────
class _TextCell extends StatelessWidget {
  const _TextCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.kpb.textPrimary,
        height: 1.4,
      ),
    );
  }
}

class _TagsCell extends StatelessWidget {
  const _TagsCell(this.tags);
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Text('—',
          style: TextStyle(color: context.kpb.textMuted, fontSize: 13));
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: context.kpb.surfaceBg,
                borderRadius: KpbRadius.pillBr,
              ),
              child: Text(
                t,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.kpb.textSecondary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BoolCell extends StatelessWidget {
  const _BoolCell({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          value ? Icons.check_circle_rounded : Icons.cancel_outlined,
          size: 16,
          color: value ? KpbColors.success : context.kpb.gray300,
        ),
        const SizedBox(width: 5),
        Text(
          value ? 'Oui' : 'Non',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: value ? KpbColors.success : context.kpb.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ScoreWidget extends StatelessWidget {
  const _ScoreWidget({required this.score});
  final int score;

  Color _color(BuildContext context) {
    if (score >= 85) return KpbColors.success;
    if (score >= 70) return KpbColors.blue;
    if (score >= 50) return KpbColors.gold;
    return context.kpb.gray400;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: KpbRadius.pillBr,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
