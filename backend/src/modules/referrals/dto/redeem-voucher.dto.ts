import { IsString, Length } from 'class-validator';

/// Idempotency key for a credit redemption: a UUID the client generates once
/// per redeem tap. A retried network call reuses it, so the spend never doubles.
export class RedeemVoucherDto {
  @IsString()
  @Length(8, 64)
  clientRef!: string;
}
