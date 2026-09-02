import { Transform } from 'class-transformer';
import { Equals, IsBoolean, IsNotEmpty, IsString, MaxLength } from 'class-validator';

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
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  consentVersion!: string;
}
