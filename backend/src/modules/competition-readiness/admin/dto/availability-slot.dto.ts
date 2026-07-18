import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const SLOT_STATUSES = [
  'available',
  'blocked',
  'exhausted',
  'cancelled',
] as const;

export class ListAvailabilitySlotsDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  counsellorId?: string;

  @IsOptional()
  @IsISO8601({ strict: true })
  from?: string;

  @IsOptional()
  @IsISO8601({ strict: true })
  to?: string;

  @IsOptional()
  @IsIn(SLOT_STATUSES)
  status?: (typeof SLOT_STATUSES)[number];

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 50;
}

export class CreateAvailabilitySlotDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  counsellorId?: string;

  @IsISO8601({ strict: true })
  startsAt!: string;

  @IsISO8601({ strict: true })
  endsAt!: string;

  @IsString()
  @MaxLength(64)
  @Matches(/^(UTC|[A-Za-z_]+(?:\/[A-Za-z0-9_+\-]+)+)$/)
  timezone!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10)
  capacity = 1;

  @IsString()
  @MaxLength(64)
  @Matches(/^[a-z0-9][a-z0-9_.-]*$/)
  reasonCode!: string;
}

export class CancelAvailabilitySlotDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsString()
  @MaxLength(64)
  @Matches(/^[a-z0-9][a-z0-9_.-]*$/)
  reasonCode!: string;
}
