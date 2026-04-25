import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateCaseMessageDto {
  @IsString()
  @MaxLength(3000)
  body!: string;

  @IsOptional()
  @IsString()
  senderName?: string;

  @IsOptional()
  @IsString()
  senderRole?: string;
}
