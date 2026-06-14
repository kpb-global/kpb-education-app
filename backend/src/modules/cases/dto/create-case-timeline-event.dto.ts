import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';

import { CaseStatus } from '../../../common/enums/case-status.enum';

export class CreateCaseTimelineEventDto {
  @IsString()
  @MaxLength(120)
  title!: string;

  @IsString()
  @MaxLength(2000)
  description!: string;

  @IsOptional()
  @IsEnum(CaseStatus)
  status?: CaseStatus;
}
