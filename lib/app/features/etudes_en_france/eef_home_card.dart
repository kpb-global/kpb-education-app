import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/data/eef_calendar.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_entry.dart';

/// La carte d'accueil de l'espace « Études en France ».
///
/// **Elle s'auto-masque**, comme `DailyScholarshipCard` et `StoryOfWeekCard` à
/// côté d'elle : quand le module est éteint, elle rend un `SizedBox.shrink()` et
/// l'accueil n'a aucune condition à porter. C'est ce qui fait qu'une bascule
/// serveur suffit — l'accueil n'a pas besoin de savoir qu'il existe un drapeau.
///
/// L'espacement du bas vit DANS la carte, pas autour : sinon l'accueil garderait
/// un trou de 24 px quand la carte se masque. Le commentaire de
/// `DailyScholarshipCard` fait la même remarque, pour la même raison.
class EefHomeCard extends StatelessWidget {
  const EefHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        if (!EefEntry.isVisible) return const SizedBox.shrink();

        final days = EefCalendar.daysUntilOpening();
        final range = EefCalendar.rangeLabel();
        // La ligne de contexte : le compte à rebours s'il y en a un, sinon la
        // fenêtre, sinon RIEN. Pas de repli inventé — la carte se contente
        // alors du sous-titre, qui ne parle pas de dates.
        final timing = days != null && days > 0
            ? 'eef_opens_in_days'.trParams({'days': '$days'})
            : range;

        return Padding(
          padding: const EdgeInsets.only(bottom: KpbSpacing.lg),
          child: KpbCard(
            variant: KpbCardVariant.interactive,
            onTap: () => Get.to<void>(
              () => const EefEntry(source: 'home_card'),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: KpbColors.actionPrimarySoft,
                    borderRadius: KpbRadius.mdBr,
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: KpbColors.actionPrimary,
                  ),
                ),
                const SizedBox(width: KpbSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('eef_title'.tr, style: KpbTextStyles.titleSm),
                      const SizedBox(height: 2),
                      Text(
                        'eef_home_card_subtitle'.tr,
                        style: KpbTextStyles.bodySm
                            .copyWith(color: context.kpb.textMuted),
                      ),
                      if (timing != null) ...[
                        const SizedBox(height: KpbSpacing.xs),
                        Text(
                          timing,
                          style: KpbTextStyles.caption
                              .copyWith(color: KpbColors.actionPrimary),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.kpb.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
