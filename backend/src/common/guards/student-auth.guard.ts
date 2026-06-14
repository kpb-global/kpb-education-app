import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';

import { StudentAuthService, StudentTokenUser } from '../../modules/auth/student-auth.service';

@Injectable()
export class StudentAuthGuard implements CanActivate {
  constructor(private readonly studentAuthService: StudentAuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const header = request.headers?.authorization as string | undefined;

    if (!header || !header.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing authorization token.');
    }

    const token = header.slice(7);
    const user: StudentTokenUser =
      await this.studentAuthService.verifyAccessToken(token);

    request.studentUser = user;
    return true;
  }
}
