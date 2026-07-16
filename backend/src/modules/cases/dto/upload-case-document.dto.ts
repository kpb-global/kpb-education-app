import { IsString, MaxLength } from 'class-validator';

export class UploadCaseDocumentDto {
  @IsString()
  @MaxLength(120)
  title!: string;
}
