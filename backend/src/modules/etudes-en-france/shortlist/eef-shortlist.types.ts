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
// C'est le constat qui a façonné tout le reste. Sur les 10 502 formations,
// `selectivity` est CONSTANTE à l'intérieur d'un cycle : tous les masters,
// toutes les L2, toutes les L3, tous les BUT, tous les DEUST sont
// `selective`, toutes les lignes `sante` `non_selective` ; seule la L1 varie
// (1 778 non sélectives, 734 sélectives).
//
// Et là où elle varie, elle ne parle pas du lecteur. « Non sélective » est la
// catégorie de Parcoursup, donc des élèves de terminale française : pour un
// candidat en demande d'admission préalable, l'université examine le dossier
// et peut le refuser (décision n° 5 du 02/10/2026,
// `docs/eef-dossier-relecture-procedures.md`). Les 2 428 lignes non
// sélectives du chemin post-bac sont toutes en DAP : les ranger en
// « sécurité » promettait précisément ce que la décision dément.
//
// Conséquence, chemin par chemin :
//
//   master               → trois étages, fondés sur la modalité de candidature
//                          publiée (1 259 / 1 474 / 262, plus 249 sans
//                          modalité publiée).
//   post-bac             → AUCUN étage. Le seul fait qui varie décrit une
//                          autre population que celle de l'étudiant.
//   L2/L3 (continuation) → AUCUN étage. Toutes ces lignes sont `selective` et
//                          aucune ne publie de modalité ni de licence
//                          conseillée.
//
// Sur ces deux chemins, la liste le DIT (`basis: null`) au lieu de rendre
// trois colonnes dont deux seraient vides ou arbitraires.
//
// Une colonne « cible » vide se lit comme « nous n'avons rien trouvé pour
// toi ». C'est faux, et c'est pire qu'une liste qui assume de n'avoir qu'un
// seul étage.
// ─────────────────────────────────────────────────────────────────────────────
import type { EefProcedureType } from '../catalog/eef-catalog.types';

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
 * liste.
 *
 * Elle ne dit pas la procédure, et ce n'est pas elle qui écarte les
 * formations hors procédure : c'est [EEF_SHORTLIST_PROCEDURES]. `licence1` le
 * montre. Les décisions du 02/10/2026 (catalogue 1.3.0) y laissent la 1re
 * année de Sciences Po (Paris) en `hors_eef` et le DCG en `parcoursup`, à côté
 * des L1 en DAP et des CUPGE en `eef` : retirer le cycle pour écarter ces 40
 * formations en aurait écarté 2 512.
 *
 * `ingenieur` n'apparaît nulle part. Ses 80 lignes sont toutes `hors_eef` —
 * admission propre à l'école, par concours ou plateforme dédiée — et le
 * filtre de procédure les écarterait de toute façon.
 */
export const EEF_PATH_CYCLES: Readonly<Record<EefEntryPath, readonly string[]>> =
  {
    post_bac: ['licence1', 'but1', 'deust', 'sante'],
    licence_continuation: ['licence2', 'licence3', 'licence_pro'],
    master: ['master'],
  };

/**
 * Les procédures que la shortlist recommande : celles de l'espace, la demande
 * d'admission préalable (dossier blanc ou jaune) et la procédure Études en
 * France.
 *
 * Liste FERMÉE, comme les cycles : une procédure qui n'y figure pas n'entre
 * pas dans la liste, y compris une valeur que le catalogue ajouterait demain.
 * Ce qu'elle écarte, et pourquoi :
 *
 *   hors_eef    admission propre à l'établissement : la 1re année de Sciences
 *               Po (Paris), 39 lignes, et les cycles d'ingénieurs, 80. Les
 *               ranger parmi des formations qui se demandent par la procédure
 *               les ferait passer pour ce qu'elles ne sont pas.
 *   parcoursup  le DCG, une ligne. Autre plateforme, autre calendrier, et
 *               `/config/app` ne sert que celui de la campagne Études en
 *               France : `campaign_dates_served_separately` serait faux pour
 *               lui (décision du 02/10/2026).
 *   NULL        une formation sans procédure, saisie à la main sous une
 *               université de l'import. La recherche ne la sert pas non plus :
 *               on ne recommande pas ce qu'on ne sait pas dire comment
 *               demander.
 *
 * Les formations `hors_eef` et `parcoursup` restent trouvables par la
 * recherche, avec la phrase de leur procédure.
 */
export const EEF_SHORTLIST_PROCEDURES: readonly EefProcedureType[] = [
  'dap_blanche',
  'dap_jaune',
  'eef',
];

/**
 * L'étage d'admission.
 *
 * `unranked` n'est pas un quatrième étage : c'est l'aveu qu'il n'y en a pas
 * pour ces lignes-là. Il sert dans deux cas — un chemin où aucune donnée ne
 * classe (post-bac, L2/L3), et les 249 masters qui ne publient pas leur
 * modalité de candidature. Les glisser dans « sécurité » les aurait fait
 * passer pour évalués ; les supprimer aurait caché des formations réelles.
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
 *
 * La sélectivité n'est pas un axe, bien qu'elle varie sur le chemin post-bac :
 * « non sélective » y est une catégorie Parcoursup qui ne dit rien d'un
 * candidat en DAP (voir l'en-tête). Le fait reste écrit dans les exigences
 * d'admission de chaque formation, que le catalogue 1.3.0 formule pour la DAP.
 */
export type EefShortlistBasis = 'admission_effort' | null;

export const EEF_PATH_BASIS: Readonly<
  Record<EefEntryPath, EefShortlistBasis>
> = {
  post_bac: null,
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
  | 'admission_exam';

export interface EefShortlistReason {
  readonly code: EefShortlistReasonCode;
  /// La valeur attestée : un identifiant de domaine, une modalité publiée, le
  /// libellé « Toutes licences ». Jamais une phrase.
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
  /// Le chemin d'entrée ne porte aucune donnée qui classe le candidat
  /// (post-bac, L2/L3) : les formations sont servies sans étage.
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
