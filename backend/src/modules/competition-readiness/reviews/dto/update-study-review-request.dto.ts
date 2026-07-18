import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class UpdateStudyReviewRequestDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  studentMessage?: string;

  @IsOptional()
  @IsIn(['in_app', 'whatsapp', 'phone', 'email'])
  preferredContact?: 'in_app' | 'whatsapp' | 'phone' | 'email';

  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(/^(UTC|[A-Za-z_]+(?:\/[A-Za-z0-9_+\-]+)+)$/)
  timezone?: string;

  @IsOptional()
  @IsObject()
  availability?: Record<string, unknown>;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(120, { each: true })
  artifactVersionIds?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  consentReceiptId?: string;
}
