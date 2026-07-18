import { IsIn, IsInt, Min } from 'class-validator';

export class UpdateWorkspaceDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsIn(['archive', 'reopen'])
  action!: 'archive' | 'reopen';
}
