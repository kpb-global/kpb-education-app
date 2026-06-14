import {
  IsArray,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateNotificationCampaignDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsString()
  templateId?: string | null;

  @IsOptional()
  @IsIn(['all_users', 'all_students', 'country', 'case_status', 'single_user'])
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
