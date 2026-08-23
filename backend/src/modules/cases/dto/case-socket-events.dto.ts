import { IsBoolean, IsNotEmpty, IsString, Matches, MaxLength } from 'class-validator';

import { MAX_CASE_MESSAGE_LENGTH } from './create-case-message.dto';

export class CaseSocketRoomDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  @Matches(/^[A-Za-z0-9_-]+$/)
  caseId!: string;
}

export class CaseSocketMessageDto extends CaseSocketRoomDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/\S/)
  @MaxLength(MAX_CASE_MESSAGE_LENGTH)
  body!: string;
}

export class CaseSocketTypingDto extends CaseSocketRoomDto {
  @IsBoolean()
  isTyping!: boolean;
}
