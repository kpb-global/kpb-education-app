import {
  IsArray,
  IsBoolean,
  IsEmail,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

import { InternalRole } from '../../../common/enums/internal-role.enum';

export class CreateAdminUserDto {
  @IsString()
  @MaxLength(120)
  fullName!: string;

  @IsEmail()
  email!: string;

  @IsEnum(InternalRole)
  role!: InternalRole;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  languageScope?: string[];

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  workload?: number;
}
