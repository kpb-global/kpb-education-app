import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';

import { LocalizedTextDto } from './localized-text.dto';

/**
 * Used for both create and update — every field is optional and the service
 * applies defaults / partial updates. Validation enforces shapes and rejects
 * unknown properties (global whitelist + forbidNonWhitelisted).
 */
export class UpsertNotificationTemplateDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => LocalizedTextDto)
  title?: LocalizedTextDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => LocalizedTextDto)
  body?: LocalizedTextDto;

  @IsOptional()
  @IsArray()
  @IsIn(['push', 'in_app', 'email'], { each: true })
  channels?: ('push' | 'in_app' | 'email')[];

  @IsOptional()
  @IsBoolean()
  isCritical?: boolean;
}
