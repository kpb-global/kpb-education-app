import { IsEmail, IsString, MaxLength } from 'class-validator';

export class StudentLoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MaxLength(128)
  password!: string;
}
