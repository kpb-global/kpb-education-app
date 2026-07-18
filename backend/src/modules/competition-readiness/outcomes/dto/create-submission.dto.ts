import {
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateSubmissionDto {
  @IsInt()
  @Min(1)
  expectedWorkspaceVersion!: number;

  @IsDateString({ strict: true })
  submittedAt!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  submissionChannel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  applicationReference?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  evidenceId!: string;
}
