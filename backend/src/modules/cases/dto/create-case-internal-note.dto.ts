import { IsString, MaxLength } from 'class-validator';

export class CreateCaseInternalNoteDto {
  @IsString()
  @MaxLength(120)
  authorName!: string;

  @IsString()
  @MaxLength(80)
  authorRole!: string;

  @IsString()
  @MaxLength(2000)
  body!: string;
}
