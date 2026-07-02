import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';

import { ADMIN_ACCESS_COOKIE, readCookie } from '../../modules/auth/admin-cookies';
import { AuthService } from '../../modules/auth/auth.service';

@Injectable()
export class AdminAuthGuard implements CanActivate {
  constructor(private readonly authService: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{
      headers: Record<string, string | undefined>;
      adminUser?: unknown;
    }>();

    // Prefer the httpOnly session cookie; fall back to a Bearer header for
    // non-browser clients (scripts, tests).
    const authorization = request.headers.authorization;
    const token =
      readCookie(request.headers.cookie, ADMIN_ACCESS_COOKIE) ??
      (authorization?.startsWith('Bearer ')
        ? authorization.slice('Bearer '.length)
        : undefined);

    if (!token) {
      throw new UnauthorizedException('Missing admin authorization token.');
    }

    request.adminUser = await this.authService.verifyToken(token);

    return true;
  }
}
