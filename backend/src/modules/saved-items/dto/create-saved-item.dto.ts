import { IsString, MaxLength } from 'class-validator';

export class CreateSavedItemDto {
  @IsString()
  @MaxLength(40)
  type!: string;

  @IsString()
  @MaxLength(120)
  itemId!: string;
}
