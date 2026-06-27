import { Injectable, Logger } from '@nestjs/common';
import type { UserProfile } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class ProfilesService {
  private readonly logger = new Logger(ProfilesService.name);

  constructor(private readonly prismaService: PrismaService) {}

  // Returned ONLY when the database is not configured. Kept readonly and never
  // mutated — a previous mutable singleton leaked one user's profile fields
  // into another user's responses (cross-tenant leak + race condition).
  private readonly demoProfile = {
    id: 'demo-user',
    accountType: 'student',
    preferredLanguage: 'fr',
    fullName: 'Aissatou Ibrahim',
    email: 'aissatou@example.com',
    phone: '+22790000000',
    whatsApp: '+22790000000',
    countryOfResidence: 'Niger',
    currentLevel: 'High school',
    targetLevel: 'Bachelor',
    languageLevel: 'Intermediate',
    fieldIds: ['computer_science', 'business'],
    targetCountryIds: ['canada', 'france'],
    gradeRange: '12 - 14/20',
    wantsScholarshipSupport: true,
    availableDocuments: ['Passport', 'Transcripts'],
    updatedAt: new Date().toISOString(),
  };

  async getMe(userId?: string) {
    const id = userId ?? 'demo-user';
    const dbProfile = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({ where: { id } }),
    );

    return dbProfile ? this.mapDbProfile(dbProfile) : this.demoProfile;
  }

  async updateMe(input: UpdateProfileDto, userId?: string) {
    const id = userId ?? 'demo-user';
    const updated = await this.prismaService.execute((prisma) =>
      prisma.userProfile.update({
        where: { id },
        data: {
          ...(input.fullName ? { fullName: input.fullName } : {}),
          ...(input.phone ? { phone: input.phone } : {}),
          ...(input.whatsApp !== undefined
            ? { whatsApp: input.whatsApp }
            : {}),
          ...(input.preferredLanguage
            ? { preferredLanguage: input.preferredLanguage }
            : {}),
          ...(input.countryOfResidence
            ? { countryOfResidence: input.countryOfResidence }
            : {}),
          ...(input.currentLevel
            ? { currentLevel: input.currentLevel }
            : {}),
          ...(input.targetLevel ? { targetLevel: input.targetLevel } : {}),
          ...(input.languageLevel
            ? { languageLevel: input.languageLevel }
            : {}),
          ...(input.gradeRange ? { gradeRange: input.gradeRange } : {}),
          ...(input.wantsScholarshipSupport !== undefined
            ? { wantsScholarship: input.wantsScholarshipSupport }
            : {}),
          ...(input.fieldIds ? { fieldIds: input.fieldIds } : {}),
          ...(input.targetCountryIds
            ? { targetCountryIds: input.targetCountryIds }
            : {}),
          ...(input.availableDocuments
            ? { availableDocuments: input.availableDocuments }
            : {}),
          ...(input.aiConsentedAt !== undefined
            ? { aiConsentedAt: new Date(input.aiConsentedAt) }
            : {}),
        },
      }),
    );

    if (updated) {
      return this.mapDbProfile(updated);
    }

    // No database: return a per-request merge of the demo profile without
    // mutating any shared state.
    return {
      ...this.demoProfile,
      ...input,
      updatedAt: new Date().toISOString(),
    };
  }

  /// GDPR / store-required account deletion. Hard-deletes every user-owned row
  /// in one transaction (FK-safe order: case children → case-referencing rows →
  /// cases → other user-owned rows → profile), then best-effort deletes the
  /// Supabase auth identity. Returns flags so the client can report honestly.
  async deleteMe(
    userId?: string,
  ): Promise<{ deleted: boolean; authIdentityRemoved: boolean }> {
    const id = userId ?? 'demo-user';

    const purged = await this.prismaService.execute(async (prisma) => {
      const profile = await prisma.userProfile.findUnique({
        where: { id },
        select: { email: true, supabaseUserId: true },
      });
      if (!profile) return null;

      const cases = await prisma.case.findMany({
        where: { userId: id },
        select: { id: true },
      });
      const caseIds = cases.map((c) => c.id);

      await prisma.$transaction([
        // Children of Case (no cascade defined).
        prisma.caseMessage.deleteMany({ where: { caseId: { in: caseIds } } }),
        prisma.caseTimelineEvent.deleteMany({
          where: { caseId: { in: caseIds } },
        }),
        prisma.caseTask.deleteMany({ where: { caseId: { in: caseIds } } }),
        prisma.caseDocument.deleteMany({ where: { caseId: { in: caseIds } } }),
        prisma.caseInternalNote.deleteMany({
          where: { caseId: { in: caseIds } },
        }),
        prisma.notificationDelivery.deleteMany({
          where: { caseId: { in: caseIds } },
        }),
        // Rows that reference Case (must precede Case).
        prisma.appointment.deleteMany({ where: { userId: id } }),
        // ServicePurchase references PaymentIntent → delete it first.
        prisma.servicePurchase.deleteMany({ where: { userId: id } }),
        prisma.paymentIntent.deleteMany({ where: { userId: id } }),
        prisma.case.deleteMany({ where: { userId: id } }),
        // Other user-owned rows.
        prisma.savedItem.deleteMany({ where: { userId: id } }),
        prisma.academyPurchase.deleteMany({ where: { userId: id } }),
        prisma.salonRegistration.deleteMany({ where: { userId: id } }),
        // CoachMessage cascades from CoachConversation (onDelete: Cascade).
        prisma.coachConversation.deleteMany({ where: { userId: id } }),
        prisma.orientationSession.deleteMany({ where: { userId: id } }),
        prisma.parentChildLink.deleteMany({
          where: { OR: [{ parentId: id }, { childId: id }] },
        }),
        prisma.deviceToken.deleteMany({ where: { userProfileId: id } }),
        prisma.partnerLead.deleteMany({ where: { userId: id } }),
        prisma.studentCredential.deleteMany({ where: { userProfileId: id } }),
        prisma.magicLinkToken.deleteMany({ where: { email: profile.email } }),
        prisma.userProfile.delete({ where: { id } }),
      ]);

      return { supabaseUserId: profile.supabaseUserId };
    });

    if (!purged) {
      // No DB (demo mode) or no such profile — nothing to purge server-side.
      return { deleted: false, authIdentityRemoved: false };
    }

    const authIdentityRemoved = await this.deleteSupabaseAuthUser(
      purged.supabaseUserId,
    );
    return { deleted: true, authIdentityRemoved };
  }

  /// Best-effort deletion of the Supabase Auth identity via the Admin REST API.
  /// Requires SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY in the deploy env; if
  /// they are absent we log loudly and return false (Postgres data is still
  /// purged, but the auth identity survives — set the secret for full store
  /// compliance). Never throws: a failure here must not abort the data purge.
  private async deleteSupabaseAuthUser(
    supabaseUserId: string | null,
  ): Promise<boolean> {
    if (!supabaseUserId) return false;
    const url = process.env.SUPABASE_URL?.trim();
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
    if (!url || !key) {
      this.logger.warn(
        'Account data purged but the Supabase auth identity was NOT removed: ' +
          'set SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY to fully satisfy store ' +
          'account-deletion requirements.',
      );
      return false;
    }
    try {
      const res = await fetch(
        `${url.replace(/\/$/, '')}/auth/v1/admin/users/${supabaseUserId}`,
        {
          method: 'DELETE',
          headers: { apikey: key, authorization: `Bearer ${key}` },
        },
      );
      if (!res.ok) {
        this.logger.error(
          `Supabase admin deleteUser failed ${res.status}: ${(await res.text()).slice(0, 200)}`,
        );
        return false;
      }
      return true;
    } catch (error) {
      this.logger.error(`Supabase admin deleteUser error: ${String(error)}`);
      return false;
    }
  }

  /// GDPR data export (portability): aggregate every user-owned record into one
  /// JSON document. Uploaded document files are referenced by URL, not embedded.
  async exportMe(userId?: string) {
    const id = userId ?? 'demo-user';

    const data = await this.prismaService.execute(async (prisma) => {
      const profile = await prisma.userProfile.findUnique({ where: { id } });
      if (!profile) return null;

      const [
        cases,
        savedItems,
        appointments,
        academyPurchases,
        servicePurchases,
        salonRegistrations,
        coachConversations,
        orientationSessions,
        parentLinksAsParent,
        parentLinksAsChild,
      ] = await Promise.all([
        prisma.case.findMany({
          where: { userId: id },
          include: { messages: true, timelineEvents: true, documents: true },
        }),
        prisma.savedItem.findMany({ where: { userId: id } }),
        prisma.appointment.findMany({ where: { userId: id } }),
        prisma.academyPurchase.findMany({ where: { userId: id } }),
        prisma.servicePurchase.findMany({ where: { userId: id } }),
        prisma.salonRegistration.findMany({ where: { userId: id } }),
        prisma.coachConversation.findMany({
          where: { userId: id },
          include: { messages: true },
        }),
        prisma.orientationSession.findMany({ where: { userId: id } }),
        prisma.parentChildLink.findMany({ where: { parentId: id } }),
        prisma.parentChildLink.findMany({ where: { childId: id } }),
      ]);

      return {
        profile,
        cases,
        savedItems,
        appointments,
        academyPurchases,
        servicePurchases,
        salonRegistrations,
        coachConversations,
        orientationSessions,
        parentLinks: { asParent: parentLinksAsParent, asChild: parentLinksAsChild },
      };
    });

    return {
      exportedAt: new Date().toISOString(),
      note: 'Export of your KPB Education data. Uploaded document files are referenced by URL, not embedded.',
      ...(data ?? { profile: this.demoProfile }),
    };
  }

  private mapDbProfile(p: UserProfile) {
    return {
      id: p.id,
      accountType: p.accountType,
      preferredLanguage: p.preferredLanguage,
      fullName: p.fullName,
      email: p.email,
      phone: p.phone,
      whatsApp: p.whatsApp,
      countryOfResidence: p.countryOfResidence,
      currentLevel: p.currentLevel,
      targetLevel: p.targetLevel,
      languageLevel: p.languageLevel,
      gradeRange: p.gradeRange,
      wantsScholarshipSupport: p.wantsScholarship,
      fieldIds: p.fieldIds,
      targetCountryIds: p.targetCountryIds,
      availableDocuments: p.availableDocuments,
      aiConsentedAt: p.aiConsentedAt ? p.aiConsentedAt.toISOString() : null,
      updatedAt: p.updatedAt.toISOString(),
    };
  }
}
