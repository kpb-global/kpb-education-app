import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/components/source_link.dart';
import '../../core/ui/components/verified_badge.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/study_level.dart';
import '../../core/utils/tuition_utils.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../cases/case_tunnel_flow.dart';

class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final String programId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final program = controller.programByIdOrNull(programId);
    if (program == null) {
      return Scaffold(
        body: Center(child: Text('program_not_found'.tr)),
      );
    }

    final institution = controller.institutionByIdOrNull(program.institutionId);
    final country = controller.countryByIdOrNull(program.countryId);
    FieldModel? field;
    try {
      field = controller.fieldById(program.fieldId);
    } catch (_) {}

    final isPartner = institution?.isPartner ?? false;
    const applicationSteps = [
      'Quiz d\'éligibilité & choix du programme',
      'Constitution du dossier avec KPB',
      'Soumission à l\'école partenaire',
      'Obtention de la lettre d\'admission',
      'Visa & préparation du départ',
    ];

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: KpbColors.navy,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: KpbColors.heroGradient),
                padding: const EdgeInsets.fromLTRB(20, 88, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPartner)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: KpbBadge(
                          label: 'Partenaire KPB',
                          color: KpbColors.gold,
                          small: true,
                        ),
                      ),
                    Text(
                      controller.resolve(program.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (institution != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        controller.resolve(institution.name),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  controller.isSaved(SavedItemType.program, program.id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: Colors.white,
                ),
                onPressed: () =>
                    controller.toggleSaved(SavedItemType.program, program.id),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(KpbSpacing.pagePad),
              child: Column(
                children: [
                  _Section(
                    icon: Icons.info_outline_rounded,
                    title: 'Le programme en bref',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: VerifiedBadge(
                            lastVerifiedAt: program.lastVerifiedAt,
                          ),
                        ),
                        const SizedBox(height: 12),
                        KpbInfoRow(
                          icon: Icons.school_outlined,
                          label: 'Niveau',
                          value: programLevelLabel(
                              controller.resolve(program.level)),
                          iconColor: KpbColors.blue,
                        ),
                        const KpbDivider(indent: 48),
                        KpbInfoRow(
                          icon: Icons.schedule_outlined,
                          label: 'Durée',
                          value: controller.resolve(program.duration),
                          iconColor: KpbColors.success,
                        ),
                        const KpbDivider(indent: 48),
                        KpbInfoRow(
                          icon: Icons.language_outlined,
                          label: 'Langue',
                          value: controller.resolve(program.language),
                          iconColor: KpbColors.warning,
                        ),
                        if (country != null) ...[
                          const KpbDivider(indent: 48),
                          KpbInfoRow(
                            icon: Icons.public_outlined,
                            label: 'Pays',
                            value:
                                '${displayCountryFlag(id: country.id, flagEmoji: country.flagEmoji)} ${controller.resolve(country.name)}',
                            iconColor: KpbColors.blue,
                          ),
                        ],
                        if (institution != null &&
                            program.campusOfferings.isEmpty) ...[
                          const KpbDivider(indent: 48),
                          KpbInfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Campus',
                            value: controller.resolve(institution.location),
                            iconColor: KpbColors.blue,
                          ),
                        ],
                        if (country != null &&
                            country.nextIntakeLabel.fr.isNotEmpty) ...[
                          const KpbDivider(indent: 48),
                          KpbInfoRow(
                            icon: Icons.calendar_month_outlined,
                            label: 'Rentrée',
                            value: controller.resolve(country.nextIntakeLabel),
                            iconColor: KpbColors.gold,
                          ),
                        ],
                        if (field != null) ...[
                          const KpbDivider(indent: 48),
                          KpbInfoRow(
                            icon: Icons.category_outlined,
                            label: 'Domaine',
                            value: controller.resolve(field.name),
                            iconColor: field.accentColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _Section(
                    icon: Icons.payments_outlined,
                    title: 'Frais de scolarité',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.resolve(program.tuition),
                          style: KpbTextStyles.titleMd.copyWith(
                            color: KpbColors.gold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          TuitionUtils.fcfaSuffixFromTuition(
                            controller.resolve(program.tuition),
                          ),
                          style: KpbTextStyles.caption,
                        ),
                        if (institution != null &&
                            program.campusOfferings.isEmpty &&
                            institution.tuitionLabel.fr.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            institution.tuitionLabel.resolve(
                              controller.localeCode,
                            ),
                            style: KpbTextStyles.bodySm,
                          ),
                        ],
                        const SizedBox(height: 8),
                        KpbSourceLink(url: program.sourceUrl),
                      ],
                    ),
                  ),
                  if (program.campusOfferings.isNotEmpty)
                    _Section(
                      icon: Icons.location_city_outlined,
                      title:
                          'Disponible sur ${program.campusOfferings.length} campus',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0;
                              i < program.campusOfferings.length;
                              i++) ...[
                            if (i > 0) const KpbDivider(indent: 48),
                            _CampusOfferingRow(
                              offering: program.campusOfferings[i],
                              localeCode: controller.localeCode,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (program.requirements.isNotEmpty)
                    _Section(
                      icon: Icons.fact_check_outlined,
                      title: 'Conditions d\'admission',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: program.requirements
                            .map(
                              (req) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        size: 18, color: KpbColors.success),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        controller.resolve(req),
                                        style: KpbTextStyles.bodySm,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  _Section(
                    icon: Icons.route_outlined,
                    title: 'Processus de candidature',
                    child: Column(
                      children: [
                        for (var i = 0; i < applicationSteps.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: KpbColors.blue,
                                  borderRadius: KpbRadius.smBr,
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  applicationSteps[i],
                                  style: KpbTextStyles.bodySm,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        program: program,
        institution: institution,
        country: country,
        controller: controller,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KpbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: KpbColors.blue, size: 20),
                const SizedBox(width: 8),
                Text(title, style: KpbTextStyles.titleMd),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _CampusOfferingRow extends StatelessWidget {
  const _CampusOfferingRow({
    required this.offering,
    required this.localeCode,
  });

  final CampusOffering offering;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final intake = offering.intake;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined,
              size: 18, color: KpbColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offering.campus,
                  style: KpbTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (intake != null && intake.isNotEmpty)
                  Text('Rentrée $intake', style: KpbTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            offering.tuitionLabel(localeCode),
            style: KpbTextStyles.bodySm.copyWith(
              color: KpbColors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.program,
    required this.institution,
    required this.country,
    required this.controller,
  });

  final ProgramModel program;
  final InstitutionModel? institution;
  final CountryModel? country;
  final AppController controller;

  void _openCaseTunnel(BuildContext context) {
    final prefill = CaseTunnelPrefill(
      title: controller.resolve(program.name),
      contextLabel: institution != null
          ? controller.resolve(institution!.name)
          : controller.resolve(program.name),
      initialType: CaseType.applicationSupport,
      countryId: program.countryId,
      institutionId: program.institutionId,
      programId: program.id,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.96,
        builder: (_, __) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: CaseTunnelFlow(
            prefill: prefill,
            onClose: () => Navigator.pop(ctx),
            onSubmitted: () {
              Navigator.pop(ctx);
              Get.snackbar(
                'KPB Education',
                'request_submitted'.tr,
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final whatsAppPrefill = kpbWhatsAppPrefill(
      custom: country?.whatsAppPrefill.fr.isNotEmpty == true
          ? controller.resolve(country!.whatsAppPrefill)
          : null,
      program: controller.resolve(program.name),
      country: country != null ? controller.resolve(country!.name) : null,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        12,
        KpbSpacing.pagePad,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        border: Border(top: BorderSide(color: context.kpb.gray100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => openWhatsAppOrToast(prefill: whatsAppPrefill),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('WhatsApp'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () => _openCaseTunnel(context),
              child: Text('enroll_with_kpb'.tr),
            ),
          ),
        ],
      ),
    );
  }
}