import * as fs from 'node:fs';
import * as path from 'node:path';

import {
  COUNTRY_BY_LABEL,
  FIELD_BY_LABEL,
  KNOWN_LEVELS,
  LANGUAGES_BY_LABEL,
  BACKFILLABLE,
  TARGETS,
  institutionBlankFills,
  normalizeLevel,
  parseCsv,
  parseTuitionMinEur,
  stableId,
} from './partner-import';

/**
 * The import script cannot be exercised end-to-end here (it needs the VPS
 * database), so its PURE half is pinned instead: CSV parsing, the closed
 * mapping tables, money parsing and id derivation. Those are where a silent
 * error would live — an unmapped filière writes an orphan row that surfaces
 * under no filter, and a mis-parsed amount writes a wrong budget score.
 */
const CSV = path.join(
  __dirname,
  '..',
  '..',
  '..',
  'scripts',
  'data',
  'universites-partenaires.csv',
);

describe('import-partner-universities — analyse du CSV livré', () => {
  const rows = parseCsv(fs.readFileSync(CSV, 'utf8'));

  // 520 et non 519 : le fichier ne se termine PAS par un saut de ligne, donc
  // `wc -l` en compte une de moins. Un analyseur qui jette la dernière ligne
  // non terminée perdrait un programme sans rien signaler.
  it('lit les 520 lignes et les 11 colonnes attendues', () => {
    expect(rows).toHaveLength(520);
    expect(Object.keys(rows[0]).sort()).toEqual(
      [
        'Cout', 'Cout Note', 'Description', 'Duree', 'Filiere', 'Institution',
        'Langue', 'Niveau', 'Pays', 'Programme', 'Ville',
      ].sort(),
    );
  });

  it('récupère la dernière ligne même sans saut de ligne final', () => {
    const parsed = parseCsv('a,b\n1,2\n3,4');
    expect(parsed).toEqual([
      { a: '1', b: '2' },
      { a: '3', b: '4' },
    ]);
  });

  it('ignore les lignes entièrement vides sans décaler les colonnes', () => {
    expect(parseCsv('a,b\n1,2\n\n3,4')).toHaveLength(2);
  });

  it('gère un saut de ligne à l’intérieur d’un champ protégé', () => {
    const parsed = parseCsv('a,b\n"ligne\nsuite",2');
    expect(parsed).toHaveLength(1);
    expect(parsed[0].a).toBe('ligne\nsuite');
  });

  it("retire le BOM du premier en-tête (sinon 'Institution' serait introuvable)", () => {
    expect(rows[0].Institution).toBe('ECE — Rentrée décalée 2027');
  });

  it('préserve les virgules internes protégées par des guillemets', () => {
    // La colonne « Cout Note » contient « …, Paris (Initiale) — Démarrage… ».
    expect(rows[0]['Cout Note']).toContain('Rentrée décalée 2027, Paris');
  });

  it('couvre tous les pays et filières du fichier (tables fermées)', () => {
    const pays = new Set(rows.map((r) => r.Pays));
    const filieres = new Set(rows.map((r) => r.Filiere));
    expect([...pays].filter((p) => !(p in COUNTRY_BY_LABEL))).toEqual([]);
    expect([...filieres].filter((f) => !(f in FIELD_BY_LABEL))).toEqual([]);
  });

  it('couvre toutes les langues du fichier', () => {
    const langues = new Set(rows.map((r) => r.Langue));
    expect([...langues].filter((l) => !(l in LANGUAGES_BY_LABEL))).toEqual([]);
  });

  it('les 3 cibles retenues totalisent 74 lignes', () => {
    const names = new Set(TARGETS.map((t) => t.csvName));
    expect(rows.filter((r) => names.has(r.Institution))).toHaveLength(74);
  });

  it('chaque cible est présente dans le CSV sous son nom exact', () => {
    for (const t of TARGETS) {
      expect(rows.some((r) => r.Institution === t.csvName)).toBe(true);
    }
  });

  it("n'embarque aucune école OMNES déjà en production", () => {
    const names = new Set(TARGETS.map((t) => t.csvName));
    const omnes = rows.filter(
      (r) => names.has(r.Institution) && /INSEEC|ECE|ESCE|Sup de Pub|HEIP/.test(r.Institution),
    );
    expect(omnes).toEqual([]);
  });
});

