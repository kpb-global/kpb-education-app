import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';

import { AiConsentService } from './ai-consent.service';

/**
 * HTTP gate for LLM-backed routes (tools, document-review, orientation).
 *
 * Must sit AFTER `StudentAuthGuard` so `request.studentUser.id` is set.
 *
 * Coupling: do not deploy this guard to production before app build 49.
 * Build 48 testers hit the same routes with no in-app consent prompt on
 * the tool screens; a 403 would surface as "check your connection".
 */
@Injectable()
export class AiConsentGuard implements CanActivate {
  constructor(private readonly consent: AiConsentService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{
      studentUser?: { id?: string };
    }>();
    const userId = request.studentUser?.id;
    if (!userId) {
      throw new UnauthorizedException('Missing authenticated student.');
    }
    const block = await this.consent.consentBlockCode(userId);
    if (block) {
      throw new ForbiddenException({
        code: block,
        message:
          block === 'guardian_consent_required'
            ? 'Guardian consent required for minors.'
            : block === 'age_verification_required'
              ? 'Birth date verification is required before AI processing.'
              : 'AI processing consent required.',
      });
    }
    return true;
  }
}
