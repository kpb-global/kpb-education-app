import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const STUDY_REVIEW_STATUSES = [
  'draft',
  'submitted',
  'triaged',
  'more_information_needed',
  'call_offered',
  'scheduled',
  'converted_to_case',
  'autonomy_recommended',
  'declined',
  'closed',
] as const;

function asArray(value: unknown): unknown[] | undefined {
  if (value === undefined || value === null || value === '') return undefined;
  return Array.isArray(value) ? value : [value];
}

function asBoolean(value: unknown): unknown {
  if (value === true || value === 'true') return true;
  if (value === false || value === 'false') return false;
  return value;
}

export class ListAdminReviewRequestsDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 20;

  @IsOptional()
  @Transform(({ value }) => asArray(value))
  @IsArray()
  @ArrayMaxSize(10)
  @IsIn(STUDY_REVIEW_STATUSES, { each: true })
  status?: (typeof STUDY_REVIEW_STATUSES)[number][];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  assignedCounsellorId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  scholarshipId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(16)
  countryCode?: string;

  @IsOptional()
  @Transform(({ value }) => asBoolean(value))
  @IsBoolean()
  overdueOnly?: boolean;
}
