import {
  ArrayMaxSize,
  IsArray,
  IsString,
  MaxLength,
  ValidateIf,
} from 'class-validator';

/**
 * La mise à jour du PROFIL « Études en France » : niveaux et domaines. Rien
 * d'autre.
 *
 * ## Ce qui n'y est pas, et pourquoi
 *
 * Ni `consent`, ni `consentVersion`, ni `wantsPremium`. Le pipe global est en
 * `forbidNonWhitelisted` : un corps qui en porte un est REFUSÉ (400), il n'est
 * pas ignoré en silence. C'est la propriété voulue — modifier ses domaines ne
 * doit ni redonner un consentement commercial que l'étudiant n'a pas redonné, ni
 * effacer son intérêt Premium. `POST /etudes-en-france/interest` reste la seule
 * porte du consentement.
 *
 * ## Trois états par champ
 *
 * Absent : inchangé. Chaîne vide (ou tableau vide) : effacé. Valeur : remplacée.
 * `null` est refusé plutôt qu'interprété — il se lirait aussi bien « inchangé »
 * que « effacé ».
 */
export class UpdateEefProfileDto {
  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(64)
  currentLevel?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(64)
  targetLevel?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsArray()
  @ArrayMaxSize(32)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  fieldIds?: string[];
}
