import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

export type AiConsentBlockCode =
  | 'ai_consent_required'
  | 'guardian_consent_required';

/**
 * Shared AI-processing consent check (KPB-66 / IA-T1).
 *
 * Extracted from CoachService so every Groq surface uses the same rules:
 * the student must have opted in (`aiConsentedAt`), and a minor additionally
 * needs recorded guardian consent.
 *
 * Fail-open: when `tryExecute` returns null (no DATABASE_URL, or the query
 * failed) we cannot verify, so we allow the call and rely on the client-side
 * gate. Do not "fix" this to fail-closed without updating the dedicated test
 * and the product decision — a hard block on every DB blip would lock the
 * coach in local/dev and during a brief Postgres outage.
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
    if (!profile) return null; // DB down or no row → don't hard-block.
    if (profile.aiConsentedAt == null) return 'ai_consent_required';
    if (this.isMinor(profile.birthDate) && profile.guardianConsentedAt == null) {
      return 'guardian_consent_required';
    }
    return null;
  }

  /// Under 18 at the time of the call. An unknown birthDate is NOT treated
  /// as minor — onboarding does not require it, so blocking on null would
  /// lock out every adult who skipped the field.
  isMinor(birthDate: Date | null | undefined): boolean {
    if (!birthDate) return false;
    const eighteenthBirthday = new Date(birthDate);
    eighteenthBirthday.setFullYear(eighteenthBirthday.getFullYear() + 18);
    return eighteenthBirthday.getTime() > Date.now();
  }
}
