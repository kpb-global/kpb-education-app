import { IsBoolean, IsIn, IsString, MaxLength } from 'class-validator';

export class GrantAiConsentDto {
  @IsIn(['fr', 'en'])
  languageCode!: 'fr' | 'en';

  @IsString()
  @MaxLength(64)
  noticeVersion!: string;

  @IsBoolean()
  accepted!: boolean;
}
