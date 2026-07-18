import { IsInt, IsString, MaxLength, Min, MinLength } from 'class-validator';

export class LinkOutcomeEvidenceDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  evidenceId!: string;
}
