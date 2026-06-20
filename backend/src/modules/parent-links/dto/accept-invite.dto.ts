import { IsString, Length } from 'class-validator';

export class AcceptInviteDto {
  @IsString()
  @Length(8, 8)
  inviteCode!: string;
}
