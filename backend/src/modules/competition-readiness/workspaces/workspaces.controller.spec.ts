import type { Response } from 'express';

import type { WorkspacesService } from './workspaces.service';
import { WorkspacesController } from './workspaces.controller';

describe('WorkspacesController', () => {
  const create = jest.fn();
  const controller = new WorkspacesController({
    create,
  } as unknown as WorkspacesService);
  const input = { scholarshipId: 'scholarship-1', cycleId: 'cycle-1' };
  const request = { studentUser: { id: 'student-1' } };
  const response = {
    status: jest.fn(),
    setHeader: jest.fn(),
  } as unknown as Response;

  beforeEach(() => jest.clearAllMocks());

  it('rejects a missing Idempotency-Key with the stable contract code', async () => {
    await expect(
      controller.create(input, undefined, request, response),
    ).rejects.toMatchObject({
      status: 400,
      response: expect.objectContaining({ code: 'IDEMPOTENCY_KEY_REQUIRED' }),
    });
    expect(create).not.toHaveBeenCalled();
  });

  it('normalizes the key and preserves status and ETag from the service', async () => {
    create.mockResolvedValueOnce({
      created: true,
      statusCode: 201,
      workspace: { id: 'workspace-1', version: 1 },
    });

    await expect(
      controller.create(input, '  request-1  ', request, response),
    ).resolves.toEqual({ id: 'workspace-1', version: 1 });
    expect(create).toHaveBeenCalledWith('student-1', input, 'request-1');
    expect(response.status).toHaveBeenCalledWith(201);
    expect(response.setHeader).toHaveBeenCalledWith('ETag', 'W/"1"');
  });
});
