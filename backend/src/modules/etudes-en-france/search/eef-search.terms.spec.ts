import {
  EEF_DESIGNATION_ONLY_WORDS,
  EEF_HEALTH_ACCESS_WORDS,
  EEF_LEVEL_SYNONYMS,
  EEF_SEARCH_MAX_EXPANDED_TERMS,
  buildSearchTerms,
  institutionsMatchingTerm,
  resolveTermInstitutions,
} from './eef-search.terms';
import { EEF_CYCLES } from '../catalog/eef-catalog.types';
import { normalizeSearchText } from '../catalog/eef-search-text';

const inst = (
  id: string,
  nameFr: string,
  acronym: string | null = null,
  nameEn = nameFr,
) => ({ id, nameFr, nameEn, acronym });

const INSTITUTIONS = [
  inst('u-saclay', 'Université Paris-Saclay', 'UPSaclay'),
  inst('u-cite', 'Université Paris Cité', 'UPC'),
  inst('u-upec', 'Université Paris-Est Créteil Val de Marne', 'UPEC'),
  inst('u-sorbonne', 'Sorbonne Université', 'SU'),
  inst('ens-lyon', "École normale supérieure de Lyon", 'ENS Lyon'),
  inst('u-bordeaux', 'Université de Bordeaux', null),
];

const ids = (raw: string) =>
  institutionsMatchingTerm(buildSearchTerms([raw])[0], INSTITUTIONS);

describe('buildSearchTerms', () => {
  it('normalise, et garde le mot tel que tapé quand il est simple', () => {
    const [term] = buildSearchTerms(['Génie']);
    expect(term).toEqual({
      raw: 'Génie',
      norm: 'genie',
      cycles: [],
      healthAccess: false,
      matchesText: true,
    });
  });

  it('découpe un composé en ses mots, et retire les mots vides', () => {
    expect(buildSearchTerms(["l'économie"]).map((t) => t.norm)).toEqual(['economie']);
    expect(buildSearchTerms(['paris-saclay']).map((t) => t.norm)).toEqual([
      'paris',
      'saclay',
    ]);
    expect(buildSearchTerms(['licence', 'de', 'droit']).map((t) => t.norm)).toEqual([
      'licence',
      'droit',
    ]);
  });

  it('garde les mots vides quand il n’y a rien d’autre', () => {
    expect(buildSearchTerms(['de', 'la']).map((t) => t.norm)).toEqual(['de', 'la']);
  });

  it('dédoublonne et laisse tomber la ponctuation seule', () => {
    expect(buildSearchTerms(['droit', 'DROIT', '-', 'droit']).map((t) => t.norm)).toEqual([
      'droit',
    ]);
  });

  it('borne le nombre de mots après découpage', () => {
    const long = Array.from({ length: 30 }, (_, i) => `mot${i}`);
    expect(buildSearchTerms(long)).toHaveLength(EEF_SEARCH_MAX_EXPANDED_TERMS);
  });

  it('attache les cycles d’un mot de niveau', () => {
    expect(buildSearchTerms(['licence'])[0].cycles).toEqual([
      'licence1',
      'licence2',
      'licence3',
      'licence_pro',
    ]);
    expect(buildSearchTerms(['L2'])[0].cycles).toEqual(['licence2']);
    expect(buildSearchTerms(['Master'])[0].cycles).toEqual(['master']);
    expect(buildSearchTerms(['ingénieur'])[0].cycles).toEqual(['ingenieur']);
    expect(buildSearchTerms(['droit'])[0].cycles).toEqual([]);
  });
});

