// La copie figée de la prose 1.2.0 est-elle FIDÈLE ?
//
// `eef:reconcile` ne réaligne une formation publiée que si sa prose en base est
// exactement celle qu'un import a écrite. Pour le catalogue publié le 01/10/2026,
// c'est l'édition 1.2.0 de `eef-catalog.copy.ts`. Si la copie figée s'en écartait
// d'un caractère, chaque ligne paraîtrait « retouchée dans l'admin » et rien ne
// serait corrigé — ou, pire, une vraie retouche paraîtrait machine.
//
// L'empreinte ci-dessous a été mesurée le 02/10/2026 sur le code d'ORIGINE
// (`eef-catalog.copy.ts` au commit 47a1295, avant correction), sur les 10 502
// formations versionnées, avec la procédure qu'elles portaient alors. Le test
// recalcule la même empreinte avec la copie figée.
import { createHash } from 'node:crypto';

import { programRequirements1_2 } from './eef-catalog.copy-1.2';
import { loadEefCatalog } from './eef-catalog.loader';
import { procedureExceptionOf } from './eef-catalog.normalize';

const EDITION_1_2_DIGEST =
  '15c16b3f7b62758b5401a7117f8ab8dfcf55e8b434df1433865eb083af89daf2';

describe('prose figée de l’édition 1.2.0', () => {
  it('reproduit à l’octet près ce que l’import 1.2.0 écrivait', () => {
    const programs = loadEefCatalog()
      .universities.flatMap((file) =>
        file.programs.map((program) => {
          // Les 57 formations corrigées le 02/10 étaient toutes en DAP blanche :
          // c'est cette procédure-là que porte leur prose 1.2.0 en base.
          const corrected = procedureExceptionOf(program, file.institution) !== null;
          return corrected ? { ...program, procedureType: 'dap_blanche' as const } : program;
        }),
      )
      .sort((a, b) => (a.id < b.id ? -1 : 1));
    expect(programs).toHaveLength(10502);

    const hash = createHash('sha256');
    for (const program of programs) {
      const lines = programRequirements1_2(program);
      hash.update(
        `${program.id}\t${JSON.stringify(lines.map((line) => line.fr))}\t`
          + `${JSON.stringify(lines.map((line) => line.en))}\n`,
      );
    }
    expect(hash.digest('hex')).toBe(EDITION_1_2_DIGEST);
  });
});