describe('TARGETS — les décisions de périmètre, épinglées', () => {
  const rows = parseCsv(fs.readFileSync(CSV, 'utf8'));

  it('les identifiants sont uniques et suivent la convention partner-', () => {
    const ids = TARGETS.map((t) => t.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const id of ids) expect(id).toMatch(/^partner-[a-z0-9-]+$/);
  });

  // Décision produit : Schiller Tampa est un ÉTABLISSEMENT distinct de Schiller
  // Europe, pas un campus de celui-ci. Un campus ne porte pas de pays ; un
  // étudiant qui filtre sur « USA » ne trouverait donc jamais Tampa s'il était
  // rattaché à la fiche européenne (esp).
  it('Schiller Tampa et Schiller Europe sont deux établissements séparés', () => {
    const tampa = TARGETS.find((t) => t.id === 'partner-schiller-tampa');
    const europe = TARGETS.find((t) => t.id === 'partner-schiller-europe');
    expect(tampa).toBeDefined();
    expect(europe).toBeDefined();
    expect(tampa!.id).not.toBe(europe!.id);
    expect(tampa!.countryId).toBe('usa');
    expect(europe!.countryId).toBe('esp');
  });

  it('Mundiapolis est rattaché au Maroc', () => {
    expect(
      TARGETS.find((t) => t.id === 'partner-mundiapolis')!.countryId,
    ).toBe('mar');
  });

  // Aucune cible ne doit diverger du pays annoncé par le CSV sans que ce soit
  // délibéré : une divergence silencieuse écrirait une fiche introuvable sous
  // le filtre pays, `Institution.countryId` n'étant pas une clé étrangère.
  it('le pays écrit correspond à celui du CSV pour chaque cible', () => {
    for (const t of TARGETS) {
      const row = rows.find((r) => r.Institution === t.csvName);
      expect(row).toBeDefined();
      expect(COUNTRY_BY_LABEL[row!.Pays]).toBe(t.countryId);
    }
  });

  it('les pays visés existent tous dans la table fermée', () => {
    const known = new Set(Object.values(COUNTRY_BY_LABEL));
    for (const t of TARGETS) expect(known.has(t.countryId)).toBe(true);
  });

  // Schiller Europe couvre Madrid, Paris et Heidelberg : c'est le cas
  // `campusOfferings`. Tampa n'a qu'un campus et doit rester sans.
  it('seules les cibles multi-campus déclarent plusieurs campus', () => {
    expect(
      TARGETS.find((t) => t.id === 'partner-schiller-europe')!.campuses.length,
    ).toBeGreaterThan(1);
    expect(
      TARGETS.find((t) => t.id === 'partner-schiller-tampa')!.campuses,
    ).toHaveLength(1);
  });

  it('Universiapolis reste hors périmètre (années d’étude, pas des diplômes)', () => {
    expect(TARGETS.some((t) => /Universiapolis/.test(t.csvName))).toBe(false);
  });
});

describe('normalizeLevel', () => {
  it.each([
    ['Licence', 'Bachelor'],
    ['Licence professionnelle', 'Bachelor'],
    ['Bachelor', 'Bachelor'],
    ['Master', 'Master'],
    ['MSc', 'Master'],
    ['MBA', 'MBA / DBA'],
    ['Doctorat', 'Doctorat'],
    // Cas français que le référentiel du service ne couvre pas : un diplôme
    // d'ingénieur est un Bac+5, donc de niveau Master.
    ['Ingénieur', 'Master'],
  ])('normalise %s en %s', (raw, expected) => {
    expect(normalizeLevel(raw)).toBe(expected);
  });

  it.each(['Prépa', 'Spécialité', '1re année'])(
    'laisse %s tel quel — et ce niveau est hors référentiel',
    (raw) => {
      const out = normalizeLevel(raw);
      expect(out).toBe(raw);
      expect(KNOWN_LEVELS.has(out)).toBe(false);
    },
  );
});

describe('parseTuitionMinEur', () => {
  it('prend la borne basse d’une fourchette en euros', () => {
    expect(parseTuitionMinEur('6 690 € – 7 025 €/an')).toBe(6690);
  });

  it('gère les espaces insécables et fines des montants français', () => {
    expect(parseTuitionMinEur('8 850 €/an')).toBe(8850);
    expect(parseTuitionMinEur('15 420 €/an')).toBe(15420);
  });

  it.each([
    ['17 610 USD/an', 'dollars'],
    ['57 900 DH/an', 'dirhams'],
    ['À confirmer', 'montant inconnu'],
    ['', 'vide'],
  ])('renvoie null pour %s (%s)', (raw) => {
    // Convertir ici figerait un taux de change périmé dès le lendemain ;
    // `tuitionFr` conserve de toute façon le libellé d'origine.
    expect(parseTuitionMinEur(raw)).toBeNull();
  });
});

describe('stableId', () => {
  it('est déterministe — relancer l’import ne crée pas de doublon', () => {
    const a = stableId('partner-p-', 'partner-mundiapolis|Licence Gestion');
    const b = stableId('partner-p-', 'partner-mundiapolis|Licence Gestion');
    expect(a).toBe(b);
    expect(a).toMatch(/^partner-p-[0-9a-f]{16}$/);
  });

  it('sépare deux programmes homonymes de deux établissements', () => {
    expect(stableId('partner-p-', 'a|Master Finance')).not.toBe(
      stableId('partner-p-', 'b|Master Finance'),
    );
  });
});

/**
 * Comblement des colonnes vides d'un établissement déjà en base.
 *
 * L'écriture est un `upsert` à partie `update` vide, pour ne jamais écraser une
 * fiche retouchée à la main. Conséquence vécue : Mundiapolis a été créé avant
 * que la colonne Description du CSV ne soit lue, et son `overview` serait resté
 * vide indéfiniment. Ces tests fixent la frontière — combler un trou, oui ;
 * remplacer une valeur existante, jamais.
 */
