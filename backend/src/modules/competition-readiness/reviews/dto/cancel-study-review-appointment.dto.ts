import { IsInt, IsString, Matches, MaxLength, Min } from 'class-validator';

export class CancelStudyReviewAppointmentDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsString()
  @MaxLength(64)
  @Matches(/^[a-z0-9][a-z0-9_.-]*$/)
  reasonCode!: string;
}
