import { IsISO8601, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateAppointmentDto {
  @IsString()
  @MaxLength(120)
  title!: string;

  @IsString()
  @MaxLength(160)
  caseId!: string;

  @IsISO8601()
  scheduledAt!: string;

  @IsOptional()
  @IsString()
  contactMethod?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
