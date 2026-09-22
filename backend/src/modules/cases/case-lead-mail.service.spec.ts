import { CampaignMailService } from '../notifications/campaign-mail.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  CaseLeadMailService,
  CaseLeadRecord,
  COMMERCIAL_LEAD_RECIPIENTS,
} from './case-lead-mail.service';

const lead: CaseLeadRecord = {
  id: 'case-1',
  referenceCode: 'KPB-2026-042',
  type: 'application_support',
  title: 'Inscription ECE Lyon',
  description: 'Je veux un bachelor en France.',
  contextLabel: 'France · Bachelor',
  preferredContactMethod: 'whatsapp',
  assignedAdvisorName: 'Jojo',
  createdAt: new Date('2026-09-21T19:22:00.000Z'),
  user: {
    fullName: 'Awa Diallo',
    email: 'awa@example.com',
    phone: '+22790000099',
    whatsApp: '+22790000098',
    countryOfResidence: 'NE',
    preferredLanguage: 'fr',
    currentLevel: 'Terminale',
    targetLevel: 'Licence',
    accountType: 'student',
    guardianName: null,
    guardianContact: null,
  },
};

function makeService(
  counsellors: Array<{ id: string; email: string; isActive: boolean }> = [],
) {
  const send = jest.fn().mockResolvedValue(true);
  const prisma = {
    tryExecute: async (operation: (client: unknown) => Promise<unknown>) =>
      operation({
        counsellor: { findMany: async () => counsellors },
      }),
  } as unknown as PrismaService;
  const mail = {
    isEnabled: true,
    send,
  } as unknown as CampaignMailService;
  return { service: new CaseLeadMailService(prisma, mail), send };
}

describe('CaseLeadMailService', () => {
  it('emails Jojo and Richard the student contact sheet', async () => {
    const { service, send } = makeService();

    await service.notifyNewCase(lead);

    expect(send.mock.calls.map((call) => call[0])).toEqual(
      COMMERCIAL_LEAD_RECIPIENTS.map((item) => item.email),
    );
    const [, subject, text, options] = send.mock.calls[0];
    expect(subject).toBe('Nouveau dossier KPB-2026-042 — Awa Diallo');
    expect(text).toContain('Awa Diallo');
    expect(text).toContain('awa@example.com');
    expect(text).toContain('+22790000099');
    expect(text).toContain('+22790000098');
    expect(text).toContain('Inscription école');
    expect(text).toContain('WhatsApp');
    expect(text).toContain('Je veux un bachelor en France.');
    expect(options).toEqual({ replyTo: 'awa@example.com' });
  });

  it('uses the email stored on an active counsellor row', async () => {
    const { service, send } = makeService([
      {
        id: 'counsellor-jojo',
        email: 'jojo.actuel@kpb-education.com',
        isActive: true,
      },
    ]);

    await service.notifyNewCase(lead);

    expect(send.mock.calls.map((call) => call[0])).toEqual([
      'jojo.actuel@kpb-education.com',
      'richardahogle@gmail.com',
    ]);
  });

  it('skips a counsellor who was deactivated', async () => {
    const { service, send } = makeService([
      {
        id: 'counsellor-richard',
        email: 'richardahogle@gmail.com',
        isActive: false,
      },
    ]);

    await service.notifyNewCase(lead);

    expect(send.mock.calls.map((call) => call[0])).toEqual([
      'josphandieuaimeagbessi@gmail.com',
    ]);
    expect(send.mock.calls.map((call) => call[0])).not.toContain(
      'bokod246@gmail.com',
    );
  });

  it('does not email a trust-and-safety report', async () => {
    const { service, send } = makeService();

    await service.notifyNewCase({
      ...lead,
      description: 'TRUST_AND_SAFETY_REPORT\nSurface: coach',
    });

    expect(send).not.toHaveBeenCalled();
  });

  it('does not send when the email provider is off', async () => {
    const send = jest.fn();
    const service = new CaseLeadMailService(
      { tryExecute: async () => [] } as unknown as PrismaService,
      { isEnabled: false, send } as unknown as CampaignMailService,
    );

    await service.notifyNewCase(lead);

    expect(send).not.toHaveBeenCalled();
  });

  it('keeps going when one recipient send throws', async () => {
    const send = jest
      .fn()
      .mockRejectedValueOnce(new Error('network down'))
      .mockResolvedValue(true);
    const service = new CaseLeadMailService(
      {
        tryExecute: async () => [],
      } as unknown as PrismaService,
      { isEnabled: true, send } as unknown as CampaignMailService,
    );

    await expect(service.notifyNewCase(lead)).resolves.toBeUndefined();
    expect(send).toHaveBeenCalledTimes(2);
  });

  it('includes the guardian contact when the student declared one', async () => {
    const { service, send } = makeService();

    await service.notifyNewCase({
      ...lead,
      user: {
        ...lead.user,
        guardianName: 'Mariam Diallo',
        guardianContact: '+22791111111',
      },
    });

    const text = send.mock.calls[0][2] as string;
    expect(text).toContain('Mariam Diallo');
    expect(text).toContain('+22791111111');
  });
});
