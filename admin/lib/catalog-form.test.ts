import { describe, expect, it } from 'vitest';

import {
  DraftError,
  EMPTY_INSTITUTION_DRAFT,
  EMPTY_PROGRAM_DRAFT,
  splitList,
  toInstitutionInput,
  toProgramInput,
} from './catalog-form';

/**
 * Le backend est STRICT depuis #271 sur les cinq colonnes de scoring : une
 * valeur présente mais mal typée lève un 400. Un formulaire HTML rend « rien »
 * sous forme de chaîne vide, y compris pour un input numérique ou une date —
 * les envoyer telles quelles ferait échouer l'enregistrement sur un champ que
 * l'utilisateur n'a jamais touché. Ces tests fixent la traduction.
 */
const base = {
  ...EMPTY_PROGRAM_DRAFT,
  institutionId: 'omnes-ece',
  countryId: 'fra',
  fieldId: 'd01',
  nameFr: 'Bachelor Cybersécurité',
};

describe('toProgramInput — champs vides', () => {
  it('à la création, OMET les colonnes vides plutôt que d’envoyer ""', () => {
    const payload = toProgramInput(base, 'create');
    expect(payload).toEqual({
      institutionId: 'omnes-ece',
      countryId: 'fra',
      fieldId: 'd01',
      nameFr: 'Bachelor Cybersécurité',
    });
    expect('minGpaRequired' in payload).toBe(false);
    expect('tuitionMinEur' in payload).toBe(false);
    expect('applicationDeadline' in payload).toBe(false);
    expect('teachingLanguages' in payload).toBe(false);
  });

  // En édition, un champ vidé doit VIDER la colonne. L'omettre la laisserait
  // telle quelle : l'utilisateur croirait avoir effacé une valeur toujours là.
  it('à l’édition, envoie null pour vider une colonne de scoring', () => {
    const payload = toProgramInput(base, 'edit');
    expect(payload.minGpaRequired).toBeNull();
    expect(payload.tuitionMinEur).toBeNull();
    expect(payload.applicationDeadline).toBeNull();
    expect(payload.teachingLanguages).toBeNull();
  });

  // Revue #275 (P2) : `updateProgram` traite une clé ABSENTE comme « ne pas
  // toucher ». Omettre un champ texte vidé faisait afficher « enregistré »
  // pendant que l'ancienne valeur survivait et réapparaissait au rechargement.
  // Je n'avais appliqué la sémantique création/édition qu'aux champs numériques.
  it('à l’édition, vide aussi les champs texte et les listes', () => {
    const payload = toProgramInput(base, 'edit');
    expect(payload.levelFr).toBe('');
    expect(payload.durationFr).toBe('');
    expect(payload.tuitionFr).toBe('');
    expect(payload.languageFr).toBe('');
    expect(payload.nameEn).toBe('');
    expect(payload.requirementsFr).toEqual([]);
  });
});

describe('toProgramInput — colonnes de scoring', () => {
  it('convertit les nombres et tronque le plancher en euros', () => {
    const payload = toProgramInput(
      { ...base, minGpaRequired: '12.5', tuitionMinEur: '6690.9' },
      'create',
    );
    expect(payload.minGpaRequired).toBe(12.5);
    expect(payload.tuitionMinEur).toBe(6690);
  });

  it('accepte la virgule décimale française', () => {
    expect(
      toProgramInput({ ...base, minGpaRequired: '12,5' }, 'create')
        .minGpaRequired,
    ).toBe(12.5);
  });

  it.each(['douze', '12 sur 20', '--3'])(
    'refuse « %s » AVANT l’appel réseau',
    (raw) => {
      expect(() =>
        toProgramInput({ ...base, minGpaRequired: raw }, 'create'),
      ).toThrow(DraftError);
    },
  );

  it('refuse une valeur négative', () => {
    expect(() =>
      toProgramInput({ ...base, tuitionMinEur: '-100' }, 'create'),
    ).toThrow(DraftError);
  });

  it('découpe les langues d’enseignement', () => {
    expect(
      toProgramInput({ ...base, teachingLanguages: 'fr, en ,' }, 'create')
        .teachingLanguages,
    ).toEqual(['fr', 'en']);
  });
});

