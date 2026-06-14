import { IsEmail, IsNotEmpty, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class StudentRegisterDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8, { message: 'Le mot de passe doit contenir au moins 8 caractères.' })
  @MaxLength(128, { message: 'Le mot de passe ne peut pas dépasser 128 caractères.' })
  @Matches(/^(?=.*[A-Z])(?=.*\d)/, {
    message: 'Le mot de passe doit contenir au moins une majuscule et un chiffre.',
  })
  password!: string;

  @IsString()
  @IsNotEmpty({ message: 'Le nom complet est requis.' })
  @MaxLength(200)
  fullName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  countryOfResidence?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5)
  preferredLanguage?: string;
}
