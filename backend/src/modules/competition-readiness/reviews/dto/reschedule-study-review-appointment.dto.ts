import { IsInt, IsString, Matches, MaxLength, Min } from 'class-validator';

export class RescheduleStudyReviewAppointmentDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsString()
  @MaxLength(120)
  slotOfferId!: string;

  @IsString()
  @MaxLength(160)
  @Matches(/^[A-Za-z0-9][A-Za-z0-9._:-]*$/)
  bookingKey!: string;

  @IsString()
  @MaxLength(64)
  @Matches(/^(UTC|[A-Za-z_]+(?:\/[A-Za-z0-9_+\-]+)+)$/)
  timezone!: string;

  @IsString()
  @MaxLength(64)
  @Matches(/^[a-z0-9][a-z0-9_.-]*$/)
  reasonCode!: string;
}
