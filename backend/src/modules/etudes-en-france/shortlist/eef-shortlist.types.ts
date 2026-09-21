// ─────────────────────────────────────────────────────────────────────────────
// La shortlist « Études en France » — le vocabulaire.
//
// CE QUE CETTE FONCTIONNALITÉ PROMET, ET CE QU'ELLE REFUSE DE PROMETTRE
//
// Le plan (§ 6) demande une liste à trois étages — ambition / cible / sécurité
// — avec une justification par établissement, et prévient : « un pourcentage
// opaque dans un produit payant se retourne au premier refus d'admission ».
//
// On va plus loin que la mise en garde : il n'y a AUCUN pourcentage ici. Pas
// parce que ce serait impopulaire, mais parce qu'aucune donnée ouverte ne
// permet d'en calculer un. Le catalogue ne publie ni taux d'admission, ni
// capacité d'accueil, ni nombre de candidats. Un « 72 % de chances » aurait
// été un nombre inventé portant l'autorité d'un nombre mesuré.
//
// Ce que la liste sert à la place : des FAITS PUBLIÉS, chacun nommé, chacun
// traçable jusqu'à la fiche officielle. L'étudiant peut être en désaccord avec
// le classement — il ne peut pas être trompé sur ce qui le fonde.
//
// LES TROIS ÉTAGES N'EXISTENT PAS TOUJOURS
//
// C'est le constat qui a façonné tout le reste. Sur les 10 247 formations,
// `selectivity` est CONSTANTE à l'intérieur d'un cycle : tous les masters,
// toutes les L2, toutes les L3, tous les BUT, tous les DEUST sont
// `selective` ; seule la L1 varie (1 723 non sélectives, 663 sélectives).
//
// Conséquence, chemin par chemin :
//
//   master               → trois étages, fondés sur la modalité de candidature
//                          publiée (1 221 / 1 442 / 251, plus 198 sans
//                          modalité publiée).
//   post-bac             → deux étages, fondés sur la sélectivité publiée.
//                          Il n'existe pas de troisième valeur : en fabriquer
//                          un « milieu » serait une invention.
//   L2/L3 (continuation) → AUCUN étage. Toutes ces lignes sont `selective` et
//                          aucune ne publie de modalité ni de licence
//                          conseillée. La liste le DIT (`basis: null`) au lieu
//                          de rendre trois colonnes dont deux seraient vides
//                          ou arbitraires.
//
// Une colonne « cible » vide se lit comme « nous n'avons rien trouvé pour
// toi ». C'est faux, et c'est pire qu'une liste qui assume de n'avoir qu'un
// seul étage.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Le chemin d'entrée, déduit de ce que l'étudiant a DÉCLARÉ.
 *
 * Ce n'est pas le niveau visé : c'est la porte par laquelle il entre, et c'est
 * elle qui décide à la fois des cycles candidats et de ce qu'on sait — ou non
 * — du risque d'admission.
 */
export type EefEntryPath = 'post_bac' | 'licence_continuation' | 'master';

/**
 * Les cycles réellement atteignables par chaque chemin.
 *
 * Table FERMÉE. Un cycle qui n'y figure pas n'est pas « probablement
 * accessible » : il est hors de ce chemin, et la formation n'entre pas dans la
 * liste. `ingenieur` n'apparaît nulle part, non par oubli — ces 74 lignes sont
 * `hors_eef`, leur sélection appartient à l'école ou au concours commun, et
 * les ranger parmi des formations qui se demandent par la procédure les ferait
 * passer pour ce qu'elles ne sont pas.
 */
export const EEF_PATH_CYCLES: Readonly<Record<EefEntryPath, readonly string[]>> =
  {
    post_bac: ['licence1', 'but1', 'deust', 'sante'],
    licence_continuation: ['licence2', 'licence3', 'licence_pro'],
    master: ['master'],
  };

/**
 * L'étage d'admission.
 *
 * `unranked` n'est pas un quatrième étage : c'est l'aveu qu'il n'y en a pas
 * pour ces lignes-là. Il sert dans deux cas — un chemin où aucune donnée ne
 * classe (L2/L3), et les 198 masters qui ne publient pas leur modalité de
 * candidature. Les glisser dans « sécurité » les aurait fait passer pour
 * évalués ; les supprimer aurait caché des formations réelles.
 */
export type EefShortlistTier = 'securite' | 'cible' | 'ambition' | 'unranked';

export const EEF_SHORTLIST_TIERS: readonly EefShortlistTier[] = [
  'securite',
  'cible',
  'ambition',
  'unranked',
];

/**
 * Sur quoi les étages reposent. Servi au client pour qu'il puisse DIRE le
 * critère, au lieu d'afficher trois colonnes sans expliquer ce qui les sépare.
 *
 * `null` veut dire qu'aucune donnée ouverte ne classe ce chemin. C'est une
 * réponse, pas une panne.
 */
