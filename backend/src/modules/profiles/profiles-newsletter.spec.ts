import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { NewsletterSyncService } from '../newsletter/newsletter-sync.service';
import { ProfilesService } from './profiles.service';

const fakeStorage = {
  keyFromUrl: () => null,
  delete: async () => undefined,
} as unknown as StorageService;

/**
 * Newsletter consent transition (GDPR): `newsletterConsentedAt` must be
 * stamped exactly once, on the false→true flip — never rewritten when the
 * client re-sends true, and never on opt-out.
 */
describe('ProfilesService — newsletter opt-in', () => {
  function makePrisma(currentOptIn: boolean) {
    const updateData: Record<string, unknown>[] = [];
    const client = {
      userProfile: {
        findUnique: async () => ({ newsletterOptIn: currentOptIn }),
        update: async (args: { data: Record<string, unknown> }) => {
          updateData.push(args.data);
          return {
            id: 'user-1',
            accountType: 'student',
            preferredLanguage: 'fr',
            fullName: 'Test User',
            email: 't@example.test',
            phone: '',
            whatsApp: null,
            countryOfResidence: '',
            currentLevel: null,
            targetLevel: null,
            languageLevel: null,
            gradeRange: null,
            annualTuitionBudgetEur: null,
            monthlyBudgetEur: null,
            preferredCurrency: 'XOF',
            wantsScholarship: false,
            newsletterOptIn: true,
            fieldIds: [],
            targetCountryIds: [],
            availableDocuments: [],
            aiConsentedAt: null,
            birthDate: null,
            guardianName: null,
            guardianContact: null,
            guardianConsentedAt: null,
            updatedAt: new Date(),
          };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { prisma, updateData };
  }

  it('stamps newsletterConsentedAt on the false→true transition and triggers the sync', async () => {
    const { prisma, updateData } = makePrisma(false);
    const syncSpy = jest.fn().mockResolvedValue(true);
    const newsletterSync = {
      syncProfile: syncSpy,
    } as unknown as NewsletterSyncService;

    await new ProfilesService(prisma, fakeStorage, newsletterSync).updateMe(
      { scholarshipNewsletterOptIn: true },
      'user-1',
    );

    expect(updateData[0]).toMatchObject({ newsletterOptIn: true });
    expect(updateData[0].newsletterConsentedAt).toBeInstanceOf(Date);
    expect(syncSpy).toHaveBeenCalledWith('user-1');
  });

  it('does not re-stamp the consent when the flag is already true', async () => {
    const { prisma, updateData } = makePrisma(true);

    await new ProfilesService(prisma, fakeStorage).updateMe(
      { scholarshipNewsletterOptIn: true },
      'user-1',
    );

    expect(updateData[0]).toMatchObject({ newsletterOptIn: true });
    expect(updateData[0].newsletterConsentedAt).toBeUndefined();
  });

  it('records an opt-out without touching the consent timestamp', async () => {
    const { prisma, updateData } = makePrisma(true);

    await new ProfilesService(prisma, fakeStorage).updateMe(
      { scholarshipNewsletterOptIn: false },
      'user-1',
    );

    expect(updateData[0]).toMatchObject({ newsletterOptIn: false });
    expect(updateData[0].newsletterConsentedAt).toBeUndefined();
  });

  it('exposes scholarshipNewsletterOptIn in the API shape', async () => {
    const { prisma } = makePrisma(false);

    const result = (await new ProfilesService(prisma, fakeStorage).updateMe(
      { scholarshipNewsletterOptIn: true },
      'user-1',
    )) as { scholarshipNewsletterOptIn?: boolean };

    expect(result.scholarshipNewsletterOptIn).toBe(true);
  });
});
