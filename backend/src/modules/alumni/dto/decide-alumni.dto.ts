import { IsIn } from 'class-validator';

export class DecideAlumniDto {
  @IsIn(['approved', 'rejected'])
  decision!: 'approved' | 'rejected';
}
