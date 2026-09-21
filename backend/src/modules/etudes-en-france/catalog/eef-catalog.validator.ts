// ─────────────────────────────────────────────────────────────────────────────
// Le validateur strict du catalogue « Études en France ».
//
// Il a une seule raison d'exister, et le dépôt l'a apprise à ses dépens :
// `catalog_source.dart:1-9` raconte comment deux bourses qui n'existent nulle
// part ont atteint un appareil de production. Ici le volume est mille fois plus
// grand, donc la relecture humaine ligne à ligne est impossible — la seule
// défense qui passe à l'échelle est une machine qui refuse.
//
// CE QU'IL VÉRIFIE, ET POURQUOI CHAQUE RÈGLE EXISTE
//
// • Une source HTTPS officielle par formation. Sans elle, personne ne peut
//   re-vérifier, donc personne ne re-vérifiera.
// • Des identifiants uniques et stables. Un doublon d'id transforme l'import
//   « créer si absent » en « ne rien faire », silencieusement.
// • Des énumérations fermées. Une procédure inconnue servie à un étudiant
//   l'envoie sur le mauvais calendrier.
// • Un PLAFOND de classement par repli. Le domaine d'une formation est deviné
//   par mots-clés ; tant que le taux de repli reste bas, la devinette est
//   marginale. S'il monte, c'est que la source a changé de vocabulaire et que
//   le classement ne veut plus rien dire — il faut le savoir avant l'étudiant.
// • Un PLANCHER de volume et de couverture. Un catalogue qui perd la moitié de
//   ses universités entre deux collectes n'est pas un catalogue plus petit,
//   c'est une collecte cassée.
// ─────────────────────────────────────────────────────────────────────────────
import {
  EEF_CYCLES,
  EEF_PROCEDURE_TYPES,
  type EefCatalog,
} from './eef-catalog.types';

const KNOWN_FIELD_IDS = new Set([
  'd01', 'd02', 'd03', 'd04', 'd05', 'd06',
  'd07', 'd08', 'd09', 'd10', 'd11', 'd12',
]);
const KNOWN_LEVELS = new Set(['Bac+2', 'Bachelor', 'Master', 'Doctorat']);
const KNOWN_SELECTIVITY = new Set(['selective', 'non_selective']);
const KNOWN_DATASETS = new Set([
  'parcoursup',
  'trouver-mon-master',
  'diplomes-prepares',
]);
const KNOWN_CYCLES = new Set<string>(EEF_CYCLES);
const KNOWN_PROCEDURES = new Set<string>(EEF_PROCEDURE_TYPES);

export interface EefCatalogGates {
  /// Nombre minimal d'universités. 69 des 70 publient au moins un master ;
  /// le plancher est posé sous ce chiffre, pas dessus, pour qu'une fermeture
  /// réelle ne fasse pas échouer la CI.
  readonly minInstitutions: number;
  readonly minPrograms: number;
  /// Part maximale de formations dont le domaine vient du repli.
  readonly maxFallbackRatio: number;
  /// Part minimale d'universités portant au moins une formation.
  readonly minInstitutionsWithPrograms: number;
}

export const DEFAULT_EEF_GATES: EefCatalogGates = {
  minInstitutions: 60,
  minPrograms: 8000,
  maxFallbackRatio: 0.08,
  minInstitutionsWithPrograms: 0.9,
};

export interface EefValidationResult {
  readonly errors: string[];
  readonly warnings: string[];
  readonly stats: {
    readonly institutions: number;
    readonly programs: number;
    readonly fallbackFields: number;
    readonly fallbackRatio: number;
    readonly institutionsWithPrograms: number;
    readonly byProcedure: Record<string, number>;
    readonly byLevel: Record<string, number>;
  };
}

function isHttpsUrl(value: string): boolean {
  if (!value.startsWith('https://')) return false;
  try {
    // `new URL` attrape ce que `startsWith` laisse passer : « https:// » seul,
    // un espace au milieu, un hôte vide.
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname.includes('.');
  } catch {
    return false;
  }
}

