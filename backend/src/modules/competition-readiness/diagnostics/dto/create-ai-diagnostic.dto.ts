import {
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateAiDiagnosticDto {
  @IsIn(['fr', 'en'])
  language!: 'fr' | 'en';

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  consentReceiptId?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  artifactVersionId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(12_000)
  applicationExcerpt?: string;
}
