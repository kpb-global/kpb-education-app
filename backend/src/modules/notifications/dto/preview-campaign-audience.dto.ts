import { IsIn, IsObject, IsOptional } from 'class-validator';

import { AUDIENCE_TYPES } from '../campaign-audience';

export class PreviewCampaignAudienceDto {
  @IsOptional()
  @IsIn(AUDIENCE_TYPES)
  audienceType?: string;

  @IsOptional()
  @IsObject()
  filters?: Record<string, unknown>;
}
