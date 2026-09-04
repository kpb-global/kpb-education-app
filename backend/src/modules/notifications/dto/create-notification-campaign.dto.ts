import {
  IsArray,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

import { AUDIENCE_TYPES } from '../campaign-audience';

export class CreateNotificationCampaignDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsString()
  templateId?: string | null;

  /**
   * Doit rester ALIGNÉ sur les branches de `CampaignExecutorService
   * .resolveRecipients` — un test le vérifie dans les deux sens.
   *
   * Trois audiences étaient implémentées et inatteignables : `account_type`,
   * `study_level` et `country_of_residence` existaient dans l'exécuteur mais
   * pas ici, donc les demander rendait 400. À l'inverse, une valeur acceptée
   * ici sans branche dans l'exécuteur produirait 0 destinataire en silence.
   */
  @IsOptional()
  @IsIn(AUDIENCE_TYPES)
  audienceType?: string;

  @IsOptional()
  @IsObject()
  filters?: Record<string, unknown>;

  @IsOptional()
  @IsArray()
  @IsIn(['push', 'in_app', 'email'], { each: true })
  channels?: ('push' | 'in_app' | 'email')[];

  @IsOptional()
  @IsString()
  scheduledFor?: string | null;

  @IsOptional()
  @IsString()
  linkedCaseId?: string | null;
}
