import { IsString, MaxLength } from 'class-validator';

export class LocalizedTextDto {
  @IsString()
  @MaxLength(500)
  fr!: string;

  @IsString()
  @MaxLength(500)
  en!: string;
}
