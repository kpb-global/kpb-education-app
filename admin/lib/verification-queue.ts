import type {
  VerificationDueResponse,
  VerificationQueueItem,
} from './catalog-api';

/**
 * L'état de la file de revérification affichée par `/verification`.
 *
 * Ces fonctions sont pures pour une raison : l'admin n'a aucune infrastructure de
 * test de composants (pas de jsdom), et la logique du décompte — celle qui se
 * trompe sans que personne ne le voie — doit pourtant être vérifiée.
 */
export interface QueueView {
  /** Les lignes affichées : au plus le plafond du serveur. */
  readonly items: readonly VerificationQueueItem[];
  /** Le compte COMPLET de la file, mis à jour à mesure que des lignes sortent. */
  readonly total: number;
  /** Le serveur a-t-il plafonné sa réponse ? */
  readonly truncated: boolean;
}

export const EMPTY_QUEUE: QueueView = { items: [], total: 0, truncated: false };

export function queueKey(
  item: Pick<VerificationQueueItem, 'entityType' | 'id'>,
): string {
  return `${item.entityType}:${item.id}`;
}

/**
 * La réponse du serveur, lue avec la tolérance d'un admin déployé séparément.
 *
 * `total` et `truncated` sont additifs : un backend plus ancien ne les envoie pas,
 * et l'absence veut alors dire « rien n'est tronqué, et le compte est la longueur
 * de la liste ».
 */
export function fromResponse(response: VerificationDueResponse): QueueView {
  return {
    items: response.items,
    total: response.total ?? response.items.length,
    truncated: response.truncated === true,
  };
}

/**
 * Une ligne validée sort de la file — et le compte complet baisse avec elle.
 *
 * IDEMPOTENT, et c'est ce qui compte : le compte ne baisse que si la ligne était
 * ENCORE là. Deux réponses pour la même ligne (un double clic, un retour tardif)
 * ne le décrémentent qu'une fois. Un décrément inconditionnel dérivait de un à
 * chaque doublon, et rien à l'écran ne le disait.
 */
export function markValidated(
  view: QueueView,
  item: Pick<VerificationQueueItem, 'entityType' | 'id'>,
): QueueView {
  const key = queueKey(item);
  if (!view.items.some((entry) => queueKey(entry) === key)) return view;
  return {
    ...view,
    items: view.items.filter((entry) => queueKey(entry) !== key),
    total: Math.max(0, view.total - 1),
  };
}

/**
 * Reste-t-il des lignes que le serveur n'a pas envoyées ?
 *
 * Distingue les deux façons d'avoir une liste vide : « tout est traité » et « les
 * lignes affichées sont traitées, et d'autres attendent ». Afficher « Aucune
 * ligne à revoir » dans le second cas dit le contraire de la notice au-dessus.
 */
export function hasMoreOnServer(view: QueueView): boolean {
  return view.truncated && view.total > view.items.length;
}
