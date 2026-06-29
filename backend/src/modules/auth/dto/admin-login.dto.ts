import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminLoginDto {
  @IsEmail()
  email!: string;

  // Optional: DB-backed admins authenticate with a password; in the DB-less dev
  // fallback the password is ignored. Must be decorated so the global
  // `forbidNonWhitelisted` ValidationPipe doesn't reject the request for
  // including a `password` field.
  @IsOptional()
  @IsString()
  @MaxLength(128)
  password?: string;
}
