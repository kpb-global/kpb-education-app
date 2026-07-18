import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsInt,
  IsISO8601,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class OfferReviewSlotsDto {
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(10)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(120, { each: true })
  slotIds!: string[];

  @IsISO8601({ strict: true })
  expiresAt!: string;

  @IsString()
  @MaxLength(64)
  @Matches(/^[a-z0-9][a-z0-9_.-]*$/)
  reasonCode!: string;
}
