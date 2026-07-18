import { IsString, MaxLength, MinLength } from 'class-validator';

export class CreateWorkspaceDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  scholarshipId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  cycleId!: string;
}
