import {
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class ApplyAlumniDto {
  @IsString()
  @MaxLength(160)
  alumniUniversity!: string;

  @IsString()
  @MaxLength(160)
  alumniProgramme!: string;

  @IsInt()
  @Min(1950)
  @Max(2100)
  alumniGraduationYear!: number;

  @IsOptional()
  @IsString()
  @Length(2, 2)
  alumniCountryCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  alumniBioFr?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  alumniBioEn?: string;

  @IsString()
  @MaxLength(500)
  alumniProofUrl!: string;
}
