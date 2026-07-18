import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export const TRIAGE_ACTIONS = [
  'triage',
  'assign',
  'request_more_information',
  'recommend_autonomy',
  'decline',
  'close',
] as const;

export class TriageReviewRequestDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsIn(TRIAGE_ACTIONS)
  action!: (typeof TRIAGE_ACTIONS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  assignedCounsellorId?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  triageSummary?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  missingItems?: string[];

  @IsString()
  @MaxLength(64)
  @Matches(/^[a-z0-9][a-z0-9_.-]*$/)
  reasonCode!: string;
}
