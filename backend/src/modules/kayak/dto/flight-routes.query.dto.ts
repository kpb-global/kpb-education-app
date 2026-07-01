import {
  IsISO4217CurrencyCode,
  IsOptional,
  IsString,
  Matches,
} from 'class-validator';

/** Query params for `GET /api/flights/routes`. */
export class FlightRoutesQueryDto {
  @Matches(/^[A-Za-z]{3}$/, { message: 'origin must be a 3-letter IATA code' })
  origin!: string;

  @Matches(/^[A-Za-z]{3}$/, {
    message: 'destination must be a 3-letter IATA code',
  })
  destination!: string;

  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'departDate must be in YYYY-MM-DD format',
  })
  departDate!: string;

  // Presence ⇒ round trip.
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'returnDate must be in YYYY-MM-DD format',
  })
  returnDate?: string;

  @IsOptional()
  @IsISO4217CurrencyCode({ message: 'currency must be an ISO-4217 code' })
  currency?: string;

  @IsOptional()
  @IsString()
  userTrackId?: string;
}
