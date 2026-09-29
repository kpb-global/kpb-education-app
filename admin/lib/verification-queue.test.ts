import { describe, expect, it } from 'vitest';

import type {
  VerificationDueResponse,
  VerificationQueueItem,
} from './catalog-api';
import {
  fromResponse,
  hasMoreOnServer,
  markValidated,
  queueKey,
} from './verification-queue';

function item(id: string, entityType: VerificationQueueItem['entityType'] = 'program'): VerificationQueueItem {
  return {
    entityType,
    id,
    label: id,
    context: null,
    category: 'program_scolarite',
    categoryLabel: 'Formations',
    cadenceDays: 180,
    owner: 'Fatou',
    lastVerifiedAt: null,
    verifiedByName: null,
    sourceUrl: null,
    dueAt: null,
    daysSinceVerification: null,
    isOverdue: true,
  };
}

const response = (
  overrides: Partial<VerificationDueResponse> & { items: VerificationQueueItem[] },
): VerificationDueResponse => ({ policies: [], total: overrides.items.length, ...overrides });

describe('fromResponse', () => {
  it('lit le compte complet et le drapeau du serveur', () => {
    const view = fromResponse(
      response({ items: [item('a'), item('b')], total: 9500, truncated: true }),
    );
    expect(view.total).toBe(9500);
    expect(view.truncated).toBe(true);
    expect(view.items).toHaveLength(2);
  });

  it('tolère un backend plus ancien : ni total ni truncated', () => {
    // L'admin et l'API se déploient séparément. Sans ces deux champs, « rien
    // n'est tronqué » et le compte est la longueur de la liste.
    const legacy = {
      items: [item('a'), item('b'), item('c')],
      policies: [],
    } as unknown as VerificationDueResponse;

    const view = fromResponse(legacy);

    expect(view.total).toBe(3);
    expect(view.truncated).toBe(false);
  });
});

describe('markValidated', () => {
  it('retire la ligne et baisse le compte complet', () => {
    const view = fromResponse(
      response({ items: [item('a'), item('b')], total: 9500, truncated: true }),
    );
    const after = markValidated(view, item('a'));
    expect(after.items.map((e) => e.id)).toEqual(['b']);
    expect(after.total).toBe(9499);
  });

  it('est IDEMPOTENT : une seconde réponse pour la même ligne ne baisse rien', () => {
    // Un double clic, ou un retour tardif, produit deux réponses pour la même
    // ligne. Le compte ne doit baisser qu'une fois.
    const view = fromResponse(
      response({ items: [item('a'), item('b')], total: 9500, truncated: true }),
    );

    const once = markValidated(view, item('a'));
    const twice = markValidated(once, item('a'));

    expect(twice.total).toBe(9499);
    expect(twice).toBe(once);
  });

  it('ne touche à rien pour une ligne qui n’est pas affichée', () => {
    const view = fromResponse(response({ items: [item('a')], total: 10, truncated: true }));
    expect(markValidated(view, item('inconnue'))).toBe(view);
  });

  it('distingue deux lignes de même identifiant mais de type différent', () => {
    // La clé est `type:identifiant` : une bourse et une formation peuvent partager
    // un identifiant sans que valider l'une retire l'autre.
    const view = fromResponse(
      response({
        items: [item('x', 'program'), item('x', 'scholarship')],
        total: 2,
      }),
    );
    const after = markValidated(view, item('x', 'scholarship'));
    expect(after.items.map(queueKey)).toEqual(['program:x']);
    expect(after.total).toBe(1);
  });
});

describe('hasMoreOnServer', () => {
  it('est faux pour une file complète, même une fois vidée', () => {
    let view = fromResponse(response({ items: [item('a')], total: 1 }));
    expect(hasMoreOnServer(view)).toBe(false);
    view = markValidated(view, item('a'));
    expect(view.items).toHaveLength(0);
    expect(hasMoreOnServer(view)).toBe(false);
  });

  it('reste vrai quand les lignes affichées sont toutes traitées mais que d’autres attendent', () => {
    // Le cas qui se contredisait : la page affichait « Aucune ligne à revoir »
    // sous une notice qui dit « 9 500 lignes attendent ».
    let view = fromResponse(
      response({ items: [item('a'), item('b')], total: 9502, truncated: true }),
    );
    view = markValidated(markValidated(view, item('a')), item('b'));

    expect(view.items).toHaveLength(0);
    expect(view.total).toBe(9500);
    expect(hasMoreOnServer(view)).toBe(true);
  });

  it('devient faux quand la dernière ligne du serveur est traitée', () => {
    let view = fromResponse(response({ items: [item('a')], total: 1, truncated: true }));
    view = markValidated(view, item('a'));
    expect(hasMoreOnServer(view)).toBe(false);
  });
});
