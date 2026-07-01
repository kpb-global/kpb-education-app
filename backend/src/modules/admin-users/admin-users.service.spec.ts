import { ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

import { InternalRole } from '../../common/enums/internal-role.enum';
import { PrismaService } from '../prisma/prisma.service';
import { AdminUsersService } from './admin-users.service';

/**
 * Guards KPB-85: createUser provisions a real bcrypt temp password (returned
 * once, never the hash), duplicate emails map to 409, and resetPassword rotates
 * the hash + clears the refresh token so a reset actually revokes access.
 */
describe('AdminUsersService — provisioning & revocation', () => {
  function makeService(opts: { createThrows?: unknown } = {}) {
    const created: Array<Record<string, unknown>> = [];
    const updates: Array<{ where: Record<string, unknown>; data: Record<string, unknown> }> = [];
    const client = {
      adminUser: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          if (opts.createThrows) throw opts.createThrows;
          created.push(data);
          return { id: 'au-1', ...data };
        },
        update: async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: Record<string, unknown>;
        }) => {
          updates.push({ where, data });
          return { id: where.id ?? 'au-1', email: 'existing@kpb.education', ...data };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { service: new AdminUsersService(prisma), created, updates };
  }

  it('createUser hashes a temp password, returns it once, and never leaks the hash', async () => {
    const { service, created } = makeService();
    const res = (await service.createUser({
      fullName: 'A',
      email: 'A@KPB.education',
      role: InternalRole.Counselor,
    })) as Record<string, unknown>;

    expect(typeof res.tempPassword).toBe('string');
    expect((res.tempPassword as string).length).toBeGreaterThan(8);
    expect(res.email).toBe('a@kpb.education'); // normalized to lowercase
    expect(res.passwordHash).toBeUndefined(); // response must not carry the hash

    const stored = created[0].passwordHash as string;
    expect(stored).toMatch(/^\$2[aby]\$/); // a real bcrypt hash was stored
    expect(await bcrypt.compare(res.tempPassword as string, stored)).toBe(true);
  });

  it('createUser maps a duplicate-email P2002 to ConflictException', async () => {
    const { service } = makeService({ createThrows: { code: 'P2002' } });
    await expect(
      service.createUser({
        fullName: 'A',
        email: 'dupe@kpb.education',
        role: InternalRole.Admin,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('resetPassword rotates the hash and clears the refresh token', async () => {
    const { service, updates } = makeService();
    const res = (await service.resetPassword('au-1')) as Record<string, unknown>;

    expect(typeof res.tempPassword).toBe('string');
    expect(updates).toHaveLength(1);
    expect(updates[0].data.refreshToken).toBeNull(); // revokes future refreshes
    const stored = updates[0].data.passwordHash as string;
    expect(stored).toMatch(/^\$2[aby]\$/);
    expect(await bcrypt.compare(res.tempPassword as string, stored)).toBe(true);
  });
});
