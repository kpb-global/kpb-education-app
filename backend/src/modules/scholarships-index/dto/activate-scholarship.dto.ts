import {
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  MaxLength,
} from 'class-validator';

export class ActivateScholarshipDto {
  @IsString()
  @Matches(/^\d{4}(?:-\d{4})?$/, {
    message: 'academicYear must look like 2026 or 2026-2027',
  })
  academicYear!: string;

  @IsDateString()
  opensAt!: string;

  @IsDateString()
  closesAt!: string;

  @IsOptional()
  @IsDateString()
  estimatedOpenAt?: string;

  @IsOptional()
  @IsDateString()
  estimatedCloseAt?: string;

  @IsOptional()
  @IsIn(['confirmed'])
  dateConfidence?: 'confirmed';

  @IsOptional()
  @IsUrl({ require_protocol: true })
  @MaxLength(2000)
  sourceUrl?: string;
}
