// Les signaux d'admission publiés : leur lecture, et leur rattrapage.
import {
  ANY_BACHELOR_LABEL,
  acceptsAnyBachelor,
  backfillEefAdmissionSignals,
  planAdmissionSignalsBackfill,
  recommendedFieldIdsOf,
  type AdmissionSignalsEntry,
  type AdmissionSignalsWriter,
} from './eef-admission-signals';
import { loadEefCatalog } from './eef-catalog.loader';
import type { EefCatalog } from './eef-catalog.types';

describe('recommendedFieldIdsOf', () => {
  it('classe les mentions publiées par mot-clé', () => {
    expect(recommendedFieldIdsOf(['Droit'])).toEqual(['d07']);
    expect(recommendedFieldIdsOf(['Economie et gestion'])).toEqual(['d02']);
  });

  it('dédoublonne et trie, pour être rejouable à l’identique', () => {
    // Un rattrapage rejoué doit produire le MÊME tableau, sinon il réécrit des
    // lignes identiques sans le savoir.
    const once = recommendedFieldIdsOf(['Gestion', 'Economie', 'Droit']);
    const twice = recommendedFieldIdsOf(['Droit', 'Economie', 'Gestion']);
    expect(once).toEqual(twice);
    expect(once).toEqual([...once].sort());
  });

  // Le repli par domaine de `resolveFieldId` sert à classer un INTITULÉ DE
  // DIPLÔME. L'employer ici rangerait n'importe quelle chaîne dans une case,
  // et une case remplie par défaut se lit comme une case attestée.
  it('laisse dehors une mention qu’aucun mot-clé ne reconnaît', () => {
    expect(recommendedFieldIdsOf(['Frontières du vivant'])).toEqual([]);
    expect(recommendedFieldIdsOf([ANY_BACHELOR_LABEL])).toEqual([]);
  });

  it('ne garde que ce qu’il sait lire dans une liste mixte', () => {
    expect(recommendedFieldIdsOf(['Droit', 'Frontières du vivant']))
      .toEqual(['d07']);
  });
});

describe('acceptsAnyBachelor', () => {
  // 302 masters publient ces deux mots. Les traiter comme une mention non
  // reconnue aurait jeté le seul cas où la porte est explicitement ouverte à
  // tout le monde — l'information la plus favorable du jeu.
  it('reconnaît « Toutes licences » à la casse et aux accents près', () => {
    expect(acceptsAnyBachelor(['Toutes licences'])).toBe(true);
    expect(acceptsAnyBachelor(['TOUTES LICENCES'])).toBe(true);
    expect(acceptsAnyBachelor(['Droit', 'Toutes licences'])).toBe(true);
  });

  it('ne le confond pas avec une mention nommée', () => {
    expect(acceptsAnyBachelor(['Droit'])).toBe(false);
    expect(acceptsAnyBachelor([])).toBe(false);
  });
});

function catalogWith(
  programs: Partial<{
    id: string;
    recommendedBachelors: string[];
    admissionModes: string[];
  }>[],
): EefCatalog {
  return {
    manifest: {} as never,
    universities: [
      {
        institution: {} as never,
        programs: programs.map((program, index) => ({
          id: program.id ?? `p-${index}`,
          recommendedBachelors: program.recommendedBachelors ?? [],
          admissionModes: program.admissionModes ?? [],
        })) as never,
      },
    ],
  };
}

describe('planAdmissionSignalsBackfill', () => {
  it('dérive l’index des domaines depuis les libellés publiés', () => {
    const [entry] = planAdmissionSignalsBackfill(
      catalogWith([
        { id: 'p-1', recommendedBachelors: ['Droit', 'Economie'] },
      ]),
    );
    expect(entry.recommendedBachelors).toEqual(['Droit', 'Economie']);
    expect(entry.recommendedFieldIds).toEqual(['d02', 'd07']);
  });

  // Les écrire reviendrait à remplacer un tableau vide par un tableau vide,
  // donc à compter comme « rattrapées » des lignes que rien ne distingue.
  it('omet les formations qui ne publient ni licence ni modalité', () => {
    const entries = planAdmissionSignalsBackfill(
      catalogWith([
        { id: 'vide' },
        { id: 'modalite', admissionModes: ['Dossier'] },
        { id: 'licence', recommendedBachelors: ['Droit'] },
      ]),
    );
    expect(entries.map((entry) => entry.id)).toEqual(['modalite', 'licence']);
  });
});

describe('backfillEefAdmissionSignals', () => {
  it('compte séparément ce qu’il a comblé et ce qu’il n’a pas touché', () => {
    const entries: AdmissionSignalsEntry[] = [
      { id: 'a', recommendedBachelors: ['Droit'], recommendedFieldIds: ['d07'], admissionModes: [] },
      { id: 'b', recommendedBachelors: ['Droit'], recommendedFieldIds: ['d07'], admissionModes: [] },
    ];
    const writer: AdmissionSignalsWriter = {
      fillIfEmpty: async (entry) => (entry.id === 'a' ? 1 : 0),
    };
    return backfillEefAdmissionSignals(entries, writer).then((summary) => {
      expect(summary).toEqual({ attempted: 2, filled: 1, untouched: 1 });
    });
  });
});

describe('contre le catalogue réel', () => {
  const catalog = loadEefCatalog();
  const entries = planAdmissionSignalsBackfill(catalog);

  it('a des signaux à écrire sur la quasi-totalité des masters', () => {
    const masters = catalog.universities.flatMap((file) =>
      file.programs.filter((program) => program.cycle === 'master'),
    );
    const withSignals = masters.filter(
      (program) =>
        program.recommendedBachelors.length > 0
        || program.admissionModes.length > 0,
    );
    // Si ce rapport s'effondre, la source a changé de forme et la shortlist
    // n'a plus d'axe de classement — mieux vaut le voir ici qu'à l'écran.
    expect(withSignals.length / masters.length).toBeGreaterThan(0.9);
  });

  // La contre-épreuve du défaut de collecte réparé avec cette fonctionnalité :
  // `for_lic_conseille` arrive tantôt en tableau, tantôt en UNE chaîne jointe
  // par des `|`. 501 entrées portaient une « mention » du genre
  // « Droit|Economie|Gestion » — un libellé que personne ne publie et
  // qu'aucun appariement ne reconnaît.
  it('ne porte plus aucune valeur jointe par des barres verticales', () => {
    const piped = entries.filter((entry) =>
      [...entry.recommendedBachelors, ...entry.admissionModes].some((value) =>
        value.includes('|'),
      ),
    );
    expect(piped).toEqual([]);
  });

  it('reconnaît la très grande majorité des mentions publiées', () => {
    let total = 0;
    let resolved = 0;
    for (const entry of entries) {
      for (const label of entry.recommendedBachelors) {
        total += 1;
        if (
          recommendedFieldIdsOf([label]).length > 0
          || acceptsAnyBachelor([label])
        ) {
          resolved += 1;
        }
      }
    }
    expect(total).toBeGreaterThan(10_000);
    // Mesuré à 100 % moins six occurrences (« Frontières du vivant »). Le seuil
    // est un cliquet : une source qui dériverait le ferait rougir.
    expect(resolved / total).toBeGreaterThan(0.99);
  });

  it('rend le même plan deux fois de suite', () => {
    expect(planAdmissionSignalsBackfill(catalog)).toEqual(entries);
  });
});
