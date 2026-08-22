import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/eef_calendar.dart';
import '../../core/ui/kpb_components.dart';

/// La coquille de l'espace « Études en France » réel.
///
/// ## Pourquoi elle est livrée vide
///
/// Pour que l'ouverture du jour J soit une variable d'environnement et non une
/// soumission App Store. `KPB_EEF_ENABLED=true` fait apparaître cet écran à la
/// place de la vitrine, sans binaire neuf : la route existe déjà, les entrées de
/// navigation la connaissent déjà, le décodeur d'accès est déjà là. Ce qui
/// manque — le catalogue, la shortlist, les outils — arrive par le réseau, pas
/// par le store.
///
/// ## Pourquoi elle ne prétend pas être plus que ça
///
/// Elle annonce honnêtement les modules en cours d'arrivée et renvoie vers ce
/// qui EXISTE déjà et sert le même besoin : le simulateur d'éligibilité, le
/// calendrier des échéances, et l'espace France écoles privées. Une coquille qui
/// afficherait des cartes vides ou des compteurs à zéro serait pire que la
/// vitrine qu'elle remplace — elle donnerait l'impression d'un produit cassé
/// plutôt que d'un produit en cours.
///
/// Le jour où le catalogue arrive, cet écran devient le vrai point d'entrée et
/// ce commentaire disparaît avec la liste ci-dessous.
class EefHomeScreen extends StatelessWidget {
  const EefHomeScreen({super.key});

  static const _comingModules =
      <({IconData icon, String titleKey, String bodyKey})>[
    (
      icon: Icons.school_outlined,
      titleKey: 'eef_pillar_catalog_title',
      bodyKey: 'eef_pillar_catalog_body',
    ),
    (
      icon: Icons.tune_rounded,
      titleKey: 'eef_pillar_shortlist_title',
      bodyKey: 'eef_pillar_shortlist_body',
    ),
    (
      icon: Icons.description_outlined,
      titleKey: 'eef_pillar_documents_title',
      bodyKey: 'eef_pillar_documents_body',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Le MÊME point unique que la vitrine et la carte d'accueil.
    //
    // Cet écran appelait `rangeLabel()` en direct, donc sans consulter la
    // suspension : le jour où `KPB_EEF_ENABLED` passe à true, un étudiant
    // nigérien y aurait relu la date d'ouverture nationale que la vitrine
    // refuse justement de lui donner. Le défaut était dormant en build 49
    // (drapeau éteint) et se serait réveillé exactement le jour du lancement de
    // l'espace réel — c'est-à-dire au pire moment.
    //
    // Troisième surface, troisième oubli possible : c'est pour ça que la règle
    // vit dans `EefCalendar.timingLabel` et nulle part ailleurs.
    final range = EefCalendar.timingLabel(
      country: Get.find<AppController>().profile?.countryOfResidence,
    );

    return Scaffold(
      appBar: AppBar(title: Text('eef_title'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          KpbSpacing.md,
          KpbSpacing.pagePad,
          KpbSpacing.xl,
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KpbSpacing.lg),
            decoration: const BoxDecoration(
              gradient: KpbColors.heroGradient,
              borderRadius: KpbRadius.lgBr,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'eef_hero_title'.tr,
                  style: KpbTextStyles.displayXs
                      .copyWith(color: KpbColors.textOnDark),
                ),
                if (range != null) ...[
                  const SizedBox(height: KpbSpacing.sm),
                  Text(
                    range,
                    style: KpbTextStyles.bodySm
                        .copyWith(color: KpbColors.actionOnDark),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.lg),
          SectionHeader(
            title: 'eef_modules_coming_heading'.tr,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: KpbSpacing.sm),
          for (final module in _comingModules) ...[
            KpbCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(module.icon, color: context.kpb.textMuted, size: 22),
                  const SizedBox(width: KpbSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(module.titleKey.tr, style: KpbTextStyles.titleSm),
                        const SizedBox(height: KpbSpacing.xs),
                        Text(
                          module.bodyKey.tr,
                          style: KpbTextStyles.bodySm
                              .copyWith(color: context.kpb.textMuted),
                        ),
                        const SizedBox(height: KpbSpacing.sm),
                        KpbBadge(
                          label: 'eef_status_preparing'.tr,
                          color: KpbColors.warning,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KpbSpacing.sm),
          ],
          const SizedBox(height: KpbSpacing.md),
          Container(
            padding: const EdgeInsets.all(KpbSpacing.md),
            decoration: BoxDecoration(
              color: KpbColors.surfaceMuted,
              borderRadius: KpbRadius.mdBr,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: context.kpb.textMuted,
                ),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Text(
                    'eef_affiliation_notice'.tr,
                    style: KpbTextStyles.caption
                        .copyWith(color: context.kpb.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
