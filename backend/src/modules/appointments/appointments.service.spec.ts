import { NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { AppointmentsService } from './appointments.service';

describe('AppointmentsService ownership', () => {
  const execute = jest.fn();
  const prisma = {
    isEnabled: true,
    execute,
  } as unknown as PrismaService;
  const service = new AppointmentsService(prisma);
  const input = {
    caseId: 'case-1',
    title: 'Préparer mon dossier',
    scheduledAt: '2026-08-01T09:00:00.000Z',
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('creates an appointment only after resolving the case for the owner', async () => {
    execute
      .mockImplementationOnce(async (callback) =>
        callback({
          case: { findFirst: jest.fn().mockResolvedValue({ id: 'case-1' }) },
        }),
      )
      .mockImplementationOnce(async (callback) =>
        callback({
          appointment: {
            create: jest.fn().mockResolvedValue({
              id: 'appointment-1',
              caseId: 'case-1',
              title: input.title,
              startsAt: new Date(input.scheduledAt),
              contactMethod: 'in_app',
              notes: null,
            }),
          },
        }),
      );

    await expect(service.create(input, 'student-1')).resolves.toMatchObject({
      id: 'appointment-1',
      caseId: 'case-1',
    });

    const ownershipQuery = execute.mock.calls[0][0];
    const findFirst = jest.fn().mockResolvedValue({ id: 'case-1' });
    await ownershipQuery({ case: { findFirst } });
    expect(findFirst).toHaveBeenCalledWith({
      where: { id: 'case-1', userId: 'student-1' },
      select: { id: true },
    });
  });

  it('hides a missing or foreign case and never creates the appointment', async () => {
    execute.mockImplementationOnce(async (callback) =>
      callback({ case: { findFirst: jest.fn().mockResolvedValue(null) } }),
    );

    await expect(service.create(input, 'student-2')).rejects.toThrow(
      NotFoundException,
    );
    expect(execute).toHaveBeenCalledTimes(1);
  });
});
