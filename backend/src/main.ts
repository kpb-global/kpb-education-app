import { loadEnvFile } from 'node:process';
import { resolve } from 'node:path';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import * as express from 'express';

import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/http-exception.filter';

async function bootstrap() {
  loadEnvFile?.('.env');
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api', { exclude: ['uploads/(.*)'] });

  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));

  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  const uploadsDir = process.env.KPB_UPLOADS_DIR
    ? resolve(process.env.KPB_UPLOADS_DIR)
    : resolve(process.cwd(), 'uploads');
  app.use('/uploads', express.static(uploadsDir, { maxAge: '1d' }));

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

  const port = Number(process.env.PORT ?? 4000);
  await app.listen(port);
}

bootstrap();
