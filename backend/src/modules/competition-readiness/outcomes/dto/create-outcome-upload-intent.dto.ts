import { OutcomeEvidenceKind } from '@prisma/client';
import {
  IsEnum,
  IsInt,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateOutcomeUploadIntentDto {
  @IsEnum(OutcomeEvidenceKind)
  kind!: OutcomeEvidenceKind;

  @IsString()
  @MinLength(1)
  @MaxLength(255)
  originalFileName!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  mimeType!: string;

  @IsInt()
  @Min(1)
  @Max(10 * 1024 * 1024)
  sizeBytes!: number;

  @Matches(/^[0-9a-fA-F]{64}$/)
  sha256!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  consentReceiptId!: string;
}
