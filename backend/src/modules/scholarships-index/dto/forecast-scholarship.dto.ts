import { IsDateString, IsOptional, IsString, IsUrl, Matches, MaxLength } from 'class-validator';

export class ForecastScholarshipDto {
  @IsString()
  @Matches(/^\d{4}(?:-\d{4})?$/, {
    message: 'academicYear must look like 2026 or 2026-2027',
  })
  academicYear!: string;

  @IsDateString()
  estimatedOpenAt!: string;

  @IsDateString()
  estimatedCloseAt!: string;

  @IsOptional()
  @IsUrl({ require_protocol: true })
  @MaxLength(2000)
  sourceUrl?: string;
}
