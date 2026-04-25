import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreatePartnerLeadDto {
  @IsString()
  @MaxLength(140)
  organizationName!: string;

  @IsString()
  @MaxLength(120)
  contactName!: string;

  @IsEmail()
  email!: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  country?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}
