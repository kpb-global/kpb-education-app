import { IsObject } from 'class-validator';

export class SubmitCountryQuizDto {
  @IsObject()
  answers!: Record<string, string>;
}
