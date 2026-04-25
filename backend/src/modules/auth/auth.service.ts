import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'crypto';

import { AdminUsersService } from '../admin-users/admin-users.service';

export interface AdminSessionUser {
  id: string;
  fullName: string;
  email: string;
  role: string;
  languageScope: string[];
}

interface AdminTokenPayload extends AdminSessionUser {
  iat: string;
}

@Injectable()
export class AuthService {
  private readonly secret = (() => {
    const env = process.env.KPB_ADMIN_TOKEN_SECRET;
    if (!env && process.env.NODE_ENV === 'production') {
      throw new Error('KPB_ADMIN_TOKEN_SECRET must be set in production');
    }
    return env ?? 'kpb-local-admin-secret';
  })();

  constructor(private readonly adminUsersService: AdminUsersService) {}

  async login(email: string) {
    const user = await this.adminUsersService.findActiveUserByEmail(email);
    if (!user) {
      throw new UnauthorizedException('Unknown or inactive admin account.');
    }

    const sessionUser = this.toSessionUser(user);
    return {
      token: this.signToken(sessionUser),
      user: sessionUser,
    };
  }

  async verifyToken(token: string): Promise<AdminSessionUser> {
    const [encodedPayload, signature] = token.split('.');
    if (!encodedPayload || !signature) {
      throw new UnauthorizedException('Malformed admin token.');
    }

    const expectedSignature = this.sign(encodedPayload);
    const incoming = Buffer.from(signature);
    const expected = Buffer.from(expectedSignature);

    if (
      incoming.length !== expected.length ||
      !timingSafeEqual(incoming, expected)
    ) {
      throw new UnauthorizedException('Invalid admin token signature.');
    }

    const payload = JSON.parse(
      Buffer.from(encodedPayload, 'base64url').toString('utf8'),
    ) as AdminTokenPayload;
    const user = await this.adminUsersService.findActiveUserByEmail(
      payload.email,
    );

    if (!user) {
      throw new UnauthorizedException('Admin account is no longer active.');
    }

    return this.toSessionUser(user);
  }

  private signToken(user: AdminSessionUser) {
    const payload: AdminTokenPayload = {
      ...user,
      iat: new Date().toISOString(),
    };
    const encodedPayload = Buffer.from(
      JSON.stringify(payload),
      'utf8',
    ).toString('base64url');

    return `${encodedPayload}.${this.sign(encodedPayload)}`;
  }

  private sign(value: string) {
    return createHmac('sha256', this.secret).update(value).digest('hex');
  }

  private toSessionUser(user: {
    id: string;
    fullName: string;
    email: string;
    role: string;
    languageScope: string[];
  }): AdminSessionUser {
    return {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      role: user.role,
      languageScope: user.languageScope,
    };
  }
}
