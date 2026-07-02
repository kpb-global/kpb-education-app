// ─────────────────────────────────────────────────────────────────────────────
// OneSignalSenderService — server-side push delivery via the OneSignal REST API.
//
// Targets users by their OneSignal "external id", which the Flutter app sets to
// the KPB user profile id on login (OneSignal.login). This replaces the former
// FCM/device-token path: OneSignal owns device subscriptions, so the backend no
// longer manages raw FCM tokens.
//
// Degrades gracefully: if ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY are unset,
// every send is a logged no-op instead of throwing.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';

const ONESIGNAL_API_URL = 'https://onesignal.com/api/v1/notifications';

@Injectable()
export class OneSignalSenderService {
  private readonly logger = new Logger(OneSignalSenderService.name);

  private get appId(): string | undefined {
    return process.env.ONESIGNAL_APP_ID?.trim() || undefined;
  }

  private get restApiKey(): string | undefined {
    return process.env.ONESIGNAL_REST_API_KEY?.trim() || undefined;
  }

  get isConfigured(): boolean {
    return Boolean(this.appId && this.restApiKey);
  }

  /**
   * Send a push notification to one KPB user (by external id).
   * Signature mirrors the previous FirebasePushService.sendToUser so call sites
   * stay unchanged.
   */
  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<boolean> {
    if (!this.isConfigured) {
      this.logger.warn(
        'OneSignal not configured (ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY) — push skipped.',
      );
      return false;
    }
    if (!userId) return false;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);
    try {
      const response = await fetch(ONESIGNAL_API_URL, {
        method: 'POST',
        headers: {
          'content-type': 'application/json; charset=utf-8',
          authorization: `Basic ${this.restApiKey}`,
        },
        body: JSON.stringify({
          app_id: this.appId,
          target_channel: 'push',
          include_aliases: { external_id: [userId] },
          headings: { en: title, fr: title },
          contents: { en: body, fr: body },
          data: data ?? {},
        }),
        signal: controller.signal,
      });

      if (!response.ok) {
        const text = await response.text();
        this.logger.error(
          `OneSignal send failed (${response.status}) for ${userId}: ${text.slice(0, 200)}`,
        );
        return false;
      }

      const json = (await response.json()) as {
        id?: string;
        recipients?: number;
        errors?: unknown;
      };
      if (json.errors) {
        this.logger.error(
          `OneSignal send returned errors for ${userId}: ${JSON.stringify(json.errors).slice(0, 200)}`,
        );
        return false;
      }
      // Distinguish "nobody to notify" (user has no subscribed device — not a
      // transient failure, so callers should NOT retry) from a real error.
      if (json.recipients === 0) {
        this.logger.debug(
          `OneSignal: no subscribed recipients for ${userId} (push not delivered).`,
        );
      }
      return true;
    } catch (error) {
      this.logger.error(`OneSignal push failed for user ${userId}:`, error);
      return false;
    } finally {
      clearTimeout(timeout);
    }
  }
}
