import { Injectable } from '@nestjs/common';
import type { UserProfile } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class ProfilesService {
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
