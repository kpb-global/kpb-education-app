import { CampaignExecutorService } from './campaign-executor.service';
import { CampaignMailService } from './campaign-mail.service';
import { OneSignalSenderService } from './onesignal-sender.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * L'exécuteur décide ce que l'admin affiche. Il n'avait aucun test, et il
 * peignait en vert des campagnes qui n'avaient rien livré : le 04/09/2026,
 * « Rentree Decalee » a trouvé 2 destinataires, en a livré 0, et s'est
 * affichée « terminée ».
 */
describe('CampaignExecutorService', () => {
  type Delivery = { channel: string; recipientId: string; status: string };

  function makeService(options: {
    channels: string[];
    template: Record<string, string> | null;
    pushOk?: boolean;
    recipients?: Array<{ id: string; preferredLanguage: string }>;
  }) {
    const recipients = options.recipients ?? [
      { id: 'u1', preferredLanguage: 'fr' },
      { id: 'u2', preferredLanguage: 'fr' },
    ];
    let deliveries: Delivery[] = [];
    const campaign = {
      id: 'c1',
      templateId: options.template ? 't1' : null,
      audienceType: 'all_users',
      filters: {},
      channels: options.channels,
      linkedCaseId: null,
      status: 'sending',
    };
    let campaignStatus = campaign.status;

    const match = (where: Record<string, unknown>) => (d: Delivery) =>
      (!where.channel || d.channel === where.channel) &&
      (!where.status || d.status === where.status) &&
      (!where.recipientId || d.recipientId === where.recipientId);

    const client = {
      notificationCampaign: {
        findUnique: async () => campaign,
        update: async ({ data }: { data: { status: string } }) => {
          campaignStatus = data.status;
          return campaign;
        },
      },
      notificationTemplate: { findUnique: async () => options.template },
      userProfile: { findMany: async () => recipients },
      notificationDelivery: {
        createMany: async ({ data }: { data: Delivery[] }) => {
          deliveries = deliveries.concat(data);
          return { count: data.length };
        },
        updateMany: async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: { status: string };
        }) => {
          const hit = deliveries.filter(match(where));
          hit.forEach((d) => (d.status = data.status));
          return { count: hit.length };
        },
        count: async ({ where }: { where?: Record<string, unknown> } = {}) =>
          deliveries.filter(match(where ?? {})).length,
      },
    };

    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
      tryExecute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;

    const push = {
      isConfigured: true,
      sendToUser: async () => options.pushOk ?? true,
    } as unknown as OneSignalSenderService;
    const mail = { isEnabled: false } as unknown as CampaignMailService;

    return {
      service: new CampaignExecutorService(prisma, push, mail),
      deliveries: () => deliveries,
      status: () => campaignStatus,
    };
  }

  const TEMPLATE = {
    titleFr: 'Titre',
    titleEn: 'Title',
    bodyFr: 'Corps',
    bodyEn: 'Body',
  };

  it('marque la campagne « completed » quand au moins un push part', async () => {
    const h = makeService({ channels: ['push'], template: TEMPLATE });
    await h.service.execute('c1');
    expect(h.status()).toBe('completed');
    expect(h.deliveries().every((d) => d.status === 'delivered')).toBe(true);
  });

  // Le défaut central : 2 destinataires, 0 livré, badge vert.
  it('marque « failed » quand tous les envois échouent', async () => {
    const h = makeService({
      channels: ['push'],
      template: TEMPLATE,
      pushOk: false,
    });
    await h.service.execute('c1');
    expect(h.status()).toBe('failed');
    expect(h.deliveries().every((d) => d.status === 'failed')).toBe(true);
  });

  // Sans modèle, les deux boucles d'envoi sont sautées : les livraisons
  // restaient « queued » à vie pendant que la campagne passait à « terminée ».
  // Or l'absence de modèle est le choix PAR DÉFAUT du formulaire admin.
  it('sans modèle, échoue franchement au lieu de laisser des envois en attente', async () => {
    const h = makeService({ channels: ['push'], template: null });
    await h.service.execute('c1');
    expect(h.deliveries().some((d) => d.status === 'queued')).toBe(false);
    expect(h.status()).toBe('failed');
  });

  // `in_app` est accepté partout et n'a aucune branche d'exécution.
  it('ne laisse pas les envois in_app en attente perpétuelle', async () => {
    const h = makeService({ channels: ['in_app'], template: TEMPLATE });
    await h.service.execute('c1');
    const inApp = h.deliveries().filter((d) => d.channel === 'in_app');
    expect(inApp.length).toBeGreaterThan(0);
    expect(inApp.every((d) => d.status === 'failed')).toBe(true);
  });

  // Une campagne partiellement livrée reste une campagne livrée.
  it('reste « completed » si une seule livraison réussit', async () => {
    let calls = 0;
    const h = makeService({ channels: ['push'], template: TEMPLATE });
    (
      h.service as unknown as { pushService: { sendToUser: () => unknown } }
    ).pushService.sendToUser = async () => ++calls === 1;
    await h.service.execute('c1');
    expect(h.status()).toBe('completed');
  });

  it('reste « completed » quand il n’y avait rien à envoyer', async () => {
    const h = makeService({
      channels: ['push'],
      template: TEMPLATE,
      recipients: [],
    });
    await h.service.execute('c1');
    expect(h.status()).toBe('completed');
  });
});
