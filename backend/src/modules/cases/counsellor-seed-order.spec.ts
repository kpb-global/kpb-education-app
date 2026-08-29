import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * L'ordre annoncé par la seed doit être PORTÉ PAR LES DONNÉES.
 *
 * L'incident : la première ligne du fichier annonce « Jojo -> Donald ->
 * Richard », mais les trois lignes étaient insérées avec `now()`, qui rend
 * l'horodatage de la TRANSACTION — donc trois `createdAt` identiques à la
 * milliseconde. Le round-robin trie sur `createdAt`, départage sur `id` : la
 * rotation réelle aurait été Donald -> Jojo -> Richard, alphabétique et
 * contraire à l'intention écrite.
 *
 * Ce test lit le fichier de seed et refuse que l'intention reste dans un
 * commentaire. Il tient debout sans base de données : c'est le contenu du
 * fichier qui est en cause, pas le moteur.
 */
const SEED = readFileSync(
  join(__dirname, '../../../scripts/seed-kpb-counsellors.sql'),
  'utf-8',
);

/** (id, prénom, horodatage) de chaque ligne, dans l'ordre du fichier. */
function seededRows() {
  const rows = [
    ...SEED.matchAll(
      /\(\s*'(counsellor-[a-z]+)',\s*'([^']+)',[\s\S]*?TIMESTAMP '([^']+)'/g,
    ),
  ];
  return rows.map((m) => ({
    id: m[1],
    name: m[2],
    createdAt: new Date(`${m[3]}Z`),
  }));
}

/** L'ordre écrit en toutes lettres sur la première ligne du fichier. */
function declaredOrder() {
  const header = SEED.split('\n')[0];
  const match = header.match(/\(([^)]*->[^)]*)\)/);
  expect(match).not.toBeNull();
  return match![1].split('->').map((n) => n.trim());
}

describe('Seed des conseillers — la rotation annoncée est dans les données', () => {
  it('chaque ligne porte un horodatage explicite, jamais now()', () => {
    const rows = seededRows();
    expect(rows).toHaveLength(3);
    for (const row of rows) {
      expect(Number.isNaN(row.createdAt.getTime())).toBe(false);
    }
    // `now()` rend l'horodatage de la transaction : trois lignes, une seule
    // valeur. C'est exactement le défaut qu'on interdit ici.
    const distinct = new Set(rows.map((r) => r.createdAt.getTime()));
    expect(distinct.size).toBe(3);
  });

  it("l'ordre par createdAt est celui annoncé en tête de fichier", () => {
    const byCreatedAt = [...seededRows()]
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
      .map((r) => r.name);
    expect(byCreatedAt).toEqual(declaredOrder());
  });

  it("l'ordre alphabétique des id ne suffit PAS — d'où l'horodatage", () => {
    // La contre-épreuve. Si un jour trier par `id` donnait le bon ordre, ce
    // test deviendrait complaisant : il passerait sans que les horodatages
    // portent quoi que ce soit. Tant qu'il échoue, l'horodatage est porteur.
    const byId = [...seededRows()]
      .sort((a, b) => a.id.localeCompare(b.id))
      .map((r) => r.name);
    expect(byId).not.toEqual(declaredOrder());
  });
});
