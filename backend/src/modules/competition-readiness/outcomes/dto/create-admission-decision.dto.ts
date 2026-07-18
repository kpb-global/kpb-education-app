import { AdmissionDecision } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateAdmissionDecisionDto {
  @IsInt()
  @Min(1)
  expectedWorkspaceVersion!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(180)
  issuedByName!: string;

  @IsEnum(AdmissionDecision)
  admissionDecision!: AdmissionDecision;

  @IsOptional()
  @IsDateString({ strict: true })
  issuedAt?: string;

  @IsDateString({ strict: true })
  receivedAt!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  evidenceId!: string;
}
