import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/**
 * Une déclaration d'intérêt pour l'espace « Études en France ».
 *
 * Tout est optionnel sauf le consentement : la vitrine doit pouvoir enregistrer
 * un « ça m'intéresse » en un tap. Exiger le niveau et la filière aurait
 * transformé le seul signal qu'on cherche à mesurer en formulaire à remplir, et
 * on aurait mesuré la patience plutôt que l'intérêt.
 *
 * Les bornes ne sont pas décoratives : ces chaînes finissent dans un export CSV
 * lu par l'équipe commerciale, et `fieldIds` est plafonné parce qu'un client
 * malveillant n'a aucune raison d'en envoyer mille.
 */
export class DeclareEefInterestDto {
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
