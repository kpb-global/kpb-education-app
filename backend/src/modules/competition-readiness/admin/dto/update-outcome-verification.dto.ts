import { EvidenceVerificationStatus } from '@prisma/client';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class UpdateOutcomeVerificationDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsEnum(EvidenceVerificationStatus)
  status!: EvidenceVerificationStatus;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  @Matches(/^[a-z0-9][a-z0-9_.-]*$/)
  reasonCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}
