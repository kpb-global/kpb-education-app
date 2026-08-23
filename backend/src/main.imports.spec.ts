import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Un import par défaut d'un module CommonJS pur EMPÊCHE l'API de démarrer.
 *
 * ## Le défaut, mesuré
 *
 * `tsconfig.json` pose `allowSyntheticDefaultImports: true` mais PAS
 * `esModuleInterop`. Cette combinaison est un mensonge de type : TypeScript
 * accepte `import compression from 'compression'` à la compilation, mais
 * n'émet aucun helper d'interop. Le JS produit appelle
 * `(0, compression_1.default)()`, et `compression` est un module CommonJS pur
 * dont `.default` vaut `undefined`.
 *
 * Résultat observé sur la CI du lot 11 :
 *
 *     Fatal: application failed to start
 *     TypeError: (0 , compression_1.default) is not a function
 *
 * L'API ne démarrait plus DU TOUT — une panne totale en production. Or
 * `tsc --noEmit` passait, le build passait, et les 400+ tests jest passaient :
 * seul le boot smoke de la CI l'a vu, après quatre minutes.
 *
 * ## Pourquoi cette garde lit main.ts au lieu d'importer les modules
 *
 * Un spec qui écrirait lui-même `import * as compression from 'compression'`
 * et vérifierait que c'est appelable ne prouverait RIEN sur main.ts : il
 * testerait son propre import. C'est le motif de faux garde-fou que ce dépôt
 * connaît déjà par cœur. Cette garde lit donc le VRAI fichier, extrait ses
 * imports par défaut, et reproduit exactement la règle d'exécution du code
 * émis : « le runtime ira chercher `.default` ».
 *
 * `helmet` passe parce que helmet v7 pose lui-même `module.exports.default` —
 * une politesse de ce paquet, pas une règle générale. C'est précisément
 * pourquoi on ne peut pas se fier à « ça marche pour helmet ».
 */
describe('main.ts — les imports doivent survivre à l’exécution, pas seulement à tsc', () => {
  const source = readFileSync(join(__dirname, 'main.ts'), 'utf8');

  /** `import X from 'pkg'` — la forme qui ira chercher `.default` à l’exécution. */
  const defaultImports = [...source.matchAll(/^import\s+(\w+)\s+from\s+'([^']+)';/gm)]
    .map(([, binding, moduleName]) => ({ binding, moduleName }))
    // Les imports relatifs sont notre propre code (transpilé par le même tsc,
    // donc porteur d'un vrai `.default`) ; `node:*` est natif.
    .filter(
      ({ moduleName }) =>
        !moduleName.startsWith('.') && !moduleName.startsWith('node:'),
    );

  it('trouve bien des imports par défaut à vérifier (garde non morte)', () => {
    expect(defaultImports.length).toBeGreaterThan(0);
  });

  it.each(defaultImports.map(({ binding, moduleName }) => [binding, moduleName]))(
    'le module `%s` (%s) expose un `.default` appelable',
    (binding, moduleName) => {
      const loaded = require(moduleName);
      expect(loaded).toBeDefined();
      expect(typeof loaded.default).not.toBe('undefined');
    },
  );

  it('`compression` reste importé en `import * as` — il n’a pas de `.default`', () => {
    // Assertion nommée, parce que c'est CE paquet qui a cassé le démarrage et
    // que la règle générale ci-dessus ne le dirait pas aussi clairement.
    expect(typeof require('compression').default).toBe('undefined');
    expect(source).toContain("import * as compression from 'compression';");
    expect(source).not.toContain("import compression from 'compression';");
  });
});
