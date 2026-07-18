import type { Socket } from 'socket.io';

import type { SupabaseAuthService } from '../auth/supabase-auth.service';
import type { OneSignalSenderService } from '../notifications/onesignal-sender.service';
import { CaseMessagingGateway } from './case-messaging.gateway';
import type { CasesService } from './cases.service';

describe('CaseMessagingGateway handshake security', () => {
  const verifyAndResolve = jest.fn();
  const gateway = new CaseMessagingGateway(
    { verifyAndResolve } as unknown as SupabaseAuthService,
    {} as CasesService,
    {} as OneSignalSenderService,
  );

  beforeEach(() => jest.clearAllMocks());

  it('uses handshake auth and the canonical profile name', async () => {
    verifyAndResolve.mockResolvedValue({
      id: 'student-1',
      email: 'student@example.test',
      fullName: 'Aïcha Étudiante',
      role: 'student',
      accountType: 'student',
    });
    const client = {
      handshake: {
        auth: { token: 'verified-token' },
        query: { fullName: 'Conseiller KPB' },
      },
      data: {},
      disconnect: jest.fn(),
    } as unknown as Socket;

    await gateway.handleConnection(client);

    expect(verifyAndResolve).toHaveBeenCalledWith('verified-token');
    expect(client.data).toMatchObject({
      userId: 'student-1',
      role: 'student',
      fullName: 'Aïcha Étudiante',
    });
    expect(client.data).not.toHaveProperty('email');
    expect(client.disconnect).not.toHaveBeenCalled();
  });

  it('rejects legacy query-string bearer tokens', async () => {
    const client = {
      handshake: { auth: {}, query: { token: 'must-not-be-accepted' } },
      data: {},
      disconnect: jest.fn(),
    } as unknown as Socket;

    await gateway.handleConnection(client);

    expect(verifyAndResolve).not.toHaveBeenCalled();
    expect(client.disconnect).toHaveBeenCalled();
  });
});
