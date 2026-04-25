import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class ProfilesService {
  constructor(private readonly prismaService: PrismaService) {}

  private profile = {
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

    if (dbProfile) {
      return {
        id: dbProfile.id,
        accountType: dbProfile.accountType,
        preferredLanguage: dbProfile.preferredLanguage,
        fullName: dbProfile.fullName,
        email: dbProfile.email,
        phone: dbProfile.phone,
        whatsApp: dbProfile.whatsApp,
        countryOfResidence: dbProfile.countryOfResidence,
        currentLevel: dbProfile.currentLevel,
        targetLevel: dbProfile.targetLevel,
        languageLevel: dbProfile.languageLevel,
        gradeRange: dbProfile.gradeRange,
        wantsScholarshipSupport: dbProfile.wantsScholarship,
        fieldIds: this.profile.fieldIds,
        targetCountryIds: this.profile.targetCountryIds,
        availableDocuments: this.profile.availableDocuments,
        updatedAt: dbProfile.updatedAt.toISOString(),
      };
    }

    return this.profile;
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
        },
      }),
    );

    if (updated) {
      // Keep in-memory copy in sync for non-DB fields
      this.profile = {
        ...this.profile,
        ...input,
        updatedAt: updated.updatedAt.toISOString(),
      };

      return {
        id: updated.id,
        accountType: updated.accountType,
        preferredLanguage: updated.preferredLanguage,
        fullName: updated.fullName,
        email: updated.email,
        phone: updated.phone,
        whatsApp: updated.whatsApp,
        countryOfResidence: updated.countryOfResidence,
        currentLevel: updated.currentLevel,
        targetLevel: updated.targetLevel,
        languageLevel: updated.languageLevel,
        gradeRange: updated.gradeRange,
        wantsScholarshipSupport: updated.wantsScholarship,
        fieldIds: this.profile.fieldIds,
        targetCountryIds: this.profile.targetCountryIds,
        availableDocuments: this.profile.availableDocuments,
        updatedAt: updated.updatedAt.toISOString(),
      };
    }

    this.profile = {
      ...this.profile,
      ...input,
      updatedAt: new Date().toISOString(),
    };
    return this.profile;
  }
}
