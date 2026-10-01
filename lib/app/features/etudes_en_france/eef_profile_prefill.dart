import 'package:get/get.dart';

import '../../core/data/mock_catalog/fields_data.dart';
import '../../core/utils/study_level.dart';

/// Les niveaux que la déclaration « Études en France » connaît. Identifiants
/// stables : ils partent en base et dans l'export commercial.
const kEefLevelSlugs = <String>[
  'terminale',
  'bac',
  'licence',
  'master',
  'doctorat',
  'autre',
];

/// Les domaines que la déclaration connaît : la taxonomie canonique d01–d12 du
/// catalogue. Le catalogue « Études en France » est classé sur ces mêmes codes
/// (CAT-M01), donc ce que l'étudiant coche ici est ce que la recherche filtre.
final List<String> kEefFieldIds = [for (final f in kFields) f.id];

/// Le niveau de la déclaration correspondant au niveau du PROFIL, ou `null`.
///
/// ## Pourquoi une table fermée, et pas une copie de la chaîne
///
/// Le profil stocke une ANNÉE d'étude (`bachelor_2`, `master_1`, « High school »
/// pour le lycée) saisie à l'onboarding sous plusieurs écritures. La déclaration
/// stocke un NIVEAU (`licence`, `master`…) dans un vocabulaire fermé. Recopier
/// l'un dans l'autre ferait partir « bachelor_2 » dans une colonne dont
/// l'export commercial attend `licence` — et un export dont la colonne mélange
/// deux vocabulaires n'est pas exploitable.
///
/// Une valeur que la table ne reconnaît pas rend `null` : le champ reste vide
/// plutôt que de recevoir une approximation que l'étudiant prendrait pour la
/// sienne.
String? eefLevelSlugForProfileLevel(String? raw) {
  final level = normalizeStudentLevel(raw);
  if (level == null) return null;
  return switch (level) {
    StudentLevel.terminale => 'terminale',
    StudentLevel.bachelor1 ||
    StudentLevel.bachelor2 ||
    StudentLevel.bachelor3 =>
      'licence',
    StudentLevel.master1 || StudentLevel.master2 => 'master',
    StudentLevel.doctorat => 'doctorat',
  };
}

/// Les domaines du profil qui existent dans la taxonomie de la déclaration, dans
/// l'ordre du profil, sans doublon. Un identifiant inconnu est écarté : il
/// partirait au serveur comme un filtre qui ne correspond à aucune formation.
List<String> eefFieldIdsFromProfile(Iterable<String>? profileFieldIds) {
  final known = kEefFieldIds.toSet();
  final out = <String>[];
  for (final id in profileFieldIds ?? const <String>[]) {
    final trimmed = id.trim();
    if (known.contains(trimmed) && !out.contains(trimmed)) out.add(trimmed);
  }
  return out;
}

/// Le libellé d'un niveau de la déclaration, dans la langue active, ou `null`
/// pour une valeur que l'app ne connaît pas. `.tr` rend la CLÉ quand elle
/// manque : afficher « eef_level_x » à un étudiant serait pire que de ne rien
/// dire.
String? eefLevelLabel(String? slug) {
  if (slug == null || slug.isEmpty) return null;
  final key = 'eef_level_$slug';
  final translated = key.tr;
  return translated == key ? null : translated;
}

/// Le libellé d'un domaine (`d07`), dans la langue active. Le code brut si le
/// domaine est inconnu : un code vaut mieux qu'un libellé inventé.
String eefFieldLabel(String id) {
  final locale = Get.locale?.languageCode ?? 'fr';
  for (final field in kFields) {
    if (field.id == id) return field.name.resolve(locale);
  }
  return id;
}
