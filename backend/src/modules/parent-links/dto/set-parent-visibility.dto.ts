import { IsBoolean } from 'class-validator';

export class SetParentVisibilityDto {
  @IsBoolean()
  parentCanView!: boolean;
}
