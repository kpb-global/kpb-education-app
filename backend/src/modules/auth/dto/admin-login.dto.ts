import { IsEmail } from 'class-validator';

export class AdminLoginDto {
  @IsEmail()
  email!: string;

  password?: string;
}
