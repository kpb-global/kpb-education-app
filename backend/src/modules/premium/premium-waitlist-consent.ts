/**
 * Les versions de consentement que ce serveur SAIT restituer, et les langues
 * dans lesquelles il sait les produire.
 *
 * ## Pourquoi une liste fermée
 *
 * Sans elle, n'importe quel client authentifié pouvait envoyer
 * `consentVersion: "peu-importe"` : la valeur passait la validation et se
 * retrouvait en base comme prétendue preuve de consentement. Une version qui ne
 * correspond à aucun texte figé ne prouve rien — elle donne juste à une colonne
 * vide l'apparence d'être remplie, ce qui est pire, parce qu'on s'y fie.
 *
 * ## Le couplage que cela crée, et comment le tenir
 *
 * Ajouter `premium-waitlist-v2` demande DEUX gestes, dans cet ordre :
 *
 *   1. déployer le backend avec la nouvelle entrée ici ;
 *   2. puis seulement livrer l'app qui l'envoie.
 *
 * Dans l'autre ordre, l'app livrée envoie une version que le serveur refuse, et
 * plus personne ne peut s'inscrire. C'est le même couplage que le préflight de
 * release nomme `requires-new`, et il doit être déclaré comme tel.
 *
 * Le prix est assumé : il est toujours préférable de refuser une inscription
 * que d'en enregistrer une dont on ne saura jamais dire à quoi elle consentait.
 */
export const PREMIUM_WAITLIST_CONSENT_VERSIONS = [
  'premium-waitlist-v1',
] as const;

/**
 * Les langues dans lesquelles le texte de consentement existe.
 *
 * L'app n'expose aujourd'hui que le français (`kShippedLocale`), mais les deux
 * textes existent et le sélecteur de langue peut être rouvert. Enregistrer la
 * langue est ce qui permet, plus tard, de produire LA phrase lue — et non la
 * paire dont l'une des deux a été lue.
 */
export const PREMIUM_WAITLIST_CONSENT_LOCALES = ['fr', 'en'] as const;
