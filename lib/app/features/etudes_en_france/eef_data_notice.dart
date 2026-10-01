import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/data/eef_calendar.dart';
import '../../core/models/eef_catalog_attribution.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_official_links.dart';

/// D'où viennent les données du catalogue, et qui parle.
///
/// ## Deux obligations, un seul bloc
///
/// 1. **La mention de paternité** de la Licence Ouverte 2.0 : citer le concédant
///    et la date de dernière mise à jour. Le catalogue dérive de jeux du
///    ministère de l'Enseignement supérieur ; le servir sans le dire, sur plus de
///    10 000 fiches et dans une app payante, est une réutilisation hors licence.
/// 2. **La non-affiliation** : KPB est un organisme privé, pas un canal de
///    l'État. Un étudiant qui prendrait cet écran pour la plateforme officielle
///    ferait confiance à la mauvaise source.
///
/// Les deux vont ensemble parce qu'elles répondent à la même question — « puis-je
/// me fier à ce que je lis, et où vérifier ? ».
///
/// La mention est SERVIE (`eefCatalog`), pas compilée : sa date change à chaque
/// réimport. Quand le serveur ne la sert pas (plus ancien, charge incomplète), le
/// bloc n'invente rien : il garde la non-affiliation, qui ne dépend d'aucune
/// donnée.
class EefDataNotice extends StatelessWidget {
  const EefDataNotice({super.key});

  /// La phrase de paternité, ou `null` quand le serveur n'a rien servi. Exposée
  /// pour qu'un test lise le texte exact sans passer par le rendu.
  static String? attributionText(EefCatalogAttribution? attribution) {
    if (attribution == null) return null;
    final date = EefCalendar.dayLabel(attribution.updatedAt);
    if (date == null) return null;
    final params = <String, String>{
      'producer': attribution.producer,
      'sources': attribution.sources.join(', '),
      'licence': attribution.licence,
      'date': date,
    };
    return attribution.sources.isEmpty
        ? 'eef_catalog_attribution_bare'.trParams(params)
        : 'eef_catalog_attribution'.trParams(params);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        final attribution = RemoteFeatureFlags.instance.catalogAttribution;
        final text = attributionText(attribution);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (text != null) ...[
              Text(
                text,
                style: KpbTextStyles.caption
                    .copyWith(color: context.kpb.textMuted),
              ),
              EefOfficialLink(
                url: attribution?.licenceUrl,
                labelKey: 'eef_catalog_licence_link',
              ),
              const SizedBox(height: KpbSpacing.sm),
            ],
            const EefAffiliationNotice(),
          ],
        );
      },
    );
  }
}

/// La rangée permanente, en bas de l'écran, qui ouvre [EefDataNotice].
///
/// Le bloc complet est en fin de liste, donc à des milliers de lignes de
/// l'écran sur un catalogue de 10 000 formations. Cette rangée garde les
/// mentions À UN GESTE, à tout moment, sans voler de place à la liste.
class EefSourcesRow extends StatelessWidget {
  const EefSourcesRow({super.key});

  Future<void> _open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KpbSpacing.pagePad,
            0,
            KpbSpacing.pagePad,
            KpbSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('eef_catalog_sources_title'.tr, style: KpbTextStyles.title),
              const SizedBox(height: KpbSpacing.md),
              const EefDataNotice(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'eef_catalog_sources_row'.tr,
      child: InkWell(
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.pagePad,
              vertical: KpbSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: context.kpb.textMuted,
                ),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Text(
                    'eef_catalog_sources_row'.tr,
                    style: KpbTextStyles.caption
                        .copyWith(color: context.kpb.textMuted),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: context.kpb.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
