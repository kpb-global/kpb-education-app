import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Validate,
} from 'class-validator';

import { MinimumAccountAgeConstraint } from '../profile-age.policy';

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
  @IsInt()
  monthlyBudgetEur?: number;

  @IsOptional()
  @IsInt()
  annualTuitionBudgetEur?: number;

  @IsOptional()
  @IsString()
  preferredCurrency?: string;

  @IsOptional()
  @IsBoolean()
  wantsScholarshipSupport?: boolean;

  // Scholarship-newsletter (Mautic) opt-in. The server stamps
  // newsletterConsentedAt on the false→true transition (GDPR proof) — clients
  // only send the desired boolean.
  @IsOptional()
  @IsBoolean()
  scholarshipNewsletterOptIn?: boolean;

  // KPB-169: canonical per-type notification opt-outs. Unknown keys are
  // dropped server-side rather than rejected, so a newer client that knows one
  // extra type can still save the types this server does understand.
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  disabledNotificationTypes?: string[];

  // DEPRECATED (KPB-169) — folded into disabledNotificationTypes on write and
  // derived on read. Accepted for clients built before the array existed.
  @IsOptional()
  @IsBoolean()
  dailyScholarshipOptOut?: boolean;

  @IsOptional()
  @IsBoolean()
  weeklyDigestOptOut?: boolean;

  @IsOptional()
  @IsArray()
  availableDocuments?: string[];

  // ISO timestamp when the user granted explicit consent to third-party AI
  // (Groq) processing. Set once the user opts into the AI coach.
  @IsOptional()
  @IsDateString()
  aiConsentedAt?: string;

  // Age gate + self-attested guardian consent for declared minors (<18).
  @IsOptional()
  @IsDateString()
  @Validate(MinimumAccountAgeConstraint)
  birthDate?: string;

  @IsOptional()
  @IsString()
  guardianName?: string;

  @IsOptional()
  @IsString()
  guardianContact?: string;

  @IsOptional()
  @IsDateString()
  guardianConsentedAt?: string;
}
