// Établissements publics diplômants ABSENTS des 70 universités.
//
// Le filtre historique est `typologie_d_universites_et_assimiles is not null`.
// Il est juste pour les universités, et il est aveugle pour tout le reste :
// le MESR classe UTC, Sciences Po ou l'INALCO sans cette typologie. La liste
// ci-dessous est fermée, UAI par UAI, après lecture du jeu
// `fr-esr-principaux-etablissements-enseignement-superieur`. On n'y met pas
// les écoles d'ingénieurs (INSA, Ponts, ISAE) : ce catalogue décrit la
// procédure universitaire, pas les concours.
//
// Une UAI n'entre dans un fichier du dépôt que si le pipeline trouve au moins
// une formation rattachée. Une fiche sans formation ne serait qu'un nom.
import type { EefInstitutionKind } from './eef-catalog.types';

export interface AdditionalEstablishment {
  readonly uai: string;
  readonly kind: Exclude<EefInstitutionKind, 'universite_publique'>;
}

export const ADDITIONAL_DEGREE_GRANTING: readonly AdditionalEstablishment[] = [
  { uai: '0601223D', kind: 'universite_technologie' },
  { uai: '0101060Y', kind: 'universite_technologie' },
  { uai: '0651124U', kind: 'universite_technologie' },
  { uai: '0753431X', kind: 'institut_etudes_politiques' },
  { uai: '0130221V', kind: 'institut_etudes_politiques' },
  { uai: '0330192E', kind: 'institut_etudes_politiques' },
  { uai: '0690173N', kind: 'institut_etudes_politiques' },
  { uai: '0310133B', kind: 'institut_etudes_politiques' },
  { uai: '0753488J', kind: 'grand_etablissement' },
  { uai: '0753471R', kind: 'grand_etablissement' },
  { uai: '0753742K', kind: 'grand_etablissement' },
  { uai: '0694123G', kind: 'grand_etablissement' },
  { uai: '0753494R', kind: 'grand_etablissement' },
  { uai: '0692459Y', kind: 'grand_etablissement' },
  { uai: '0753237L', kind: 'grand_etablissement' },
];

const BY_UAI = new Map(
  ADDITIONAL_DEGREE_GRANTING.map((row) => [row.uai.toUpperCase(), row.kind]),
);

/// Le premier UAI, ou n'importe lequel d'une liste séparée par `;`.
export function institutionKindForUai(
  uai: string,
): AdditionalEstablishment['kind'] | null {
  for (const code of uai.split(';')) {
    const kind = BY_UAI.get(code.trim().toUpperCase());
    if (kind) return kind;
  }
  return null;
}

/// Clause `where` pour retrouver ces fiches dans le jeu des établissements.
export function additionalInstitutionWhere(): string {
  return ADDITIONAL_DEGREE_GRANTING.map((row) => `uai="${row.uai}"`).join(
    ' or ',
  );
}
