import { ORIENTATION_FIELDS } from '../../orientation/orientation-fields.data';
import {
  FIELD_FALLBACK_BY_DOMAIN,
  FIELD_KEYWORD_RULES,
  KNOWN_FIELD_IDS,
  PARCOURSUP_FAMILIES,
  normalizeCityName,
  normalizeLabel,
  procedureExceptionOf,
  refineParcoursupProcedure,
  refineParcoursupShape,
  resolveFieldId,
  resolveParcoursupShape,
  stableEefId,
} from './eef-catalog.normalize';

describe('normalizeLabel', () => {
  it('efface accents, casse, apostrophes et traits d’union', () => {
    expect(normalizeLabel("Réalisation d'applications")).toBe(
      'realisation d applications',
    );
    expect(normalizeLabel('Réalisation d’applications')).toBe(
      'realisation d applications',
    );
    expect(normalizeLabel('Génie civil - Construction durable')).toBe(
      'genie civil construction durable',
    );
  });

  // Régression : l'apostrophe non normalisée faisait rater 23 formations
  // d'informatique, classées nulle part et donc écartées du catalogue.
  it("classe « Réalisation d'applications » en informatique", () => {
    expect(resolveFieldId("BUT - Réalisation d'applications")?.fieldId).toBe(
      'd01',
    );
  });
});

