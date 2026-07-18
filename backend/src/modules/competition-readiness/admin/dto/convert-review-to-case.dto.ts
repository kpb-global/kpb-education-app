import { IsEnum, IsInt, IsOptional, IsString, Matches, MaxLength, Min } from 'class-validator';

import { CaseType } from '../../../../common/enums/case-type.enum';

export class ConvertReviewToCaseDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsOptional()
  @IsEnum(CaseType)
  caseType?: CaseType;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  serviceOfferId?: string;

  @IsString()
  @MaxLength(64)
  @Matches(/^[a-z0-9][a-z0-9_.-]*$/)
  reasonCode!: string;
}
