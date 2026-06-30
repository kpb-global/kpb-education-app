import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

import { InternalRole } from '../../../common/enums/internal-role.enum';

export class UpdateAdminUserDto {
  @IsOptional()
  @IsEnum(InternalRole)
  role?: InternalRole;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  workload?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  languageScope?: string[];
}
