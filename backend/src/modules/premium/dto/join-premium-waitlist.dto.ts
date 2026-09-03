import { Transform } from 'class-transformer';
import {
  Equals,
  IsBoolean,
  IsIn,
  IsNotEmpty,
  IsString,
  MaxLength,
} from 'class-validator';

import {
  PREMIUM_WAITLIST_CONSENT_LOCALES,
  PREMIUM_WAITLIST_CONSENT_VERSIONS,
} from '../premium-waitlist-consent';

/**
 * Une inscription à la liste d'attente Karatou Premium.
 *
 * Deux champs, et rien d'autre. C'est délibéré : le seul signal qu'on cherche à
 * mesurer est « combien d'étudiants veulent le Pass », et il s'obtient en un
 * tap. Demander le niveau, la filière ou le budget aurait transformé ce signal
 * en formulaire, et on aurait mesuré la patience plutôt que l'intérêt — le même
 * raisonnement que `DeclareEefInterestDto`, qui rend tout optionnel sauf le
 * consentement.
 *
 * Il n'y a AUCUN champ de prix, de moyen de paiement ni d'engagement. Karatou
 * n'encaisse rien dans l'application ; s'inscrire ici ne coûte rien et n'engage
 * à rien.
 */
export class JoinPremiumWaitlistDto {
  /**
   * Le consentement, EXIGÉ et devant valoir exactement `true`.
   *
   * Sans ce champ, `consentedAt` ne serait qu'un `now()` déplacé de Postgres
   * vers Node : un POST au corps vide — un script, un rejeu de requête, un
   * retry automatique — produirait une ligne portant une preuve de
   * consentement que rien ne distinguerait d'un tap volontaire. L'horodatage
   * serveur démontre « non antidatable » ; ce champ ajoute la seule propriété
   * qui manquait, « l'acte a eu lieu ».
   *
   * `@Equals(true)` et non `@IsBoolean()` seul : un `false` explicite doit être
   * refusé, pas enregistré. Une inscription sur liste d'attente notant que
   * l'étudiant n'a pas consenti n'a aucun sens.
   */
  @IsBoolean()
  @Equals(true, {
    message:
      'consent must be true — a waitlist entry cannot be stored without it.',
  })
  consent!: boolean;

  /**
   * L'identifiant du texte affiché à l'écran au moment du tap.
   *
   * Une date prouve le moment, pas ce qui a été lu. Ce texte changera — il
   * décrit un service qui n'existe pas encore — et le jour où un étudiant
   * demande à quoi il s'est inscrit, il faut pouvoir produire la phrase, pas
   * seulement l'instant.
   */
  //
  // `@Transform` AVANT `@IsNotEmpty`, et ce n'est pas cosmétique : pour
  // class-validator, la chaîne « \u00a0\u00a0 » n'est pas vide. Sans découpe
  // préalable, un client pouvait envoyer `consentVersion: "   "`, passer la
  // validation, et faire écrire une preuve de consentement qui ne désigne AUCUN
  // texte. C'est la panne silencieuse que cette colonne existe pour éviter : une
  // ligne d'apparence valide dont on ne peut rien produire le jour où on la
  // demande. Un test l'a trouvée avant la revue ; l'écriture initiale ne l'avait
  // pas vue.
  //
  // La transformation vaut aussi côté service, qui reçoit alors la valeur déjà
  // découpée : `main.ts` monte le `ValidationPipe` avec `transform: true`.
  //
  // `@IsIn` sur la liste FERMÉE des versions que ce serveur sait restituer.
  //
  // Sans elle, n'importe quel client authentifié pouvait envoyer une version
  // inventée : elle passait la validation et devenait une prétendue preuve.
  // Une version qui ne désigne aucun texte figé ne prouve rien, et donne à une
  // colonne vide l'apparence d'être remplie — ce qui est pire, parce qu'on s'y
  // fie. Voir le couplage de déploiement documenté dans
  // `premium-waitlist-consent.ts`.
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  @IsIn(PREMIUM_WAITLIST_CONSENT_VERSIONS as unknown as string[], {
    message:
      'consentVersion must be one of the notice versions this server can reproduce.',
  })
  consentVersion!: string;

  /**
   * La LANGUE du texte affiché au moment du tap.
   *
   * Une version seule désigne une PAIRE de textes, français et anglais. Elle
   * dit donc « l'étudiant a accepté l'un des deux », ce qui ne suffit pas le
   * jour où il faut produire la phrase — et le problème empire s'il change de
   * langue ensuite, puisque plus rien ne rappelle celle qu'il lisait alors.
   *
   * Liste fermée elle aussi : une locale libre finirait par contenir `fr-FR`,
   * `FR` et `français` pour la même chose, et la colonne redeviendrait
   * inexploitable.
   */
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsString()
  @IsIn(PREMIUM_WAITLIST_CONSENT_LOCALES as unknown as string[], {
    message: 'consentLocale must be a locale this notice exists in.',
  })
  consentLocale!: string;
}
