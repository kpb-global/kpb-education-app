import { IsBoolean, IsIn, IsString, MaxLength } from 'class-validator';

export class GrantOutcomeConsentDto {
  @IsIn(['outcome_evidence'])
  purpose!: 'outcome_evidence';

  @IsIn(['fr', 'en'])
  languageCode!: 'fr' | 'en';

  @IsString()
  @MaxLength(64)
  noticeVersion!: string;

  @IsBoolean()
  accepted!: boolean;
}
