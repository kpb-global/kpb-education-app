import { Transform, type TransformFnParams } from 'class-transformer';
import {
  ArrayMaxSize,
  Equals,
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/**
 * Une déclaration d'intérêt pour l'espace « Études en France ».
 *
 * Tout est optionnel sauf le consentement — et cette phrase était FAUSSE quand
 * elle a été écrite : aucun champ de consentement n'existait. Elle l'est
 * maintenant, grâce à [consent] et [consentVersion].
 *
 * Le reste demeure optionnel : la vitrine doit pouvoir enregistrer un « ça
 * m'intéresse » en un tap. Exiger le niveau et la filière aurait transformé le
 * seul signal qu'on cherche à mesurer en formulaire à remplir, et on aurait
 * mesuré la patience plutôt que l'intérêt.
 *
 * Les bornes ne sont pas décoratives : ces chaînes finissent dans un export CSV
 * lu par l'équipe commerciale, et `fieldIds` est plafonné parce qu'un client
 * malveillant n'a aucune raison d'en envoyer mille.
 */
export class DeclareEefInterestDto {
  /**
   * Le consentement, EXIGÉ et devant valoir exactement `true`.
   *
   * ## Ce que ce champ répare
   *
   * Sans lui, `consentedAt` était un `now()` implicite : le serveur horodatait
   * chaque écriture, donc un `POST` au corps vide — un script, un `curl`, le
   * rejeu d'une requête capturée, un retry automatique — produisait une ligne
   * portant une preuve de consentement que rien ne distinguait d'un tap sur la
   * feuille. Le `now()` n'avait pas été supprimé, il avait été déplacé de
   * Postgres vers Node.
   *
   * La propriété que l'horodatage serveur démontre est « non antidatable ». Ce
   * champ ajoute la seule qui manquait : « l'acte a eu lieu ».
   *
   * `@Equals(true)` et non `@IsBoolean()` : un `false` explicite doit être
   * refusé, pas enregistré. Il n'existe aucun cas d'usage où l'on écrit une
   * déclaration d'intérêt en notant que l'étudiant n'a pas consenti.
   */
  @IsBoolean()
  @Equals(true, {
    message:
      'consent must be true — a declaration cannot be stored without it.',
  })
  consent!: boolean;

  /**
   * L'identifiant du texte de consentement affiché à l'écran.
   *
   * Une date prouve le moment, pas ce qui a été lu. Le jour où un étudiant
   * demande sur quelle base on l'a rappelé, il faut pouvoir produire la PHRASE
   * qu'il a acceptée — et cette phrase changera, en français comme en anglais.
   * Sans version, on ne pourrait produire qu'un horodatage.
   *
   * Le dépôt a déjà ce mécanisme en plus riche (`ConsentNotice` versionné avec
   * son empreinte de contenu, `ConsentReceipt`) ; il n'est branché que sur le
   * Success Lab. Cette colonne est la version pauvre mais réelle, et le
   * chaînage complet est un chantier à part.
   *
   * ## Pourquoi le `@Transform` n'est pas cosmétique
   *
   * Pour class-validator, `"   "` n'est PAS une chaîne vide : `@IsNotEmpty()`
   * la laisse passer. Le service faisait ensuite `.trim()` et écrivait `""` en
   * base — une ligne d'apparence irréprochable, portant un `consentedAt` et une
   * version VIDE, c'est-à-dire une preuve de consentement qui ne désigne aucun
   * texte. C'est la panne exacte que cette colonne existe pour éviter, et rien
   * ne l'aurait signalée : la ligne redevenait ce qu'elle valait AVANT l'ajout
   * du champ.
   *
   * Le rognage doit donc avoir lieu ICI, pas dans le service. `main.ts` monte
   * le `ValidationPipe` avec `transform: true`, donc la transformation
   * s'applique avant les validateurs : `@IsNotEmpty()` juge la valeur réelle,
   * et `@MaxLength(64)` mesure la chaîne STOCKÉE plutôt que son remplissage.
   */
  @Transform(({ value }: TransformFnParams) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  consentVersion!: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  currentLevel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  targetLevel?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(32)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  fieldIds?: string[];

  @IsOptional()
  @IsBoolean()
  wantsPremium?: boolean;
}