export function validateEefCatalog(
  catalog: EefCatalog,
  gates: EefCatalogGates = DEFAULT_EEF_GATES,
): EefValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];
  const institutionIds = new Set<string>();
  const programIds = new Set<string>();
  const byProcedure: Record<string, number> = {};
  const byLevel: Record<string, number> = {};
  let programs = 0;
  let fallbackFields = 0;
  let institutionsWithPrograms = 0;

  for (const file of catalog.universities) {
    const institution = file.institution;
    const where = institution?.id ?? '(sans id)';
    if (!institution) {
      errors.push('Un fichier ne porte aucun établissement.');
      continue;
    }
    if (institutionIds.has(institution.id)) {
      errors.push(`Établissement en double : ${institution.id}.`);
    }
    institutionIds.add(institution.id);
    if (institution.uai.trim() === '') {
      errors.push(`${where} : UAI manquant.`);
    }
    if (institution.nameFr.trim() === '' || institution.nameEn.trim() === '') {
      errors.push(`${where} : nom FR ou EN manquant.`);
    }
    if (institution.city.trim() === '' || institution.region.trim() === '') {
      errors.push(`${where} : ville ou région manquante.`);
    }
    if (!isHttpsUrl(institution.websiteUrl)) {
      errors.push(`${where} : site officiel absent ou non HTTPS.`);
    }
    if (!isHttpsUrl(institution.sourceUrl)) {
      errors.push(`${where} : source de vérification absente ou non HTTPS.`);
    }
    if (institution.enrolment && institution.enrolment.count <= 0) {
      errors.push(`${where} : effectif étudiant non positif.`);
    }

    if (file.programs.length > 0) institutionsWithPrograms += 1;
    for (const program of file.programs) {
      programs += 1;
      byProcedure[program.procedureType] =
        (byProcedure[program.procedureType] ?? 0) + 1;
      byLevel[program.level] = (byLevel[program.level] ?? 0) + 1;
      if (program.fieldIsFallback) fallbackFields += 1;
      const pWhere = `${where}/${program.id}`;
      if (programIds.has(program.id)) {
        errors.push(`Formation en double : ${program.id}.`);
      }
      programIds.add(program.id);
      if (program.institutionId !== institution.id) {
        errors.push(
          `${pWhere} : rattachée à ${program.institutionId}, rangée sous ${institution.id}.`,
        );
      }
      if (program.nameFr.trim() === '') errors.push(`${pWhere} : intitulé vide.`);
      if (!KNOWN_FIELD_IDS.has(program.fieldId)) {
        errors.push(`${pWhere} : domaine hors référentiel (${program.fieldId}).`);
      }
      if (!KNOWN_LEVELS.has(program.level)) {
        errors.push(`${pWhere} : niveau hors référentiel (${program.level}).`);
      }
      if (!KNOWN_CYCLES.has(program.cycle)) {
        errors.push(`${pWhere} : cycle hors référentiel (${program.cycle}).`);
      }
      if (!KNOWN_PROCEDURES.has(program.procedureType)) {
        errors.push(
          `${pWhere} : procédure hors référentiel (${program.procedureType}).`,
        );
      }
      if (!KNOWN_SELECTIVITY.has(program.selectivity)) {
        errors.push(`${pWhere} : sélectivité hors référentiel.`);
      }
      if (!KNOWN_DATASETS.has(program.dataset)) {
        errors.push(`${pWhere} : jeu de données inconnu (${program.dataset}).`);
      }
      if (!Number.isInteger(program.durationYears) || program.durationYears <= 0) {
        errors.push(`${pWhere} : durée non entière ou nulle.`);
      }
      if (!isHttpsUrl(program.sourceUrl)) {
        errors.push(`${pWhere} : fiche officielle absente ou non HTTPS.`);
      }
      // Une valeur encore jointe par des barres verticales.
      //
      // Le portail des masters publie `for_lic_conseille` tantôt en tableau de
      // mentions, tantôt en UNE chaîne jointe par des `|`. Non découpée, elle
      // produit une « mention » du genre « Droit|Economie|Gestion » : un
      // libellé que personne ne publie, qu'aucun appariement ne reconnaît, et
      // qui enterre donc trois licences conseillées dans une case introuvable.
      // 501 entrées étaient dans ce cas avant que le constructeur ne découpe.
      //
      // Le gardien est ici plutôt que dans le constructeur parce que le défaut
      // n'était pas une règle manquante mais une FORME de la source qu'on
      // n'avait pas vue : c'est la donnée produite qu'il faut relire.
      for (const [label, values] of [
        ['licences conseillées', program.recommendedBachelors],
        ['modalités de candidature', program.admissionModes],
        ['parcours', program.tracks],
      ] as const) {
        const piped = values.filter((value) => value.includes('|'));
        if (piped.length > 0) {
          errors.push(
            `${pWhere} : ${label} non découpées (${piped.join(' / ')}).`,
          );
        }
      }
    }
  }

  const fallbackRatio = programs === 0 ? 0 : fallbackFields / programs;
  const coverage =
    institutionIds.size === 0
      ? 0
      : institutionsWithPrograms / institutionIds.size;

  if (institutionIds.size < gates.minInstitutions) {
    errors.push(
      `Plancher d'établissements non atteint : ${institutionIds.size} < ${gates.minInstitutions}.`,
    );
  }
  if (programs < gates.minPrograms) {
    errors.push(
      `Plancher de formations non atteint : ${programs} < ${gates.minPrograms}.`,
    );
  }
  if (fallbackRatio > gates.maxFallbackRatio) {
    errors.push(
      `Trop de domaines classés par repli : ${(fallbackRatio * 100).toFixed(1)} % > `
      + `${(gates.maxFallbackRatio * 100).toFixed(1)} %. La source a probablement changé de vocabulaire.`,
    );
  }
  if (coverage < gates.minInstitutionsWithPrograms) {
    errors.push(
      `Trop d'universités sans aucune formation : ${(coverage * 100).toFixed(1)} % couvertes, `
      + `plancher ${(gates.minInstitutionsWithPrograms * 100).toFixed(1)} %.`,
    );
  }

  const manifest = catalog.manifest;
  if (!manifest || manifest.catalogVersion?.trim() === '') {
    errors.push('Manifeste sans version de catalogue.');
  }
  if (!manifest?.sources?.length) {
    errors.push('Manifeste sans aucune source déclarée.');
  }
  for (const source of manifest?.sources ?? []) {
    if (source.licence.trim() === '') {
      errors.push(`Source ${source.datasetId} : licence non déclarée.`);
    }
    if (source.fetchedAt.trim() === '') {
      errors.push(`Source ${source.datasetId} : date de collecte absente.`);
    }
  }
  if (manifest && manifest.institutionCount !== institutionIds.size) {
    errors.push(
      `Manifeste : ${manifest.institutionCount} établissements annoncés, ${institutionIds.size} présents.`,
    );
  }
  if (manifest && manifest.programCount !== programs) {
    errors.push(
      `Manifeste : ${manifest.programCount} formations annoncées, ${programs} présentes.`,
    );
  }

  // Un avertissement, pas une erreur : un millésime ancien n'invalide pas la
  // structure d'une offre de formation, mais l'exploitation doit le voir.
  for (const source of manifest?.sources ?? []) {
    const vintageYear = Number.parseInt(source.vintage.slice(0, 4), 10);
    const currentYear = new Date(manifest.generatedAt).getUTCFullYear();
    if (Number.isFinite(vintageYear) && currentYear - vintageYear >= 3) {
      warnings.push(
        `Source ${source.datasetId} : millésime ${source.vintage}, soit `
        + `${currentYear - vintageYear} ans. Les lignes qui en viennent doivent être `
        + "revérifiées avant publication, et leurs chiffres datés ne sont pas importés.",
      );
    }
  }

  return {
    errors,
    warnings,
    stats: {
      institutions: institutionIds.size,
      programs,
      fallbackFields,
      fallbackRatio,
      institutionsWithPrograms,
      byProcedure,
      byLevel,
    },
  };
}
