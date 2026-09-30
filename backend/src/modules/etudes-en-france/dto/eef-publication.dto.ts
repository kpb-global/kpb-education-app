import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * La demande de publication (ou de retrait) d'un établissement de l'import.
 *
 * ## Une simulation d'abord, et un chiffre pour écrire
 *
 * `apply` vaut faux par défaut : sans lui, la réponse est le PLAN, rien n'est écrit.
 * Pour écrire, `expectedPrograms` doit valoir EXACTEMENT le nombre de formations
 * que le plan annonce. C'est à la fois une confirmation saisie (un `apply: true`
 * collé par erreur ne suffit pas) et un contrôle de concurrence (si quelqu'un a
 * publié entre-temps, le compte ne correspond plus et rien n'est écrit).
 *
 * `programIds`, s'il est donné, doit contenir au moins un identifiant : une liste
 * vide se lirait « aucune » ou « toutes », et les deux lectures sont plausibles.
 */
export class EefPublicationDto {
  @IsOptional()
  @IsBoolean()
  apply?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(5000)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(80, { each: true })
  programIds?: string[];

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100_000)
  expectedPrograms?: number;
}
