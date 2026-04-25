import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';

import { CaseType } from '../../../common/enums/case-type.enum';

export class CreateCaseDto {
  @IsEnum(CaseType)
  type!: CaseType;

  @IsString()
  @MaxLength(120)
  title!: string;

  @IsString()
  @MaxLength(2000)
  description!: string;

  @IsString()
  @MaxLength(160)
  contextLabel!: string;

  @IsOptional()
  @IsString()
  preferredContactMethod?: string;
}
