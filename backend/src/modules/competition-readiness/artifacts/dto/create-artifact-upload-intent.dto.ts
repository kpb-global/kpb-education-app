import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

import { APPLICATION_ARTIFACT_KINDS } from '../../common/competition-readiness.contract';

export class CreateArtifactUploadIntentDto {
  @IsIn(APPLICATION_ARTIFACT_KINDS)
  kind!: (typeof APPLICATION_ARTIFACT_KINDS)[number];

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  title?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(255)
  originalFileName!: string;

  @IsString()
  @MaxLength(100)
  mimeType!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  sizeBytes!: number;

  @IsString()
  @Matches(/^[0-9a-fA-F]{64}$/)
  sha256!: string;
}
