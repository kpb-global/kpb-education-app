import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { ROLES_KEY } from '../decorators/roles.decorator';
import { InternalRole } from '../enums/internal-role.enum';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<InternalRole[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredRoles?.length) {
      return true;
    }

    const request = context.switchToHttp().getRequest<{ adminUser?: { role?: string } }>();
    const role = request.adminUser?.role;

    if (!role) {
      throw new UnauthorizedException('Admin session required.');
    }

    if (!requiredRoles.includes(role as InternalRole)) {
      throw new ForbiddenException('This action is not allowed for your role.');
    }

    return true;
  }
}
