import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../cases/case_composer_sheet.dart';
import '../explore/program_detail_screen.dart';

/// M7 — Admission France écoles privées (rentrée septembre 2026).
class FrancePrivateAdmissionScreen extends StatelessWidget {
  const FrancePrivateAdmissionScreen({super.key});

  static const _processSteps = [
    'Choix de l\'école privée partenaire (OMNES, ICN, Schiller, IGENSIA…)',
    'Constitution du dossier d\'admission avec KPB',
    'Entretien / validation admission école',
    'Visa long séjour étudiant',
    'Logement & préparation du départ',
    'Arrivée en France avec suivi KPB',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final partners = controller.institutions
        .where(
          (i) =>
              (i.countryId == 'fra' || i.countryId == 'france') && i.isPartner,
        )
        .toList();
    final francePrograms = controller.programs
        .where((p) => p.countryId == 'fra' || p.countryId == 'france')
        .length;

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: KpbColors.navy,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: KpbColors.heroGradient),
                padding: const EdgeInsets.fromLTRB(24, 96, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      displayCountryFlag(id: 'fra'),
                      style: const TextStyle(fontSize: 44),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Admission France — Écoles privées',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rentrée septembre 2026 · $francePrograms programmes disponibles',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(KpbSpacing.pagePad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.kpb.gray100,
                      borderRadius: KpbRadius.mdBr,
                      border: Border.all(color: context.kpb.gray200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: context.kpb.textSecondary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Universités publiques — Bientôt disponible · Septembre 2026',
                            style: KpbTextStyles.bodySm,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  KpbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pourquoi le privé au lancement ?',
                          style: KpbTextStyles.titleMd,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Les écoles privées françaises partenaires KPB offrent un parcours d\'admission direct, avec des rentrées flexibles et un accompagnement personnalisé pour les étudiants africains.',
                          style: KpbTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  KpbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.route_outlined,
                                color: KpbColors.blue, size: 20),
                            SizedBox(width: 8),
                            Text('Ton parcours en 6 étapes',
                                style: KpbTextStyles.titleMd),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < _processSteps.length; i++) ...[
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
                                  _processSteps[i],
                                  style: KpbTextStyles.bodySm,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Écoles partenaires France',
                      style: KpbTextStyles.titleMd),
                  const SizedBox(height: 10),
                  if (partners.isEmpty)
                    const KpbCard(
                      child: Text(
                        'Synchronise le catalogue pour voir les écoles OMNES et partenaires.',
                        style: KpbTextStyles.bodySm,
                      ),
                    )
                  else
                    ...partners.map(
                      (inst) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: KpbCard(
                          onTap: () {
                            final program =
                                controller.programs.firstWhereOrNull(
                              (p) => p.institutionId == inst.id,
                            );
                            if (program != null) {
                              Get.to(
                                () => ProgramDetailScreen(
                                  programId: program.id,
                                ),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: context.kpb.skyLight,
                                  borderRadius: KpbRadius.mdBr,
                                ),
                                child: const Icon(
                                  Icons.account_balance_outlined,
                                  color: KpbColors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.resolve(inst.name),
                                      style: KpbTextStyles.titleMd,
                                    ),
                                    Text(
                                      controller.resolve(inst.location),
                                      style: KpbTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              const KpbBadge(
                                label: 'Partenaire',
                                color: KpbColors.success,
                                small: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
        child: FilledButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => CaseComposerSheet(
              caseType: CaseType.applicationSupport,
              title: 'Procédure France — écoles privées',
              contextLabel: 'France · Septembre 2026',
              countryId: 'fra',
            ),
          ),
          child: const Text('Je commence ma procédure'),
        ),
      ),
    );
  }
}
