import { Transform, Type, type TransformFnParams } from 'class-transformer';
import { PilotStatus } from '@prisma/client';
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsEnum,
  IsIn,
  IsInt,
  IsISO8601,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
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

export class ListImpactPilotsDto {
  @IsOptional()
  @Transform(({ value }: TransformFnParams) => queryArray(value))
  @IsArray()
  @ArrayMaxSize(10)
  @IsEnum(PilotStatus, { each: true })
  status?: PilotStatus[];

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

export class CreateImpactPilotDto {
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{2,79}$/)
  code!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(4000)
  hypothesis!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(80)
  @ArrayUnique()
  @Matches(/^[A-Za-z]{2}$/, { each: true })
  countryCodes!: string[];

  @IsObject()
  targetPopulation!: Record<string, unknown>;

  @IsObject()
  primaryMetrics!: Record<string, unknown>;

  @IsObject()
  guardrailMetrics!: Record<string, unknown>;

  @IsEnum(PilotStatus)
  status!: PilotStatus;

  @IsOptional()
  @IsISO8601({ strict: true })
  recruitmentStartsAt?: string | null;

  @IsOptional()
  @IsISO8601({ strict: true })
  startsAt?: string | null;

  @IsOptional()
  @IsISO8601({ strict: true })
  endsAt?: string | null;

  @IsString()
  @Matches(/^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$/)
  protocolVersion!: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(30)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(120, { each: true })
  partnerAgreementIds?: string[];

  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/)
  reasonCode!: string;
}

export class UpdateImpactPilotDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsObject()
  changes!: Record<string, unknown>;

  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/)
  reasonCode!: string;
}

export class CreateImpactCohortDto {
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{1,79}$/)
  code!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  label!: string;

  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/)
  cohortType!: string;

  @IsObject()
  inclusionRules!: Record<string, unknown>;

  @IsObject()
  exclusionRules!: Record<string, unknown>;

  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/)
  reasonCode!: string;
}

export class EnrolImpactCohortMemberDto {
  @IsString()
  @MaxLength(120)
  userId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  workspaceId?: string;

  @IsString()
  @MaxLength(120)
  consentReceiptId!: string;

  @IsString()
  @Matches(/^[A-Za-z]{2}$/)
  countryCodeLocked!: string;

  @IsOptional() @IsString() @MaxLength(80) studyLevelLocked?: string;
  @IsOptional() @IsString() @MaxLength(80) genderCodeLocked?: string;
  @IsOptional() @IsString() @MaxLength(80) deviceClassLocked?: string;
  @IsOptional() @IsString() @MaxLength(80) connectivityLocked?: string;

  @IsString()
  @MaxLength(80)
  profileRubricVersion!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  matchingAlgorithmVersion?: string;

  @IsObject()
  baselineSnapshot!: Record<string, unknown>;

  @IsString()
  @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/)
  reasonCode!: string;
}

export class WithdrawImpactCohortMemberDto {
  @IsInt() @Min(1) expectedVersion!: number;
  @IsString() @MaxLength(200) exitReason!: string;
  @IsString() @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/) reasonCode!: string;
}

export class CreateExperimentAssignmentDto {
  @IsString() @MaxLength(120) experimentKey!: string;
  @IsString() @MaxLength(80) experimentVersion!: string;
  @IsString() @MaxLength(80) armCode!: string;
  @IsString() @Matches(/^[0-9a-f]{64}$/) assignmentSeedHash!: string;
  @IsString() @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/) reasonCode!: string;
}

export class CreatePilotAssessmentDto {
  @IsString() @MaxLength(80) assessmentType!: string;
  @IsString() @MaxLength(80) instrumentVersion!: string;
  @IsObject() answers!: Record<string, unknown>;
  @IsOptional() @IsNumber() score?: number;
  @IsOptional() @IsISO8601({ strict: true }) administeredAt?: string;
  @IsString() @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/) reasonCode!: string;
}

export class FreezeImpactSnapshotDto {
  @IsInt() @Min(1) expectedVersion!: number;
  @IsISO8601({ strict: true }) periodStart!: string;
  @IsISO8601({ strict: true }) periodEnd!: string;
  @IsISO8601({ strict: true }) sourceWatermark!: string;
  @IsString() @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/) reasonCode!: string;
}

export class ImpactReportQueryDto {
  @IsOptional() @IsString() @MaxLength(120) pilotId?: string;
  @IsOptional()
  @Transform(({ value }: TransformFnParams) => queryArray(value))
  @IsArray()
  @ArrayMaxSize(30)
  @IsString({ each: true })
  metricKey?: string[];
  @IsOptional() @IsISO8601({ strict: true }) periodStart?: string;
  @IsOptional() @IsISO8601({ strict: true }) periodEnd?: string;
  @IsOptional()
  @Transform(({ value }: TransformFnParams) => value === true || value === 'true')
  @IsBoolean()
  publicSafeOnly?: boolean;
}

export class CreateImpactDataRoomExportDto {
  @IsString() @MaxLength(120) snapshotId!: string;
  @IsString() @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/) purposeCode!: string;
  @IsOptional() @IsIn(['json']) format: 'json' = 'json';
  @IsOptional() @IsISO8601({ strict: true }) expiresAt?: string;
  @IsString() @Matches(/^[a-z0-9][a-z0-9_.-]{0,79}$/) reasonCode!: string;
}

export class ListImpactDataRoomExportsDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  pilotId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  snapshotId?: string;
}
