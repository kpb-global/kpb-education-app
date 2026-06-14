import { IsArray, IsBoolean, IsEmail, IsEnum, IsOptional, IsString } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  fullName?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  whatsApp?: string;

  @IsOptional()
  @IsString()
  countryOfResidence?: string;

  @IsOptional()
  @IsString()
  preferredLanguage?: string;

  @IsOptional()
  @IsString()
  currentLevel?: string;

  @IsOptional()
  @IsString()
  targetLevel?: string;

  @IsOptional()
  @IsString()
  languageLevel?: string;

  @IsOptional()
  @IsArray()
  fieldIds?: string[];

  @IsOptional()
  @IsArray()
  targetCountryIds?: string[];

  @IsOptional()
  @IsString()
  gradeRange?: string;

  @IsOptional()
  @IsBoolean()
  wantsScholarshipSupport?: boolean;

  @IsOptional()
  @IsArray()
  availableDocuments?: string[];
}
