import { loadEnvFile } from 'node:process';
import { existsSync } from 'node:fs';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import * as express from 'express';

import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/http-exception.filter';

async function bootstrap() {
  // Only load .env when the file is present — in prod Docker, env is injected
  // by the container runtime and there is no .env file on disk.
  if (existsSync('.env')) {
    loadEnvFile('.env');
  }
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api');

  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));

  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  // Uploaded documents are NOT served from a public static path anymore; they
  // are streamed through the authenticated GET /cases/:id/documents/:docId/file
  // endpoint (ownership-checked). See StorageService.getObject.

  // ── Validation ─────────────────────────────────────────────────────────────
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // ── Global exception filter ─────────────────────────────────────────────
  app.useGlobalFilters(new GlobalExceptionFilter());

  // ── CORS ────────────────────────────────────────────────────────────────────
  app.enableCors({
    origin: process.env.CORS_ORIGINS?.split(',') ?? ['http://localhost:3000'],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    maxAge: 86400, // 24h preflight cache
  });

  // Run onModuleDestroy hooks (Prisma $disconnect, cron teardown) on SIGTERM/SIGINT
  // so redeploys drain in-flight work instead of being killed mid-request.
  app.enableShutdownHooks();

  const port = Number(process.env.PORT ?? 4000);
  await app.listen(port);
}

bootstrap().catch((error) => {
  // A boot failure (port in use, misconfigured module) must exit non-zero with a
  // clear log, not surface as an unhandled promise rejection.
  console.error('Fatal: application failed to start', error);
  process.exit(1);
});
