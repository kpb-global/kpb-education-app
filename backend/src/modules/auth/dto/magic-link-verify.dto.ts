import { IsEmail, IsOptional, IsString, Length, MaxLength } from 'class-validator';

export class MagicLinkVerifyDto {
  /** Full magic-link token (`{id}.{secret}`) from email deep link. */
  @IsOptional()
  @IsString()
  @MaxLength(256)
  token?: string;

  /** Email + 6-digit code fallback when opening the link on another device. */
  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  @Length(6, 6)
  code?: string;
}