describe('resolveFieldId', () => {
  it('classe par mot-clé sans marquer de repli', () => {
    expect(resolveFieldId('L1 - Droit')).toEqual({
      fieldId: 'd07',
      isFallback: false,
    });
    // La finance est dans « Commerce & Management », pas dans « Ingénierie ».
    expect(resolveFieldId('Master — Monnaie, banque, finance')).toEqual({
      fieldId: 'd02',
      isFallback: false,
    });
  });

  it('fait primer la santé sur l’informatique quand les deux mots sont là', () => {
    // L'ordre des règles EST le classement : d04 passe avant d01.
    expect(resolveFieldId('Informatique médicale')?.fieldId).toBe('d04');
  });

  it('replie sur le grand domaine, et le dit', () => {
    expect(resolveFieldId('Mention inconnue au dictionnaire', 'ARTS, LETTRES, LANGUES')).toEqual({
      fieldId: 'd09',
      isFallback: true,
    });
  });

  it('ne lit que le premier grand domaine quand la source en cumule', () => {
    expect(
      resolveFieldId('Zzz', 'DROIT, ECONOMIE, GESTION|SCIENCES HUMAINES ET SOCIALES')
        ?.fieldId,
    ).toBe('d02');
  });

  it('refuse de ranger ce que la source ne décrit pas', () => {
    // « DU - Diplôme d'Université » ne dit pas ce qu'on y étudie. Le ranger
    // quelque part serait inventer l'information.
    expect(resolveFieldId("DU - Diplôme d'Université")).toBeNull();
    expect(resolveFieldId('')).toBeNull();
  });

  it('ne produit que des domaines du référentiel d01..d12', () => {
    for (const rule of FIELD_KEYWORD_RULES) {
      expect(KNOWN_FIELD_IDS.has(rule.fieldId)).toBe(true);
    }
    for (const fieldId of Object.values(FIELD_FALLBACK_BY_DOMAIN)) {
      expect(KNOWN_FIELD_IDS.has(fieldId)).toBe(true);
    }
  });

  it('parle des domaines de l’orientation — les mêmes que ceux que l’étudiant déclare', () => {
    // Le référentiel est UNE liste : celle de l'orientation. Un domaine ajouté ou
    // retiré là-bas doit se répercuter ici sans qu'on recopie une seule liste.
    expect([...KNOWN_FIELD_IDS].sort()).toEqual(
      ORIENTATION_FIELDS.map((field) => field.id).sort(),
    );
  });

  it('atteint CHAQUE domaine de l’orientation : aucun ne reste sans formation', () => {
    const reachable = new Set(FIELD_KEYWORD_RULES.map((rule) => rule.fieldId));
    for (const field of ORIENTATION_FIELDS) {
      expect({ id: field.id, name: field.nameFr, reachable: reachable.has(field.id) })
        .toEqual({ id: field.id, name: field.nameFr, reachable: true });
    }
  });

  // L'ANCRAGE : ce test ne nomme aucun numéro. Il dit « une formation de finance
  // est dans Commerce & Management », puis va lire le nom que l'orientation donne
  // au domaine renvoyé. Une règle qui glisserait sur le mauvais numéro — c'est ce
  // qui s'était produit : dix domaines sur douze portaient le nom d'un autre —
  // ne peut plus passer.
  const nameOf = (label: string, domain?: string) => {
    const resolved = resolveFieldId(label, domain);
    if (!resolved) return null;
    return (
      ORIENTATION_FIELDS.find((field) => field.id === resolved.fieldId)?.nameFr
      ?? `inconnu:${resolved.fieldId}`
    );
  };

  it.each([
    ['Master Informatique', 'Informatique & Intelligence Artificielle'],
    ['Master Finance d’entreprise et de marché', 'Commerce & Management'],
    ['Master Marketing, vente', 'Commerce & Management'],
    ['Licence Gestion', 'Commerce & Management'],
    ['Génie mécanique', 'Ingénierie & Sciences'],
    ['L1 - Chimie', 'Ingénierie & Sciences'],
    ['L1 - Physique', 'Ingénierie & Sciences'],
    ['L1 - Sciences de la vie', 'Santé & Sciences de la Vie'],
    ['Biochimie, biologie moléculaire', 'Santé & Sciences de la Vie'],
    ['Master Santé', 'Santé & Sciences de la Vie'],
    ['Sciences du médicament et des produits de santé', 'Santé & Sciences de la Vie'],
    ['L2 STAPS : entraînement sportif', 'Santé & Sciences de la Vie'],
    ['BUT - Génie civil - Construction durable', 'Architecture & BTP'],
    ['Urbanisme et aménagement', 'Architecture & BTP'],
    ['Communication des organisations', 'Design, Médias & Communication'],
    ['BUT - Métiers du multimédia et de l’internet', 'Informatique & Intelligence Artificielle'],
    ['Cinéma et audiovisuel', 'Design, Médias & Communication'],
    ['Master Journalisme', 'Design, Médias & Communication'],
    ['L1 - Droit', 'Droit & Relations Internationales'],
    ['Droit du patrimoine', 'Droit & Relations Internationales'],
    ['Master Environnement et développement durable', 'Environnement & Agriculture'],
    ['Agronomie et agroalimentaire', 'Environnement & Agriculture'],
    ['Viticulture et oenologie', 'Environnement & Agriculture'],
    ['Master Histoire', 'Sciences Humaines & Éducation'],
    ['L1 - Psychologie', 'Sciences Humaines & Éducation'],
    ['L2 - Lettres', 'Sciences Humaines & Éducation'],
    ['L1 - Tourisme', 'Hôtellerie & Tourisme'],
    ['Hôtellerie et restauration', 'Hôtellerie & Tourisme'],
    ['L1 - Arts du spectacle', 'Arts & Culture'],
    ['Musicologie', 'Arts & Culture'],
    ['Patrimoine et musées', 'Arts & Culture'],
    ['Gestion de patrimoine', 'Commerce & Management'],
    ['Supply chain et logistique', 'Logistique & Supply Chain'],
    ['Transport, mobilités, réseaux', 'Logistique & Supply Chain'],
    ['Gestion de production, logistique, achats', 'Logistique & Supply Chain'],
  ])('« %s » est dans « %s »', (label, name) => {
    expect(nameOf(label)).toBe(name);
  });

  it('ne range pas en environnement ce qui contient « eau » dans un autre mot', () => {
    // « réseaux », « bureaux » : 43 formations de transport et de réseaux étaient
    // classées en environnement pour cette seule raison.
    expect(nameOf('BUT - Réseaux Opérateurs et Multimédia'))
      .toBe('Informatique & Intelligence Artificielle');
    expect(nameOf('BUT - Bureaux d’études Conception')).toBe('Ingénierie & Sciences');
    // … et « eau » comme mot entier reste de l'environnement.
    expect(nameOf('Sciences de l’eau')).toBe('Environnement & Agriculture');
    expect(nameOf('Gestion des eaux')).toBe('Environnement & Agriculture');
  });

  it('ne range pas en design « modélisation », mais garde « mode »', () => {
    expect(nameOf('BUT - Exploration et modélisation statistique')).toBe('Ingénierie & Sciences');
    expect(nameOf('Mode et création')).toBe('Design, Médias & Communication');
  });

  it('classe les repli par grand domaine sur les domaines de l’orientation', () => {
    expect(nameOf('Zzz', 'SCIENCES, TECHNOLOGIES, SANTE')).toBe('Ingénierie & Sciences');
    expect(nameOf('Zzz', 'SCIENCES DE LA SANTE')).toBe('Santé & Sciences de la Vie');
    expect(nameOf('Zzz', 'CULTURE ET COMMUNICATION')).toBe('Design, Médias & Communication');
  });

  it('n’a aucune règle vide, qui capterait tout', () => {
    for (const rule of FIELD_KEYWORD_RULES) {
      for (const keyword of rule.keywords) {
        expect(keyword.trim()).not.toBe('');
      }
    }
  });
});

