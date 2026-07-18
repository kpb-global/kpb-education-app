import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

import { WORKSPACE_STEP_STATUSES } from '../../common/competition-readiness.contract';

export class UpdateWorkspaceStepDto {
  @IsIn(WORKSPACE_STEP_STATUSES)
  status!: (typeof WORKSPACE_STEP_STATUSES)[number];

  @IsString()
  @MinLength(1)
  @MaxLength(128)
  clientMutationId!: string;

  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notApplicableReason?: string;
}
