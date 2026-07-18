import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateStudyReviewRequestDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ArrayUnique()
  @IsString({ each: true })
  @MinLength(1, { each: true })
  @MaxLength(120, { each: true })
  artifactVersionIds!: string[];

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  consentReceiptId!: string;

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
}
