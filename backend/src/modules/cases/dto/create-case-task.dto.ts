import { IsISO8601, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateCaseTaskDto {
  @IsString()
  @MaxLength(160)
  title!: string;

  @IsOptional()
  @IsString()
  assigneeName?: string;

  @IsOptional()
  @IsString()
  assigneeRole?: string;

  @IsOptional()
  @IsISO8601()
  dueAt?: string;

  @IsOptional()
  @IsString()
  status?: string;
}
