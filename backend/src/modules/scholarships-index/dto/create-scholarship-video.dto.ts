import {
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateScholarshipVideoDto {
  @IsUrl({ require_protocol: true, protocols: ['https'] })
  @IsNotEmpty()
  @MaxLength(2000)
  youtubeUrl!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  titleFr!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  titleEn!: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  descriptionFr?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  descriptionEn?: string;

  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['https'] })
  @MaxLength(2000)
  thumbnailUrl?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(86400)
  durationSeconds?: number;

  @IsOptional()
  @IsString()
  @Matches(/^[a-z]{2}(?:-[A-Z]{2})?$/)
  languageCode?: string;

  @IsOptional()
  @IsDateString()
  youtubePublishedAt?: string;

  @IsOptional()
  @IsIn(['draft', 'published', 'archived'])
  status?: 'draft' | 'published' | 'archived';

  @IsOptional()
  @IsBoolean()
  isFeatured?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000)
  displayOrder?: number;
}
