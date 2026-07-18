import { Transform, Type, type TransformFnParams } from 'class-transformer';
import {
  PartnershipAgreementStatus,
  PartnershipAgreementType,
} from '@prisma/client';
import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsISO8601,
  IsObject,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

function queryArray(value: unknown): unknown {
  if (value === undefined) return undefined;
  return Array.isArray(value) ? value : [value];
}

export class ListPartnerAgreementsDto {
  @IsOptional()
  @Transform(({ value }: TransformFnParams) => queryArray(value))
  @IsArray()
  @ArrayMaxSize(10)
  @IsEnum(PartnershipAgreementStatus, { each: true })
  status?: PartnershipAgreementStatus[];

  @IsOptional()
  @Transform(({ value }: TransformFnParams) => queryArray(value))
  @IsArray()
  @ArrayMaxSize(10)
  @IsEnum(PartnershipAgreementType, { each: true })
  agreementType?: PartnershipAgreementType[];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  partnerId?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2}$/)
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

export class CreatePartnerAgreementDto {
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{2,119}$/)
  agreementKey!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  partnerId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  institutionId?: string | null;

  @IsEnum(PartnershipAgreementStatus)
  status!: PartnershipAgreementStatus;

  @IsEnum(PartnershipAgreementType)
  agreementType!: PartnershipAgreementType;

  @IsArray()
  @ArrayMaxSize(20)
  @ArrayUnique()
  @IsString({ each: true })
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/, { each: true })
  purposeCodes!: string[];

  @IsArray()
  @ArrayMaxSize(80)
  @ArrayUnique()
  @IsString({ each: true })
  @Matches(/^[A-Za-z]{2}$/, { each: true })
  countryCodes!: string[];

  @IsBoolean()
  canRecruitPilot!: boolean;

  @IsBoolean()
  canVerifySubmission!: boolean;

  @IsBoolean()
  canVerifyDecision!: boolean;

  @IsBoolean()
  canShareAggregateData!: boolean;

  @IsBoolean()
  canPubliclyNamePartner!: boolean;

  @IsBoolean()
  canUsePartnerLogo!: boolean;

  @IsOptional()
  @IsObject()
  dataProtectionScope?: Record<string, unknown> | null;

  @IsOptional()
  @IsObject()
  safeguardingScope?: Record<string, unknown> | null;

  @IsOptional()
  @IsISO8601({ strict: true })
  signedAt?: string | null;

  @IsOptional()
  @IsISO8601({ strict: true })
  startsAt?: string | null;

  @IsOptional()
  @IsISO8601({ strict: true })
  endsAt?: string | null;

  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/)
  reasonCode!: string;
}

export class UpdatePartnerAgreementDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsObject()
  changes!: Record<string, unknown>;

  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/)
  reasonCode!: string;
}

export class CreatePartnerAgreementEvidenceDto {
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/)
  kind!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  storageKey?: string;

  @IsOptional()
  @IsUrl({ protocols: ['https'], require_protocol: true })
  @MaxLength(2000)
  externalUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  note?: string;

  @IsOptional()
  @IsBoolean()
  verified?: boolean;

  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/)
  reasonCode!: string;
}
