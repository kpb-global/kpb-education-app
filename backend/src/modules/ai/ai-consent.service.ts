import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

export type AiConsentBlockCode =
  | 'ai_consent_required'
  | 'age_verification_required'
  | 'guardian_consent_required';

/**
 * Shared AI-processing consent check (KPB-66 / IA-T1).
 *
 * Extracted from CoachService so every Groq surface uses the same rules:
 * the student must have opted in (`aiConsentedAt`), and a minor additionally
 * needs recorded guardian consent.
 *
 * Fail-closed: a missing profile, unknown birth date, or failed profile read
 * blocks third-party AI processing. Availability cannot outrank consent and
 * age verification; local development can seed a profile to exercise AI.
 *
 * Not to be confused with `competition-readiness/diagnostics/ai-consent.*`
 * (Success Lab, minimum diagnostic age 13).
 */
@Injectable()
export class AiConsentService {
  constructor(private readonly prisma: PrismaService) {}

  async consentBlockCode(
    userId: string,
  ): Promise<AiConsentBlockCode | null> {
    const profile = await this.prisma.tryExecute((client) =>
      client.userProfile.findUnique({
        where: { id: userId },
        select: {
          aiConsentedAt: true,
          birthDate: true,
          guardianConsentedAt: true,
        },
      }),
    );
    if (!profile?.birthDate) return 'age_verification_required';
    if (profile.aiConsentedAt == null) return 'ai_consent_required';
    if (this.isMinor(profile.birthDate) && profile.guardianConsentedAt == null) {
      return 'guardian_consent_required';
    }
    return null;
  }

  /// Under 18 at the time of the call. Callers must block an unknown birthDate
  /// before invoking this helper; unknown age is never evidence of adulthood.
  isMinor(birthDate: Date | null | undefined): boolean {
    if (!birthDate) return true;
    const eighteenthBirthday = new Date(birthDate);
    eighteenthBirthday.setFullYear(eighteenthBirthday.getFullYear() + 18);
    return eighteenthBirthday.getTime() > Date.now();
  }
}
