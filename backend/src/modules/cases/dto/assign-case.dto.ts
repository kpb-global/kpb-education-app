import { IsISO8601, IsOptional, IsString, MaxLength } from 'class-validator';

export class AssignCaseDto {
  @IsString()
  @MaxLength(120)
  assignedAdvisorName!: string;

  @IsOptional()
  @IsString()
  assignedAdvisorPhone?: string;

  @IsOptional()
  @IsString()
  assignedAdvisorWhatsapp?: string;

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
