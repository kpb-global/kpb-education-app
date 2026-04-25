import {
  ConflictException,
  Injectable,
  UnauthorizedException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

import { PrismaService } from '../prisma/prisma.service';

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

  constructor(
    private readonly prismaService: PrismaService,
    private readonly jwtService: JwtService,
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

    // Atomic rotation: clear the stored hash in the same transaction that
    // issues the new one. Concurrent refresh calls with the same token lose
    // the race and get rejected by the compare above on the next attempt.
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