describe('resolveParcoursupShape', () => {
  it('garde la sélectivité quand la ligne porte les deux familles', () => {
    // Une ligne « Licence sélective » + « Licence » doit rester sélective :
    // prendre la première famille au hasard effacerait la seule information
    // qui distingue les deux.
    const shape = resolveParcoursupShape(['Licence sélective', 'Licence']);
    expect(shape?.selectivity).toBe('selective');
    expect(shape?.cycle).toBe('licence1');
    const reversed = resolveParcoursupShape(['Licence', 'Licence sélective']);
    expect(reversed?.selectivity).toBe('selective');
  });

  it('fait primer la famille la plus spécifique sur « Licence »', () => {
    expect(resolveParcoursupShape(['Licence', 'BUT'])?.cycle).toBe('but1');
  });

  it('rejette une famille hors table plutôt que de deviner', () => {
    expect(resolveParcoursupShape(['CPGE'])).toBeNull();
    expect(resolveParcoursupShape([])).toBeNull();
  });

  it('met la 1re année de licence en DAP blanche et le BUT en procédure EEF', () => {
    expect(PARCOURSUP_FAMILIES.Licence.procedureType).toBe('dap_blanche');
    expect(PARCOURSUP_FAMILIES.BUT.procedureType).toBe('eef');
    expect(
      PARCOURSUP_FAMILIES["Formations d'architecture, du paysage et du patrimoine"]
        .procedureType,
    ).toBe('dap_jaune');
  });

  it('range PASS en 1re année de licence, donc en DAP blanche', () => {
    expect(PARCOURSUP_FAMILIES['Etudes de santé'].procedureType).toBe(
      'dap_blanche',
    );
  });
});

describe('normalizeCityName', () => {
  it('retire le bureau distributeur et rend la ville lisible', () => {
    expect(normalizeCityName('RENNES CEDEX 7')).toBe('Rennes');
    expect(normalizeCityName('PARIS CEDEX 05')).toBe('Paris');
    expect(normalizeCityName('SAINT-MARTIN-D HERES')).toBe("Saint-Martin-d Heres");
  });

  it('laisse intacte une ville déjà correctement capitalisée', () => {
    expect(normalizeCityName("Saint-Martin-d'Hères")).toBe("Saint-Martin-d'Hères");
    expect(normalizeCityName('Le Havre')).toBe('Le Havre');
  });

  it('garde les particules en minuscules sauf en tête', () => {
    expect(normalizeCityName('AULNOY-LEZ-VALENCIENNES')).toBe(
      'Aulnoy-lez-Valenciennes',
    );
    expect(normalizeCityName('LE MANS')).toBe('Le Mans');
  });

  it('rend une chaîne vide quand il ne reste rien', () => {
    expect(normalizeCityName('   ')).toBe('');
    expect(normalizeCityName('CEDEX 12')).toBe('');
  });
});

