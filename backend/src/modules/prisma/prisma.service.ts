import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService implements OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);
  private readonly client: PrismaClient | null;

  constructor() {
    this.client = process.env.DATABASE_URL ? new PrismaClient() : null;
  }

  get isEnabled() {
    return this.client !== null;
  }

  /** Lightweight readiness probe used by /health/ready. */
  async isReady(): Promise<boolean> {
    if (!this.client) return false;
    try {
      await this.client.$queryRawUnsafe('SELECT 1');
      return true;
    } catch (error) {
      this.logger.warn(
        `Prisma readiness check failed: ${
          error instanceof Error ? error.message : 'Unknown error'
        }`,
      );
      return false;
    }
  }

  async execute<T>(operation: (client: PrismaClient) => Promise<T>): Promise<T | null> {
    if (!this.client) {
      return null;
    }

    try {
      return await operation(this.client);
    } catch (error) {
      this.logger.error(
        `Prisma operation failed: ${
          error instanceof Error ? error.message : 'Unknown error'
        }`,
        error instanceof Error ? error.stack : undefined,
      );
      throw error;
    }
  }

  /**
   * Like execute(), but returns null instead of throwing on database errors.
   * Use only when in-memory fallback is explicitly intended.
   */
  async tryExecute<T>(operation: (client: PrismaClient) => Promise<T>): Promise<T | null> {
    if (!this.client) {
      return null;
    }

    try {
      return await operation(this.client);
    } catch (error) {
      this.logger.warn(
        `Prisma operation failed, falling back to in-memory data: ${
          error instanceof Error ? error.message : 'Unknown error'
        }`,
      );
      return null;
    }
  }

  async onModuleDestroy() {
    await this.client?.$disconnect();
  }
}
