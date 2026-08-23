import { IsNotEmpty, IsString, Matches, MaxLength } from 'class-validator';

export const MAX_CASE_MESSAGE_LENGTH = 3000;

// senderRole and senderName are intentionally absent: students must not choose
// their own role. The service defaults to 'student'. Staff messages arrive via
// the WebSocket gateway (CaseMessagingGateway) where the role is derived from
// the authenticated connection, not from the payload.
export class CreateCaseMessageDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/\S/)
  @MaxLength(MAX_CASE_MESSAGE_LENGTH)
  body!: string;
}
