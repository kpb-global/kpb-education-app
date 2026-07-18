import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

import { SCHOLARSHIP_WORKSPACE_STATUSES } from '../../common/competition-readiness.contract';

export class ListWorkspacesQueryDto {
  @IsOptional()
  @IsIn(SCHOLARSHIP_WORKSPACE_STATUSES)
  status?: (typeof SCHOLARSHIP_WORKSPACE_STATUSES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit = 20;
}