describe('toProgramInput — date limite', () => {
  it('laisse passer une date ISO valide', () => {
    expect(
      toProgramInput({ ...base, applicationDeadline: '2027-03-01' }, 'create')
        .applicationDeadline,
    ).toBe('2027-03-01');
  });

  // Le backend refuse ces formes depuis #271 : « 03/01/2027 » y était lu comme
  // le 1er mars en heure locale, « 2027-02-30 » reporté au 2 mars. On les
  // arrête ici pour que l'erreur s'affiche dans le formulaire.
  it.each(['03/01/2027', '1 mars 2027', '20270301', '2027-3-1'])(
    'refuse le format « %s »',
    (raw) => {
      expect(() =>
        toProgramInput({ ...base, applicationDeadline: raw }, 'create'),
      ).toThrow(DraftError);
    },
  );

  it.each(['2027-02-30', '2027-02-29', '2027-13-01', '2027-04-31'])(
    'refuse « %s » : jour inexistant au calendrier',
    (raw) => {
      expect(() =>
        toProgramInput({ ...base, applicationDeadline: raw }, 'create'),
      ).toThrow(DraftError);
    },
  );

  it('accepte un 29 février bissextile', () => {
    expect(
      toProgramInput({ ...base, applicationDeadline: '2028-02-29' }, 'create')
        .applicationDeadline,
    ).toBe('2028-02-29');
  });
});

describe('toProgramInput — champs obligatoires', () => {
  it.each([
    ['institutionId', 'Établissement'],
    ['countryId', 'Pays'],
    ['fieldId', 'Filière'],
    ['nameFr', 'Nom (FR)'],
  ])('exige %s', (key) => {
    expect(() =>
      toProgramInput({ ...base, [key]: '  ' }, 'create'),
    ).toThrow(DraftError);
  });
});

describe('toInstitutionInput', () => {
  it('n’exige que le nom et le pays', () => {
    expect(
      toInstitutionInput({
        ...EMPTY_INSTITUTION_DRAFT,
        nameFr: 'Université Mundiapolis',
        countryId: 'mar',
      }),
    ).toEqual({
      nameFr: 'Université Mundiapolis',
      countryId: 'mar',
      isPartner: false,
    });
  });

  it('découpe les périodes de rentrée', () => {
    expect(
      toInstitutionInput({
        ...EMPTY_INSTITUTION_DRAFT,
        nameFr: 'X',
        countryId: 'mar',
        intakePeriods: 'Septembre, Février',
      }).intakePeriods,
    ).toEqual(['Septembre', 'Février']);
  });

  it('refuse un pays vide — la colonne n’est pas une clé étrangère', () => {
    expect(() =>
      toInstitutionInput({ ...EMPTY_INSTITUTION_DRAFT, nameFr: 'X' }),
    ).toThrow(DraftError);
  });
});

describe('splitList', () => {
  it('écarte les entrées vides et les espaces', () => {
    expect(splitList(' a , ,b,  ')).toEqual(['a', 'b']);
    expect(splitList('')).toEqual([]);
  });
});

describe('toProgramInput — borne de la moyenne (revue #275, P2)', () => {
  // `matching.ts` calcule `(gpa - minGpaRequired + 2) / 4` sur une échelle /20.
  // Un seuil de 125 met TOUT candidat à zéro — et avec `isEstimate: false`,
  // donc l'app présenterait ce zéro comme une certitude, pas une estimation.
  it.each(['125', '20.5', '100'])('refuse une moyenne de %s', (raw) => {
    expect(() =>
      toProgramInput({ ...base, minGpaRequired: raw }, 'create'),
    ).toThrow(DraftError);
  });

  it.each(['20', '19.5', '0'])('accepte %s', (raw) => {
    expect(
      toProgramInput({ ...base, minGpaRequired: raw }, 'create').minGpaRequired,
    ).toBe(Number(raw));
  });

  // Le plancher de frais, lui, n'a pas de borne haute : une scolarité à
  // 60 000 €/an existe.
  it('ne borne PAS le plancher de frais', () => {
    expect(
      toProgramInput({ ...base, tuitionMinEur: '60000' }, 'create')
        .tuitionMinEur,
    ).toBe(60000);
  });
});

describe('toInstitutionInput — création vs édition (revue #275, P2)', () => {
  const filled = {
    ...EMPTY_INSTITUTION_DRAFT,
    nameFr: 'Université X',
    countryId: 'mar',
  };

  it('à la création, omet les champs vides', () => {
    const payload = toInstitutionInput(filled, 'create');
    expect('locationFr' in payload).toBe(false);
    expect('overviewFr' in payload).toBe(false);
    expect('studyLevels' in payload).toBe(false);
    expect('intakePeriods' in payload).toBe(false);
  });

  // Sans ça, ces champs étaient IMPOSSIBLES à effacer depuis l'éditeur, qui
  // acceptait pourtant la valeur vide sans rien signaler.
  it('à l’édition, vide réellement les champs effacés', () => {
    const payload = toInstitutionInput(filled, 'edit');
    expect(payload.locationFr).toBe('');
    expect(payload.overviewFr).toBe('');
    expect(payload.tuitionLabelFr).toBe('');
    expect(payload.languageRequirementsFr).toBe('');
    expect(payload.studyLevels).toEqual([]);
    expect(payload.intakePeriods).toEqual([]);
  });

  it('le mode par défaut reste la création', () => {
    expect('locationFr' in toInstitutionInput(filled)).toBe(false);
  });
});