describe('institutionBlankFills', () => {
  const incoming = {
    overviewFr: 'Université privée reconnue par l’État.',
    overviewEn: 'State-recognised private university.',
    locationFr: 'Casablanca · Nouaceur',
    locationEn: 'Casablanca · Nouaceur',
  };

  it('comble une colonne vide', () => {
    expect(institutionBlankFills({ overviewFr: '' }, incoming).overviewFr).toBe(
      incoming.overviewFr,
    );
  });

  it('comble une colonne absente (null en base)', () => {
    expect(
      institutionBlankFills({ overviewFr: null }, incoming).overviewFr,
    ).toBe(incoming.overviewFr);
  });

  // Revue #272 (P2) : « vide » doit être ce que la BASE sait vérifier dans un
  // `WHERE col = ''`, seule forme atomique. Une colonne d'espaces n'est donc
  // PAS comblée — c'est le choix conservateur, et il est volontaire.
  it("ne comble PAS une colonne d'espaces", () => {
    expect(
      institutionBlankFills({ overviewFr: '   ' }, incoming).overviewFr,
    ).toBeUndefined();
  });

  // Le cas Schiller : sa description est DÉJÀ en base, identique à celle du
  // CSV. Rien ne doit être réécrit, même à valeur égale — une écriture inutile
  // ferait bouger `updatedAt` et brouillerait la file de vérification.
  it('ne touche pas une colonne déjà remplie', () => {
    const fills = institutionBlankFills(
      { overviewFr: 'Texte écrit à la main' },
      incoming,
    );
    expect(fills.overviewFr).toBeUndefined();
  });

  it("n'écrit rien quand la source est vide", () => {
    expect(
      institutionBlankFills({ overviewFr: '' }, { overviewFr: '' }),
    ).toEqual({});
  });

  it('ne renvoie que des colonnes de la liste autorisée', () => {
    const fills = institutionBlankFills(
      { overviewFr: '', locationFr: '' },
      { ...incoming, isPartner: 'oui' } as never,
    );
    for (const k of Object.keys(fills)) {
      expect(BACKFILLABLE).toContain(k);
    }
    expect(Object.keys(fills)).not.toContain('isPartner');
  });

  it('comble plusieurs colonnes en une passe', () => {
    expect(
      institutionBlankFills(
        { overviewFr: '', overviewEn: '', locationFr: 'déjà là', locationEn: '' },
        incoming,
      ),
    ).toEqual({
      overviewFr: incoming.overviewFr,
      overviewEn: incoming.overviewEn,
      locationEn: incoming.locationEn,
    });
  });

  it('un objet existant vide déclenche tous les comblements', () => {
    expect(institutionBlankFills({}, incoming)).toEqual(incoming);
  });
});

describe('Description du CSV', () => {
  const rows = parseCsv(fs.readFileSync(CSV, 'utf8'));

  it('chaque cible a exactement une description, non vide', () => {
    for (const t of TARGETS) {
      const descs = new Set(
        rows
          .filter((r) => r.Institution === t.csvName)
          .map((r) => r.Description.trim()),
      );
      expect(descs.size).toBe(1);
      expect([...descs][0].length).toBeGreaterThan(20);
    }
  });
});

/**
 * L'atomicité du comblement ne se teste pas sur la fonction pure : elle tient à
 * la FORME de l'écriture. `fills` est calculé pendant la lecture du plan, et un
 * `update` inconditionnel écraserait le texte d'un administrateur qui aurait
 * rempli la colonne entre-temps (revue de #272). La garantie doit donc être
 * portée par un `WHERE col = ''` réévalué par la base à l'instant de l'écriture.
 *
 * Ce test lit le script parce que c'est le seul endroit où cette forme existe,
 * et qu'une réécriture « simplificatrice » vers `update: fills` reviendrait au
 * défaut sans qu'aucun test unitaire ne bronche.
 */
describe('le comblement est atomique, pas seulement rapproché', () => {
  const SCRIPT = path.join(
    __dirname,
    '..',
    '..',
    '..',
    'scripts',
    'import-partner-universities.ts',
  );
  const src = fs.readFileSync(SCRIPT, 'utf8');

  it("l'upsert de l'établissement ne porte AUCUN comblement", () => {
    expect(src).not.toMatch(/update:\s*fills/);
    expect(src).toMatch(/upsert\(\{[\s\S]{0,400}?update:\s*\{\}/);
  });

  it('le comblement passe par updateMany avec une condition de vide', () => {
    expect(src).toMatch(/institution\.updateMany/);
    expect(src).toMatch(/where:\s*\{\s*id:\s*target\.id,\s*\[key\]:\s*''/);
  });

  it("signale quand une colonne a été remplie entre-temps plutôt que d'écraser", () => {
    expect(src).toMatch(/rempli entre-temps/);
  });
});
