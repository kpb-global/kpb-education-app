import { Injectable, NotFoundException } from '@nestjs/common';

import { mockAdminData } from '../../common/data/mock-admin';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { PrismaService } from '../prisma/prisma.service';

type AdminUserRecord = (typeof mockAdminData.adminUsers)[number];

@Injectable()
export class AdminUsersService {
  constructor(private readonly prismaService: PrismaService) {}

  private readonly users = [...mockAdminData.adminUsers];

  async listUsers() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.adminUser.findMany({
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items) {
      return {
        items: items.map((item) => ({
          id: item.id,
          fullName: item.fullName,
          email: item.email,
          role: item.role,
          isActive: item.isActive,
          languageScope: item.languageScope,
          workload: item.workload,
        })),
      };
    }

    return { items: this.users };
  }

  async findActiveUserByEmail(email: string) {
    const dbUser = await this.prismaService.execute((prisma) =>
      prisma.adminUser.findFirst({
        where: {
          email: { equals: email, mode: 'insensitive' },
          isActive: true,
        },
      }),
    );

    if (dbUser) {
      return {
        id: dbUser.id,
        fullName: dbUser.fullName,
        email: dbUser.email,
        role: dbUser.role,
        isActive: dbUser.isActive,
        languageScope: dbUser.languageScope,
        workload: dbUser.workload,
      };
    }

    return this.users.find(
      (user) =>
        user.email.toLowerCase() === email.toLowerCase() && user.isActive,
    );
  }

  async createUser(input: Record<string, unknown>) {
    const record: AdminUserRecord = {
      id: `admin-user-${Date.now()}`,
      fullName: (input['fullName'] as string | undefined) ?? 'New operator',
      email: (input['email'] as string | undefined) ?? 'new@kpb.education',
      role:
        (input['role'] as AdminUserRecord['role'] | undefined) ??
        InternalRole.Counselor,
      isActive: (input['isActive'] as boolean | undefined) ?? true,
      languageScope: (input['languageScope'] as string[] | undefined) ?? ['fr'],
      workload: (input['workload'] as number | undefined) ?? 0,
    };

    const created = await this.prismaService.execute((prisma) =>
      prisma.adminUser.create({
        data: {
          fullName: record.fullName,
          email: record.email,
          role: record.role,
          isActive: record.isActive,
          languageScope: record.languageScope,
          workload: record.workload,
        },
      }),
    );

    if (created) {
      return {
        id: created.id,
        fullName: created.fullName,
        email: created.email,
        role: created.role,
        isActive: created.isActive,
        languageScope: created.languageScope,
        workload: created.workload,
      };
    }

    this.users.unshift(record);
    return record;
  }

  async updateUser(id: string, input: Record<string, unknown>) {
    const updated = await this.prismaService.execute((prisma) =>
      prisma.adminUser.update({
        where: { id },
        data: {
          ...(input['role'] ? { role: input['role'] as InternalRole } : {}),
          ...(input['isActive'] !== undefined
            ? { isActive: input['isActive'] as boolean }
            : {}),
          ...(input['workload'] !== undefined
            ? { workload: input['workload'] as number }
            : {}),
          ...(input['languageScope']
            ? { languageScope: input['languageScope'] as string[] }
            : {}),
        },
      }),
    );

    if (updated) {
      return {
        id: updated.id,
        fullName: updated.fullName,
        email: updated.email,
        role: updated.role,
        isActive: updated.isActive,
        languageScope: updated.languageScope,
        workload: updated.workload,
      };
    }

    const index = this.users.findIndex((item) => item.id === id);
    if (index < 0) {
      throw new NotFoundException(`Admin user ${id} not found.`);
    }
    this.users[index] = {
      ...this.users[index],
      ...input,
    } as AdminUserRecord;
    return this.users[index];
  }
}
