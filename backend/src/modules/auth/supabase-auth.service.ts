import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createPublicKey } from 'crypto';
import type { JsonWebKey as CryptoJsonWebKey } from 'crypto';

import { PrismaService } from '../prisma/prisma.service';
import type { AccountType } from '@prisma/client';

/// Shape attached to `request.studentUser` by the guard. Kept identical to the
/// legacy `StudentTokenUser` contract so the ~13 student-facing controllers
/// need no changes.
export interface SupabaseTokenUser {
  id: string;
  email: string;
  role: 'student';
}

interface Jwk {
  kid?: string;
  kty: string;
  [key: string]: unknown;
}

const JWKS_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes
const SUPABASE_ROLE_TO_ACCOUNT: Record<string, AccountType> = {
  student: 'student',
  parent: 'parent',
  partner: 'partner',
  // `commercial` is an internal staff role, never provisioned here as a
  // student profile; commercial users authenticate through the admin path.
};

/**
 * Verifies Supabase Auth access tokens and maps them to a local UserProfile.
 *
 * Supports both signing schemes:
 *  - Asymmetric (ES256/RS256) via the project JWKS endpoint (default for new
 *    projects). Public keys are fetched on demand and cached.
 *  - Symmetric (HS256) via `SUPABASE_JWT_SECRET` (legacy projects). When the
 *    secret is set it takes precedence.
 *
 * Business data stays in Postgres/Prisma — Supabase is used for auth only.
 */
@Injectable()
export class SupabaseAuthService {
  private readonly supabaseUrl = (
    process.env.SUPABASE_URL ?? ''
  ).replace(/\/+$/, '');
  private readonly jwtSecret = process.env.SUPABASE_JWT_SECRET;

  private jwksCache: { keys: Jwk[]; fetchedAt: number } | null = null;

  constructor(
    private readonly prismaService: PrismaService,
    private readonly jwtService: JwtService,
  ) {
    // Fail loud at boot rather than silently 401-ing every student/parent
    // request: SUPABASE_URL is required for both the JWKS and HS256 (issuer) paths.
    if (process.env.NODE_ENV === 'production' && !this.supabaseUrl) {
      throw new Error(
        'SUPABASE_URL must be set in production — student/parent authentication depends on it.',
      );
    }
  }

  private get issuer(): string {
    return `${this.supabaseUrl}/auth/v1`;
  }

  /** Verifies the token signature/claims and resolves the local profile. */
  async verifyAndResolve(token: string): Promise<SupabaseTokenUser> {
    if (!this.supabaseUrl && !this.jwtSecret) {
      throw new UnauthorizedException('Supabase auth is not configured.');
    }

    const payload = await this.verifyToken(token);

    const sub = typeof payload.sub === 'string' ? payload.sub : undefined;
    const email =
      typeof payload.email === 'string'
        ? payload.email.trim().toLowerCase()
        : undefined;
    if (!sub || !email) {
      throw new UnauthorizedException('Token missing subject or email.');
    }

    const role = this.extractRole(payload);
    const profileId = await this.resolveProfileId({ sub, email, role });

    return { id: profileId, email, role: 'student' };
  }

  // ── Signature verification ──────────────────────────────────────────────

  private async verifyToken(
    token: string,
  ): Promise<Record<string, unknown>> {
    const verifyOptions = {
      issuer: this.issuer,
      audience: 'authenticated',
    } as const;

    try {
      if (this.jwtSecret) {
        return this.jwtService.verify(token, {
          secret: this.jwtSecret,
          algorithms: ['HS256'],
          ...verifyOptions,
        });
      }

      const pem = await this.resolveSigningKey(token);
      return this.jwtService.verify(token, {
        publicKey: pem,
        algorithms: ['ES256', 'RS256'],
        ...verifyOptions,
      });
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('Invalid or expired access token.');
    }
  }

  private async resolveSigningKey(token: string): Promise<string> {
    const kid = this.decodeHeader(token).kid;
    let jwk = await this.findJwk(kid);
    if (!jwk) {
      // Key may have rotated since last fetch — force a refresh once.
      this.jwksCache = null;
      jwk = await this.findJwk(kid);
    }
    if (!jwk) {
      throw new UnauthorizedException('No matching signing key for token.');
    }
    return createPublicKey({ key: jwk as unknown as CryptoJsonWebKey, format: 'jwk' })
      .export({ type: 'spki', format: 'pem' })
      .toString();
  }

  private decodeHeader(token: string): { kid?: string; alg?: string } {
    const segment = token.split('.')[0];
    if (!segment) throw new UnauthorizedException('Malformed token.');
    try {
      return JSON.parse(
        Buffer.from(segment, 'base64url').toString('utf8'),
      );
    } catch {
      throw new UnauthorizedException('Malformed token header.');
    }
  }

  private async findJwk(kid?: string): Promise<Jwk | undefined> {
    const keys = await this.getJwks();
    if (!kid) return keys[0];
    return keys.find((k) => k.kid === kid) ?? undefined;
  }

  private async getJwks(): Promise<Jwk[]> {
    const now = Date.now();
    if (this.jwksCache && now - this.jwksCache.fetchedAt < JWKS_CACHE_TTL_MS) {
      return this.jwksCache.keys;
    }
    const res = await fetch(
      `${this.supabaseUrl}/auth/v1/.well-known/jwks.json`,
    );
    if (!res.ok) {
      throw new UnauthorizedException('Unable to fetch signing keys.');
    }
    const body = (await res.json()) as { keys?: Jwk[] };
    const keys = body.keys ?? [];
    this.jwksCache = { keys, fetchedAt: now };
    return keys;
  }

  // ── Profile mapping (provision-on-first-login) ───────────────────────────

  private extractRole(payload: Record<string, unknown>): AccountType {
    const appMeta = payload.app_metadata as
      | { role?: unknown }
      | undefined;
    const raw =
      typeof appMeta?.role === 'string' ? appMeta.role.toLowerCase() : '';
    return SUPABASE_ROLE_TO_ACCOUNT[raw] ?? 'student';
  }

  private async resolveProfileId(input: {
    sub: string;
    email: string;
    role: AccountType;
  }): Promise<string> {
    const { sub, email, role } = input;

    const byId = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({
        where: { supabaseUserId: sub },
        select: { id: true },
      }),
    );
    if (byId) return byId.id;

    // Link an existing (legacy) profile that shares the email, then stamp it
    // with the Supabase id so future lookups hit the fast path above.
    const byEmail = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({
        where: { email },
        select: { id: true, supabaseUserId: true },
      }),
    );
    if (byEmail) {
      if (!byEmail.supabaseUserId) {
        await this.prismaService.tryExecute((prisma) =>
          prisma.userProfile.update({
            where: { id: byEmail.id },
            data: { supabaseUserId: sub },
          }),
        );
      }
      return byEmail.id;
    }

    const displayName =
      email.split('@')[0]?.replace(/[._-]+/g, ' ').trim() || 'Utilisateur';
    const created = await this.prismaService.execute((prisma) =>
      prisma.userProfile.create({
        data: {
          supabaseUserId: sub,
          accountType: role,
          fullName: displayName.slice(0, 80),
          email,
          phone: '',
          countryOfResidence: '',
          preferredLanguage: 'fr',
        },
        select: { id: true },
      }),
    );
    if (!created) {
      throw new UnauthorizedException('Database unavailable.');
    }
    return created.id;
  }
}
