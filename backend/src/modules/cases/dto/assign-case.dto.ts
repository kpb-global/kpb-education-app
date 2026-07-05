import { IsISO8601, IsOptional, IsString, MaxLength } from 'class-validator';

// No advisor phone/WhatsApp fields on purpose: student contact always goes
// through the official KPB line, so personal numbers are never stored on a
// case (anti-fraud, Item 12).
export class AssignCaseDto {
  @IsString()
  @MaxLength(120)
  assignedAdvisorName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  nextStepTitle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  nextStepDescription?: string;

  @IsOptional()
  @IsISO8601()
  scheduledAt?: string;
}
