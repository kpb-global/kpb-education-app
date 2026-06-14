import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as admin from 'firebase-admin';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FirebasePushService implements OnModuleInit {
  private readonly logger = new Logger(FirebasePushService.name);
  private initialized = false;

  constructor(private readonly prismaService: PrismaService) {}

  onModuleInit() {
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!serviceAccountJson) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT not set — push notifications disabled.',
      );
      return;
    }

    try {
      const serviceAccount = JSON.parse(serviceAccountJson);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      this.initialized = true;
      this.logger.log('Firebase Admin SDK initialized.');
    } catch (error) {
      this.logger.error('Failed to initialize Firebase Admin SDK:', error);
    }
  }

  /**
   * Sends a push to all of the user's registered devices.
   * Returns `true` only if at least one device accepted the message, so
   * callers can record an accurate delivery status (a no-op when push is
   * disabled or the user has no tokens returns `false`).
   */
  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<boolean> {
    if (!this.initialized) return false;

    const tokens = await this.prismaService.execute((prisma) =>
      prisma.deviceToken.findMany({
        where: { userProfileId: userId },
        select: { token: true, id: true },
      }),
    );

    if (!tokens || tokens.length === 0) return false;

    const message: admin.messaging.MulticastMessage = {
      tokens: tokens.map((t: { token: string }) => t.token),
      notification: { title, body },
      data: data ?? {},
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);

      const tokensToDelete: string[] = [];
      response.responses.forEach((resp, index) => {
        if (
          resp.error &&
          (resp.error.code === 'messaging/registration-token-not-registered' ||
            resp.error.code === 'messaging/invalid-registration-token')
        ) {
          tokensToDelete.push(tokens[index].id);
        }
      });

      if (tokensToDelete.length > 0) {
        await this.prismaService.execute((prisma) =>
          prisma.deviceToken.deleteMany({
            where: { id: { in: tokensToDelete } },
          }),
        );
        this.logger.log(`Cleaned up ${tokensToDelete.length} invalid tokens.`);
      }

      return response.successCount > 0;
    } catch (error) {
      this.logger.error(`Push notification failed for user ${userId}:`, error);
      return false;
    }
  }
}
