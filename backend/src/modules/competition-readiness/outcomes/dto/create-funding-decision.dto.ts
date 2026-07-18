import { FundingDecision } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateFundingDecisionDto {
  @IsInt()
  @Min(1)
  expectedWorkspaceVersion!: number;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  admissionDecisionId?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(180)
  issuedByName!: string;

  @IsEnum(FundingDecision)
  fundingDecision!: FundingDecision;

  @IsOptional()
  @Matches(/^[1-9][0-9]{0,17}$/)
  fundingAmountMinor?: string;

  @IsOptional()
  @Matches(/^[A-Z]{3}$/)
  fundingCurrency?: string;

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
