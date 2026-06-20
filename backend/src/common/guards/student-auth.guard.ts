import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';

import {
  SupabaseAuthService,
  SupabaseTokenUser,
} from '../../modules/auth/supabase-auth.service';

/**
 * Authenticates student/parent requests with a Supabase Auth access token.
 *
 * The token is verified (JWKS or HS256) and mapped to a local UserProfile.
 * The resolved user is attached as `request.studentUser` — the same contract
 * the legacy home-grown guard exposed — so downstream controllers are
 * unchanged.
 */
@Injectable()
export class StudentAuthGuard implements CanActivate {
  constructor(private readonly supabaseAuthService: SupabaseAuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const header = request.headers?.authorization as string | undefined;

    if (!header || !header.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing authorization token.');
    }

    const token = header.slice(7);
    const user: SupabaseTokenUser =
      await this.supabaseAuthService.verifyAndResolve(token);

    request.studentUser = user;
    return true;
  }
}
