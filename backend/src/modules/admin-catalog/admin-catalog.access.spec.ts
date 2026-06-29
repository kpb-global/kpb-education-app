import 'reflect-metadata';

import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import type { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { AdminCatalogController } from './admin-catalog.controller';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';

function contextForRole(role?: string): ExecutionContext {
  return {
    getHandler: () => AdminCatalogController.prototype.createProgram,
    getClass: () => AdminCatalogController,
    switchToHttp: () => ({
      getRequest: () => ({ adminUser: role ? { role } : undefined }),
    }),
  } as unknown as ExecutionContext;
}

describe('AdminCatalogController access control', () => {
  const reflector = new Reflector();
  const guard = new RolesGuard(reflector);

  it('is protected by the admin auth + roles guards', () => {
    const guards =
      (Reflect.getMetadata('__guards__', AdminCatalogController) as unknown[]) ??
      [];
    expect(guards).toEqual(
      expect.arrayContaining([AdminAuthGuard, RolesGuard]),
    );
  });

  it('restricts writes to Admin, SuperAdmin and ContentManager', () => {
    const roles = reflector.getAllAndOverride<InternalRole[]>(ROLES_KEY, [
      AdminCatalogController.prototype.createProgram,
      AdminCatalogController,
    ]);
    expect(roles).toEqual([
      InternalRole.Admin,
      InternalRole.SuperAdmin,
      InternalRole.ContentManager,
    ]);
  });

  it('allows a content manager', () => {
    expect(
      guard.canActivate(contextForRole(InternalRole.ContentManager)),
    ).toBe(true);
  });

  it('forbids a counselor', () => {
    expect(() =>
      guard.canActivate(contextForRole(InternalRole.Counselor)),
    ).toThrow(ForbiddenException);
  });

  it('rejects an unauthenticated request', () => {
    expect(() => guard.canActivate(contextForRole(undefined))).toThrow(
      UnauthorizedException,
    );
  });
});
