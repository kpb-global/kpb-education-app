import '../models/app_models.dart';
import '../utils/study_level.dart';

/// Les quatre étiquettes de ciblage OneSignal d'un profil — et elles seules.
///
/// Les segments du tableau de bord OneSignal filtrent par égalité stricte sur
/// ces valeurs ; elles doivent donc être des clés stables, jamais des libellés
/// d'affichage. Trois défauts observés en production, corrigés ici :
/// - `level` partait brut : « High school » depuis l'onboarding, « Terminale »
///   depuis le profil, pour le même niveau. On envoie la clé normalisée
///   ([StudentLevelX.key]) : `terminale`, `bachelor_1`… `doctorat`.
/// - `target_country` retombait sur le pays de RÉSIDENCE quand aucun pays visé
///   n'était choisi : un étudiant guinéen sans destination entrait dans un
///   segment « vise la Guinée ». La résidence est déjà connue de OneSignal
///   (champ natif `country`) ; on n'envoie ici que le premier pays visé.
/// - une valeur devenue inconnue laissait l'ancienne en place côté OneSignal.
///
/// Une valeur vide signifie « retirer l'étiquette » : [OneSignalService] la
/// supprime au lieu de l'ignorer, pour qu'un profil modifié ne reste pas dans
/// un segment qui ne le concerne plus.
Map<String, String> oneSignalTargetingTags(
  UserProfile profile, {
  required String localeCode,
}) {
  return {
    'account_type': profile.accountType.name,
    'level': normalizeStudentLevel(profile.currentLevel)?.key ?? '',
    'target_country': profile.targetCountryIds.isNotEmpty
        ? profile.targetCountryIds.first.trim()
        : '',
    'locale': localeCode,
  };
}