describe('refineParcoursupShape', () => {
  it('laisse une licence Sciences Po en première année', () => {
    const shape = resolveParcoursupShape([
      "Sciences Po - Instituts d'études politiques",
    ]);
    expect(shape).not.toBeNull();
    expect(
      refineParcoursupShape(
        shape!,
        "Sciences Po / Instituts d'études politiques - Grade Licence",
      ).cycle,
    ).toBe('licence1');
  });

  it('ne classe pas un grade de master en DAP', () => {
    const shape = resolveParcoursupShape([
      "Sciences Po - Instituts d'études politiques",
    ]);
    const refined = refineParcoursupShape(
      shape!,
      'Sciences Po / Instituts d’études politiques - Sciences Humaines et Sociales - Grade Master',
    );
    expect(refined.cycle).toBe('master');
    expect(refined.procedureType).toBe('eef');
    expect(refined.level).toBe('Master');
  });
});

describe('procedureExceptionOf — décisions du 02/10/2026', () => {
  const university = { uai: '0751717J' };
  const sciencesPo = { uai: '0753431X' };

  it('sort la 1re année de Sciences Po (Paris) de la DAP : voie propre à l’établissement', () => {
    expect(
      procedureExceptionOf({ cycle: 'licence1', nameFr: 'L1 - Histoire' }, sciencesPo),
    ).toEqual({ key: 'sciences_po_paris_l1', procedureType: 'hors_eef' });
    // Reconnue aussi quand l'UAI est une liste, ou en minuscules.
    expect(
      procedureExceptionOf({ cycle: 'licence1', nameFr: 'L1 - Lettres' }, { uai: '0000000A; 0753431x' })
        ?.procedureType,
    ).toBe('hors_eef');
  });

  it('ne touche ni un master de Sciences Po, ni un IEP de région', () => {
    expect(procedureExceptionOf({ cycle: 'master', nameFr: 'Master — Droit' }, sciencesPo)).toBeNull();
    expect(
      procedureExceptionOf({ cycle: 'licence1', nameFr: 'L1 - Histoire' }, { uai: '0330192E' }),
    ).toBeNull();
  });

  it('range le DCG sur Parcoursup et le CUPGE en Études en France', () => {
    expect(
      procedureExceptionOf(
        { cycle: 'licence1', nameFr: 'DCG - Diplôme de Comptabilité et de Gestion' },
        university,
      ),
    ).toEqual({ key: 'dcg', procedureType: 'parcoursup' });
    expect(
      procedureExceptionOf(
        { cycle: 'licence1', nameFr: 'CUPGE - Sciences et technologies' },
        university,
      ),
    ).toEqual({ key: 'cupge', procedureType: 'eef' });
    expect(
      procedureExceptionOf(
        {
          cycle: 'licence1',
          nameFr: 'Cycle Universitaire Préparatoire aux Grandes Écoles de commerce',
        },
        university,
      )?.key,
    ).toBe('cupge');
  });

  it('laisse une L1 ordinaire, une L2 ou un intitulé voisin en dehors des exceptions', () => {
    expect(procedureExceptionOf({ cycle: 'licence1', nameFr: 'L1 - Droit' }, university)).toBeNull();
    // « dcg » doit être un mot : pas « DCGX », ni une L2 de comptabilité.
    expect(procedureExceptionOf({ cycle: 'licence1', nameFr: 'DCGX - Autre' }, university)).toBeNull();
    expect(
      procedureExceptionOf({ cycle: 'licence2', nameFr: 'DCG - Diplôme de Comptabilité et de Gestion' }, university),
    ).toBeNull();
    expect(
      procedureExceptionOf({ cycle: 'sante', nameFr: 'L1 - Sciences de la vie' }, sciencesPo),
    ).toBeNull();
  });

  it('refineParcoursupProcedure ne change que la procédure', () => {
    const shape = resolveParcoursupShape(['Licence sélective', 'Licence'])!;
    const refined = refineParcoursupProcedure(shape, 'CUPGE - Informatique', university);
    expect(refined).toEqual({ ...shape, procedureType: 'eef' });
    expect(refineParcoursupProcedure(shape, 'L1 - Droit', university)).toBe(shape);
  });
});

describe('stableEefId', () => {
  it('ne dépend que de la clé métier', () => {
    expect(stableEefId('eef-prog-', 'a')).toBe(stableEefId('eef-prog-', 'a'));
    expect(stableEefId('eef-prog-', 'a')).not.toBe(stableEefId('eef-prog-', 'b'));
    expect(stableEefId('eef-prog-', 'a')).toMatch(/^eef-prog-[0-9a-f]{16}$/);
  });
});
