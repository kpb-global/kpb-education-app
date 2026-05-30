import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';

import { StudentAuthService } from '../auth/student-auth.service';
import { CasesService } from './cases.service';
import { FirebasePushService } from '../notifications/firebase-push.service';

@WebSocketGateway({
  namespace: '/cases',
  cors: {
    origin: process.env.CORS_ORIGINS?.split(',') ?? ['http://localhost:3000'],
    credentials: true,
  },
})
export class CaseMessagingGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(CaseMessagingGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly studentAuthService: StudentAuthService,
    private readonly casesService: CasesService,
    private readonly pushService: FirebasePushService,
  ) {}

  async handleConnection(client: Socket) {
    const token = client.handshake.query.token as string;
    if (!token) {
      client.disconnect();
      return;
    }

    try {
      const user = await this.studentAuthService.verifyAccessToken(token);
      client.data.userId = user.id;
      client.data.email = user.email;
      client.data.role =
        (client.handshake.query.role as string | undefined) ?? 'student';
      // Store the display name so messages show a friendly sender name.
      client.data.fullName =
        (client.handshake.query.fullName as string | undefined) ?? user.email;
      this.logger.log(`Client connected: ${user.email} (${client.data.role})`);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.log(
      `Client disconnected: ${client.data?.email ?? 'unknown'}`,
    );
  }

  @SubscribeMessage('joinCase')
  async handleJoinCase(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { caseId: string },
  ) {
    const room = `case:${data.caseId}`;
    await client.join(room);
    this.logger.log(
      `${client.data.email} joined room ${room}`,
    );
    return { event: 'joinedCase', data: { caseId: data.caseId } };
  }

  @SubscribeMessage('leaveCase')
  async handleLeaveCase(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { caseId: string },
  ) {
    const room = `case:${data.caseId}`;
    await client.leave(room);
  }

  @SubscribeMessage('newMessage')
  async handleNewMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { caseId: string; body: string },
  ) {
    const userId = client.data.userId as string;
    const role = client.data.role as string;
    const senderRole =
      role == 'commercial' || role == 'counselor' || role == 'advisor'
        ? role
        : 'student';
    // Prefer the display name stored on connect; fall back to email.
    const senderName =
      (client.data.fullName as string | undefined) ?? client.data.email;
    const message = await this.casesService.createMessage(data.caseId, {
      senderName,
      senderRole,
      body: data.body,
    });

    const room = `case:${data.caseId}`;
    this.server.to(room).emit('message', message);
    client.emit('messageAck', { messageId: message.id, status: 'delivered' });

    // Send push to other participants (e.g., advisor)
    const caseRecord = await this.casesService.findOne(data.caseId);
    if (caseRecord?.userId && caseRecord.userId !== userId) {
      await this.pushService.sendToUser(
        caseRecord.userId,
        'Nouveau message',
        data.body.substring(0, 100),
        { type: 'case_message', caseId: data.caseId },
      );
    }
  }

  @SubscribeMessage('typing')
  handleTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { caseId: string; isTyping: boolean },
  ) {
    const room = `case:${data.caseId}`;
    client.to(room).emit('typing', {
      userId: client.data.userId,
      isTyping: data.isTyping,
    });
  }

  emitCaseUpdated(caseId: string, payload: Record<string, unknown>) {
    this.server.to(`case:${caseId}`).emit('caseUpdated', payload);
  }

  emitCaseMessage(caseId: string, payload: Record<string, unknown>) {
    this.server.to(`case:${caseId}`).emit('message', payload);
  }
}
