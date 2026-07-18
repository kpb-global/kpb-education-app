import { Type } from 'class-transformer';
import { EvidenceVerificationStatus } from '@prisma/client';
import {
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class ListAdminOutcomesDto {
  @IsOptional()
  @IsIn(['submission', 'admission', 'funding'])
  type?: 'submission' | 'admission' | 'funding';

  @IsOptional()
  @IsEnum(EvidenceVerificationStatus)
  verificationStatus?: EvidenceVerificationStatus;

  @IsOptional()
  @IsString()
  @MaxLength(16)
  countryCode?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 20;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  cursor?: string;
}
