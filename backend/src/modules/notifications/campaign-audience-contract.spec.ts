import { readFileSync } from 'fs';
import { join } from 'path';

/**
 * Le DTO et l'exécuteur doivent connaître les MÊMES audiences.
 *
 * Ils divergeaient dans les deux sens, et chaque sens échoue différemment :
 * une audience implémentée mais absente du DTO rend 400 (`account_type`,
 * `study_level`, `country_of_residence` étaient dans ce cas) ; une audience
 * acceptée par le DTO sans branche dans l'exécuteur tombe dans le `default`
 * et produit 0 destinataire — une campagne qui « réussit » sans destinataire.
 *
 * On lit les deux fichiers plutôt que d'importer une constante partagée :
 * introduire cette constante serait le vrai correctif, mais le test doit
 * pouvoir échouer AUSSI quand quelqu'un cesse de l'utiliser.
 */
function read(relative: string): string {
  return readFileSync(join(__dirname, relative), 'utf8');
}

function dtoAudiences(): Set<string> {
  const source = read('dto/create-notification-campaign.dto.ts');
  const block = /@IsIn\(\[([\s\S]*?)\]\)\s*audienceType/.exec(source);
  expect(block).not.toBeNull();
  return new Set(
    Array.from(block![1].matchAll(/'([a-z_]+)'/g)).map((m) => m[1]),
  );
}

function executorAudiences(): Set<string> {
  const source = read('campaign-executor.service.ts');
  const start = source.indexOf('private async resolveRecipients');
  expect(start).toBeGreaterThan(-1);
  const body = source.slice(start);
  const end = body.indexOf('\n  }\n');
  return new Set(
    Array.from(body.slice(0, end).matchAll(/case '([a-z_]+)':/g)).map(
      (m) => m[1],
    ),
  );
}

describe('Le DTO de campagne et l’exécuteur parlent des mêmes audiences', () => {
  it('aucune audience implémentée n’est refusée par le DTO', () => {
    const missing = [...executorAudiences()].filter(
      (a) => !dtoAudiences().has(a),
    );
    expect(missing).toEqual([]);
  });

  it('aucune audience acceptée par le DTO n’est sans destinataires', () => {
    const orphans = [...dtoAudiences()].filter(
      (a) => !executorAudiences().has(a),
    );
    expect(orphans).toEqual([]);
  });

  it('les deux listes sont non vides (le test lit bien quelque chose)', () => {
    expect(dtoAudiences().size).toBeGreaterThan(4);
    expect(executorAudiences().size).toBeGreaterThan(4);
  });
});