export type EefShortlistBasis = 'admission_effort' | 'selectivity' | null;

export const EEF_PATH_BASIS: Readonly<
  Record<EefEntryPath, EefShortlistBasis>
> = {
  post_bac: 'selectivity',
  licence_continuation: null,
  master: 'admission_effort',
};

/**
 * Pourquoi CETTE formation est dans la liste, et à cet étage.
 *
 * Codes fermés, jamais de prose : la phrase se traduit côté client, ce qui
 * garantit la parité FR/EN par construction et évite qu'une justification
 * arrive en français à un lecteur anglophone. Chaque code voyage avec la
 * VALEUR attestée qui l'a produit — le domaine, la mention, la modalité —
 * pour que la justification soit vérifiable sur la fiche officielle.
 */
export type EefShortlistReasonCode =
  /// Le domaine de la formation est l'un de ceux que l'étudiant a déclarés.
  | 'field_declared'
  /// L'une des licences conseillées par l'établissement appartient à un
  /// domaine déclaré. C'est le signal que rien d'autre ne donne : un master de
  /// management dont la porte d'entrée est ouverte aux licences de sciences de
  /// la vie n'apparaîtrait dans aucun filtre par domaine du diplôme. Pour un
  /// étudiant de « droit, économie », 594 masters sont dans ce cas.
  | 'bachelor_domain_recommended'
  /// L'établissement publie « Toutes licences » : la porte est explicitement
  /// ouverte à n'importe quelle licence. 302 masters le déclarent.
  | 'bachelor_any_accepted'
  /// Candidature sur dossier seul.
  | 'admission_file_only'
  /// La candidature comporte un entretien.
  | 'admission_interview'
  /// La candidature comporte un examen ou un concours.
  | 'admission_exam'
  /// La capacité d'accueil est la seule limite publiée.
  | 'selectivity_open'
  /// L'établissement arbitre entre les dossiers.
  | 'selectivity_arbitrated';

export interface EefShortlistReason {
  readonly code: EefShortlistReasonCode;
  /// La valeur attestée : un identifiant de domaine, une modalité publiée, une
  /// sélectivité. Jamais une phrase.
  readonly value: string;
}

/**
 * Ce que la liste NE SAIT PAS, dit une fois pour toutes en tête de réponse.
 *
 * Ces trois-là valent pour chaque ligne du catalogue, donc les répéter par
 * formation serait du bruit — mais les taire ferait croire que le silence est
 * une absence de frais, une absence d'exigence de français, ou une absence
 * d'échéance.
 */
export type EefShortlistDisclosure =
  /// Les droits réellement payés dépendent d'une exonération que les données
  /// ouvertes ne publient pas.
  | 'tuition_not_published'
  /// Aucun jeu ouvert ne publie le niveau de français exigé formation par
  /// formation.
  | 'french_level_not_published'
  /// Les dates de campagne varient par pays et par procédure : elles sont
  /// servies par `/config/app`, jamais figées dans une ligne de catalogue.
  | 'campaign_dates_served_separately'
  /// L'étudiant n'a déclaré aucun domaine : la liste n'est donc resserrée sur
  /// aucune filière, et le dit plutôt que de laisser croire à un ciblage.
  | 'no_field_declared'
  /// Le chemin d'entrée ne porte aucune donnée de classement : les formations
  /// sont servies sans étage.
  | 'no_ranking_data';

/**
 * Pourquoi aucune liste n'a pu être construite.
 *
 * Ce n'est PAS une erreur : la lecture réussit, et l'état « je ne peux pas
 * encore » est une information que l'écran sait rendre — il demande le champ
 * manquant. Répondre 4xx aurait produit un écran d'erreur là où il faut une
 * question.
 */
export type EefShortlistBlocked =
  /// Aucune déclaration d'intérêt n'existe pour ce profil.
  | 'no_declaration'
  /// Le niveau visé manque : c'est lui qui décide du chemin.
  | 'target_level_missing'
  /// Le niveau courant manque : sans lui, « viser une licence » peut vouloir
  /// dire entrer en L1 ou continuer en L3, et les deux listes n'ont rien de
  /// commun.
  | 'current_level_missing'
  /// Le couple déclaré ne correspond à aucun chemin de la table fermée —
  /// « autre », ou une combinaison qu'on refuse d'interpréter.
  | 'declaration_unmappable'
  /// Le niveau visé existe, mais le catalogue ne le couvre pas encore. Le
  /// doctorat est dans ce cas : aucune ligne, et le dire vaut mieux que de
  /// servir une liste vide sans motif.
  | 'level_not_in_catalog';
