import { IsString, MaxLength } from 'class-validator';

// senderRole and senderName are intentionally absent: students must not choose
// their own role. The service defaults to 'student'. Staff messages arrive via
// the WebSocket gateway (CaseMessagingGateway) where the role is derived from
// the authenticated connection, not from the payload.
export class CreateCaseMessageDto {
  @IsString()
  @MaxLength(3000)
  body!: string;
}
