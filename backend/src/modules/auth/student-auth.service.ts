import {
  ConflictException,
  Injectable,
  UnauthorizedException,
  HttpException,
  HttpStatus,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';

import { PrismaService } from '../prisma/prisma.service';
import { MagicLinkMailService } from './magic-link-mail.service';

export interface StudentTokenUser {
  id: string;
  email: string;
  role: 'student';
}

// ── In-memory login attempt tracker ──────────────────────────────────────────
// In production, use Redis for multi-instance support.
interface LoginAttempt {
  count: number;
  firstAttemptAt: number;
}

const LOGIN_MAX_ATTEMPTS = 5;
const LOGIN_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const MAGIC_LINK_TTL_MS = 15 * 60 * 1000;
const MAGIC_LINK_RESEND_COOLDOWN_MS = 60 * 1000;

@Injectable()
export class StudentAuthService {
  private readonly refreshSecret = (() => {
    const env = process.env.KPB_JWT_REFRESH_SECRET;
    if (!env && process.env.NODE_ENV === 'production') {
      throw new Error('KPB_JWT_REFRESH_SECRET must be set in production');
    }
    return env ?? 'kpb-refresh-dev';
  })();

  private readonly loginAttempts = new Map<string, LoginAttempt>();
  private readonly magicLinkCooldown = new Map<string, number>();

  constructor(
    private readonly prismaService: PrismaService,
    private readonly jwtService: JwtService,
    private readonly magicLinkMailService: MagicLinkMailService,
  ) {}

  async register(input: {
    email: string;
    password: string;
    fullName: string;
    phone?: string;
    countryOfResidence?: string;
    preferredLanguage?: string;
  }) {
    // Normalize email to prevent duplicate accounts
    const normalizedEmail = input.email.trim().toLowerCase();

    const existing = await this.prismaService.execute((prisma) =>
      prisma.studentCredential.findUnique({ where: { email: normalizedEmail } }),
    );
    if (existing) {
      throw new ConflictException('An account with this email already exists.');
    }

    const passwordHash = await bcrypt.hash(input.password, 12);

    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const profile = await tx.userProfile.create({
          data: {
            accountType: 'student',
            fullName: input.fullName.trim(),
            email: normalizedEmail,
            phone: input.phone ?? '',
            countryOfResidence: input.countryOfResidence ?? '',
            preferredLanguage: input.preferredLanguage ?? 'fr',
          },
        });

        await tx.studentCredential.create({
          data: {
            userProfileId: profile.id,
            email: normalizedEmail,
            passwordHash,
          },
        });

        return profile;
      }),
    );

    if (!result) {
      throw new Error('Database unavailable.');
    }

    return this.issueTokens({ id: result.id, email: result.email });
  }

  async login(email: string, password: string) {
    const normalizedEmail = email.trim().toLowerCase();

    // ── Brute-force check ──────────────────────────────────────
    this.checkLoginAttempts(normalizedEmail);

    const credential = await this.prismaService.execute((prisma) =>
      prisma.studentCredential.findUnique({
        where: { email: normalizedEmail },
        include: { userProfile: true },
      }),
    );

    if (!credential) {
      this.recordFailedAttempt(normalizedEmail);
      throw new UnauthorizedException('Invalid email or password.');
    }

    const valid = await bcrypt.compare(password, credential.passwordHash);
    if (!valid) {
      this.recordFailedAttempt(normalizedEmail);
      throw new UnauthorizedException('Invalid email or password.');
    }

    // Reset attempts on successful login
    this.loginAttempts.delete(normalizedEmail);

    return this.issueTokens({
      id: credential.userProfile.id,
      email: credential.email,
    });
  }

  async refresh(refreshToken: string) {
    let payload: { sub: string; type: string };
    try {
      payload = this.jwtService.verify(refreshToken, {
        secret: this.refreshSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token.');
    }

    if (payload.type !== 'refresh') {
      throw new UnauthorizedException('Invalid token type.');
    }

    const credential = await this.prismaService.execute((prisma) =>
      prisma.studentCredential.findFirst({
        where: { userProfileId: payload.sub },
        include: { userProfile: true },
      }),
    );
    if (!credential || !credential.refreshToken) {
      throw new UnauthorizedException('Session expired.');
    }

    const valid = await bcrypt.compare(refreshToken, credential.refreshToken);
    if (!valid) {
      // Reuse detection: a token that verifies cryptographically but no longer
      // matches the stored hash is evidence of theft or replay. Revoke the
      // whole session to force re-authentication.
      await this.prismaService.tryExecute((prisma) =>
        prisma.studentCredential.update({
          where: { id: credential.id },
          data: { refreshToken: null },
        }),
      );
      throw new UnauthorizedException('Refresh token revoked.');
    }

    // Atomic rotation: invalidate the presented token before issuing a new
    // one, gated on the exact stored hash. Two concurrent refreshes with the
    // same token both pass the compare above, but only the first wins this
    // conditional update (count === 1); the loser is rejected, preserving
    // single-use semantics and reuse detection.
    const rotated = await this.prismaService.execute((prisma) =>
      prisma.studentCredential.updateMany({
        where: { id: credential.id, refreshToken: credential.refreshToken },
        data: { refreshToken: null },
      }),
    );
    if (!rotated || rotated.count === 0) {
      throw new UnauthorizedException('Refresh token already used.');
    }

    return this.issueTokens({
      id: credential.userProfile.id,
      email: credential.email,
    });
  }

  async logout(userProfileId: string): Promise<void> {
    await this.prismaService.tryExecute((prisma) =>
      prisma.studentCredential.updateMany({
        where: { userProfileId },
        data: { refreshToken: null },
      }),
    );
  }

  async verifyAccessToken(token: string): Promise<StudentTokenUser> {
    try {
      const payload = this.jwtService.verify(token);
      return { id: payload.sub, email: payload.email, role: 'student' };
    } catch {
      throw new UnauthorizedException('Invalid or expired access token.');
    }
  }

  async requestMagicLink(email: string) {
    const normalizedEmail = email.trim().toLowerCase();
    const now = Date.now();
    const lastSent = this.magicLinkCooldown.get(normalizedEmail);
    if (lastSent != null && now - lastSent < MAGIC_LINK_RESEND_COOLDOWN_MS) {
      const secondsLeft = Math.ceil(
        (MAGIC_LINK_RESEND_COOLDOWN_MS - (now - lastSent)) / 1000,
      );
      throw new HttpException(
        `Veuillez patienter ${secondsLeft}s avant de renvoyer un code.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const recordId = randomBytes(12).toString('hex');
    const secret = randomBytes(24).toString('hex');
    const token = `${recordId}.${secret}`;
    const code = String(Math.floor(100000 + Math.random() * 900000));
    const tokenHash = await bcrypt.hash(secret, 10);
    const codeHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(now + MAGIC_LINK_TTL_MS);

    await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await tx.magicLinkToken.deleteMany({
          where: {
            email: normalizedEmail,
            OR: [{ usedAt: { not: null } }, { expiresAt: { lt: new Date() } }],
          },
        });
        await tx.magicLinkToken.create({
          data: {
            id: recordId,
            email: normalizedEmail,
            tokenHash,
            codeHash,
            expiresAt,
          },
        });
      }),
    );

    await this.magicLinkMailService.sendMagicLink(normalizedEmail, {
      token,
      code,
    });
    this.magicLinkCooldown.set(normalizedEmail, now);

    const isDev = process.env.NODE_ENV !== 'production';
    return {
      message: 'Magic link sent.',
      expiresInSeconds: MAGIC_LINK_TTL_MS / 1000,
      email: normalizedEmail,
      ...(isDev ? { devCode: code, devToken: token } : {}),
    };
  }

  async verifyMagicLink(input: {
    token?: string;
    email?: string;
    code?: string;
  }) {
    const record = await this.resolveMagicLinkRecord(input);
    if (!record) {
      throw new UnauthorizedException('Code ou lien invalide ou expiré.');
    }

    if (record.usedAt || record.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException('Code ou lien invalide ou expiré.');
    }

    const normalizedEmail = record.email;
    let userId: string;

    const existing = await this.prismaService.execute((prisma) =>
      prisma.studentCredential.findUnique({
        where: { email: normalizedEmail },
        include: { userProfile: true },
      }),
    );

    if (existing) {
      userId = existing.userProfile.id;
    } else {
      const placeholderPassword = await bcrypt.hash(
        randomBytes(32).toString('hex'),
        12,
      );
      const displayName =
        normalizedEmail.split('@')[0]?.replace(/[._-]+/g, ' ').trim() ||
        'Utilisateur';

      const created = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const profile = await tx.userProfile.create({
            data: {
              accountType: 'student',
              fullName: displayName.slice(0, 80),
              email: normalizedEmail,
              phone: '',
              countryOfResidence: '',
              preferredLanguage: 'fr',
            },
          });
          await tx.studentCredential.create({
            data: {
              userProfileId: profile.id,
              email: normalizedEmail,
              passwordHash: placeholderPassword,
            },
          });
          return profile;
        }),
      );
      if (!created) {
        throw new Error('Database unavailable.');
      }
      userId = created.id;
    }

    await this.prismaService.execute((prisma) =>
      prisma.magicLinkToken.update({
        where: { id: record.id },
        data: { usedAt: new Date() },
      }),
    );

    return this.issueTokens({ id: userId, email: normalizedEmail });
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private checkLoginAttempts(email: string): void {
    const attempt = this.loginAttempts.get(email);
    if (!attempt) return;

    const elapsed = Date.now() - attempt.firstAttemptAt;
    if (elapsed > LOGIN_WINDOW_MS) {
      // Window expired, reset
      this.loginAttempts.delete(email);
      return;
    }

    if (attempt.count >= LOGIN_MAX_ATTEMPTS) {
      const minutesLeft = Math.ceil((LOGIN_WINDOW_MS - elapsed) / 60000);
      throw new HttpException(
        `Trop de tentatives de connexion. Réessayez dans ${minutesLeft} minute(s).`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private recordFailedAttempt(email: string): void {
    const attempt = this.loginAttempts.get(email);
    if (!attempt || Date.now() - attempt.firstAttemptAt > LOGIN_WINDOW_MS) {
      this.loginAttempts.set(email, { count: 1, firstAttemptAt: Date.now() });
    } else {
      attempt.count++;
    }
  }

  private async resolveMagicLinkRecord(input: {
    token?: string;
    email?: string;
    code?: string;
  }) {
    if (input.token?.trim()) {
      const [recordId, secret] = input.token.trim().split('.', 2);
      if (!recordId || !secret) {
        throw new BadRequestException('Invalid magic link token format.');
      }
      const record = await this.prismaService.execute((prisma) =>
        prisma.magicLinkToken.findUnique({ where: { id: recordId } }),
      );
      if (!record) return null;
      const valid = await bcrypt.compare(secret, record.tokenHash);
      return valid ? record : null;
    }

    const email = input.email?.trim().toLowerCase();
    const code = input.code?.trim();
    if (!email || !code) {
      throw new BadRequestException(
        'Provide either token or email + 6-digit code.',
      );
    }

    const record = await this.prismaService.execute((prisma) =>
      prisma.magicLinkToken.findFirst({
        where: {
          email,
          usedAt: null,
          expiresAt: { gt: new Date() },
        },
        orderBy: { createdAt: 'desc' },
      }),
    );
    if (!record) return null;
    const valid = await bcrypt.compare(code, record.codeHash);
    return valid ? record : null;
  }

  private async issueTokens(user: { id: string; email: string }) {
    const accessToken = this.jwtService.sign(
      { sub: user.id, email: user.email },
      { expiresIn: '1h' },
    );

    const refreshToken = this.jwtService.sign(
      { sub: user.id, type: 'refresh' },
      { secret: this.refreshSecret, expiresIn: '7d' },
    );

    const refreshHash = await bcrypt.hash(refreshToken, 10);
    await this.prismaService.execute((prisma) =>
      prisma.studentCredential.update({
        where: { userProfileId: user.id },
        data: { refreshToken: refreshHash },
      }),
    );

    return {
      accessToken,
      refreshToken,
      user: { id: user.id, email: user.email },
    };
  }
}
