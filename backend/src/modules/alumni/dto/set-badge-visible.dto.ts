import { IsBoolean } from 'class-validator';

export class SetBadgeVisibleDto {
  @IsBoolean()
  visible!: boolean;
}