describe('les mots des études de santé', () => {
  const only = (word: string) => {
    const terms = buildSearchTerms([word]);
    expect(terms).toHaveLength(1);
    return terms[0];
  };

  it.each([
    'médecine', 'Médecine', 'MEDECINE', 'médecin', 'medicine', 'L.AS', 'LAS',
    'PACES', 'MMOPK', 'pharmacie', 'pharmacy', 'odontologie', 'dentaire',
    'dentiste', 'maïeutique', 'kiné', 'kinésithérapie',
  ])('« %s » désigne une 1re année d’accès santé — et pas tout le cycle', (word) => {
    const term = only(word);
    expect(term.healthAccess).toBe(true);
    // Le cycle `sante` entier mettrait les 61 diplômes paramédicaux en tête.
    expect(term.cycles).toEqual([]);
  });

  it.each(['santé', 'health'])('« %s » désigne toute la famille santé', (word) => {
    const term = only(word);
    expect(term.cycles).toEqual(['sante']);
    expect(term.healthAccess).toBe(false);
  });

  it('« PASS » se cherche par le texte : il est dans l’intitulé des PASS, pas des L.AS', () => {
    const term = only('PASS');
    expect(term).toMatchObject({ norm: 'pass', cycles: [], healthAccess: false, matchesText: true });
  });

  it('« las » n’est pas cherché dans le texte : il est dans « plastiques »', () => {
    expect(only('L.AS').matchesText).toBe(false);
    expect(only('las').matchesText).toBe(false);
    expect(only('médecine').matchesText).toBe(true);
  });

  it('un mot qui ne se cherche pas dans le texte désigne toujours quelque chose', () => {
    // Sinon sa clause serait `OR: []`, qui ne rend aucune ligne.
    for (const word of EEF_DESIGNATION_ONLY_WORDS) {
      const term = only(word);
      expect({ word, designates: term.healthAccess || term.cycles.length > 0 }).toEqual({
        word,
        designates: true,
      });
    }
  });

  it('les tables sont sur les clés normalisées, et ne se chevauchent pas', () => {
    for (const word of [...EEF_HEALTH_ACCESS_WORDS, ...EEF_DESIGNATION_ONLY_WORDS]) {
      expect(normalizeSearchText(word)).toBe(word);
    }
    for (const word of EEF_HEALTH_ACCESS_WORDS) {
      expect({ word, alsoALevel: word in EEF_LEVEL_SYNONYMS }).toEqual({ word, alsoALevel: false });
    }
  });

  it('« L.AS » et « L AS » sont recollés en un seul mot', () => {
    expect(buildSearchTerms(['L.AS']).map((term) => term.norm)).toEqual(['las']);
    expect(buildSearchTerms(['L', 'AS']).map((term) => term.norm)).toEqual(['las']);
    expect(buildSearchTerms(['L', 'AS', 'chimie']).map((term) => term.norm)).toEqual(['las', 'chimie']);
    // Un « l » qui n'est pas suivi de « as » reste un mot vide comme avant.
    expect(buildSearchTerms(['l', 'économie']).map((term) => term.norm)).toEqual(['economie']);
    expect(buildSearchTerms(['L AS']).map((term) => term.norm)).toEqual(['las']);
  });

  it('« sage-femme » ne désigne rien : « femme » seul viserait les études sur le genre', () => {
    const terms = buildSearchTerms(['sage-femme']);
    expect(terms.flatMap((term) => term.cycles)).toEqual([]);
    expect(terms.some((term) => term.healthAccess)).toBe(false);
  });

  it('« médical » n’est pas un synonyme : aucun intitulé ne le porte, et il ne dit pas « soin »', () => {
    expect(only('médical')).toMatchObject({ cycles: [], healthAccess: false });
  });
});

describe('EEF_LEVEL_SYNONYMS', () => {
  it('ne désigne que des cycles qui existent', () => {
    const known = new Set<string>(EEF_CYCLES);
    for (const [word, cycles] of Object.entries(EEF_LEVEL_SYNONYMS)) {
      for (const cycle of cycles) {
        expect({ word, cycle, known: known.has(cycle) }).toEqual({
          word,
          cycle,
          known: true,
        });
      }
    }
  });

  it('a ses clés sous forme normalisée — sinon le mot tapé ne les rencontre jamais', () => {
    for (const word of Object.keys(EEF_LEVEL_SYNONYMS)) {
      expect(word).toBe(word.toLowerCase());
      expect(word).toMatch(/^[a-z0-9]+$/);
    }
  });
});

describe('institutionsMatchingTerm', () => {
  it('retrouve un établissement par un mot de son nom', () => {
    expect(ids('sorbonne')).toEqual(['u-sorbonne']);
    expect(ids('saclay')).toEqual(['u-saclay']);
    expect(ids('creteil')).toEqual(['u-upec']);
    expect(ids('bordeaux')).toEqual(['u-bordeaux']);
  });

  it('un mot partagé désigne tous les établissements qui le portent', () => {
    expect(ids('paris').sort()).toEqual(['u-cite', 'u-saclay', 'u-upec'].sort());
  });

  it('retrouve un établissement par son sigle, entier', () => {
    expect(ids('upec')).toEqual(['u-upec']);
    expect(ids('UPEC')).toEqual(['u-upec']);
    expect(ids('su')).toEqual(['u-sorbonne']);
  });

  it('jamais par un morceau au milieu d’un mot', () => {
    // « ens » est dans « enseignement » mais n'est pas le début d'un mot du nom
    // des autres : seul le sigle « ENS Lyon » le porte.
    expect(ids('ens')).toEqual(['ens-lyon']);
    expect(ids('aclay')).toEqual([]);
    expect(ids('orbonne')).toEqual([]);
  });

  it('sous trois lettres, seul le sigle entier compte', () => {
    expect(ids('un')).toEqual([]);
    expect(ids('de')).toEqual([]);
    expect(ids('up')).toEqual([]);
  });

  it('un préfixe de sigle suffit à partir de trois lettres', () => {
    expect(ids('ups')).toEqual(['u-saclay']);
  });

  it('ignore accents et casse des deux côtés', () => {
    expect(ids('École')).toEqual(['ens-lyon']);
    expect(ids('ecole')).toEqual(['ens-lyon']);
  });

  it('tolère un sigle absent', () => {
    expect(ids('bordeaux')).toEqual(['u-bordeaux']);
  });
});

describe('resolveTermInstitutions', () => {
  it('n’a d’entrée que pour les mots qui désignent un établissement', () => {
    const resolved = resolveTermInstitutions(
      buildSearchTerms(['sorbonne', 'droit']),
      INSTITUTIONS,
    );
    expect([...resolved.keys()]).toEqual(['sorbonne']);
    expect(resolved.get('sorbonne')).toEqual(['u-sorbonne']);
  });

  it('rend une table vide quand rien ne correspond', () => {
    expect(resolveTermInstitutions(buildSearchTerms(['droit']), INSTITUTIONS).size).toBe(0);
    expect(resolveTermInstitutions(buildSearchTerms(['sorbonne']), []).size).toBe(0);
  });
});
