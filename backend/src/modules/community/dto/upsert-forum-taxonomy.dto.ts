import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, ValidateNested } from 'class-validator';

import { PublicationStatus } from '../../../common/enums/publication-status.enum';
import { LocalizedTextDto } from './localized-text.dto';

/**
 * Shared by forum categories and tags, for both create and update. All fields
 * are optional (the service applies defaults / partial updates); validation
 * enforces shapes and rejects unknown properties.
 */
export class UpsertForumTaxonomyDto {
  @IsOptional()
  @ValidateNested()
  @Type(() => LocalizedTextDto)
  label?: LocalizedTextDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => LocalizedTextDto)
  description?: LocalizedTextDto;

  @IsOptional()
  @IsInt()
  displayOrder?: number;

  @IsOptional()
  @IsEnum(PublicationStatus)
  status?: PublicationStatus;
}
