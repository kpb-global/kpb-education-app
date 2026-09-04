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

/** Un journal n'est pas une décharge : on garde de quoi diagnostiquer. */
const MAX_LOGGED_BODY = 500;

function truncate(text: string): string {
  return text.length > MAX_LOGGED_BODY
    ? `${text.slice(0, MAX_LOGGED_BODY)}… (tronqué)`
    : text;
}

/**
 * Lit le corps d'une réponse en échec sans jamais faire échouer la
 * journalisation elle-même — un corps illisible ne doit pas transformer une
 * erreur d'envoi en exception non rattrapée.
 */
async function safeBody(response: Response): Promise<string> {
  try {
    return truncate((await response.text()).trim()) || '(corps vide)';
  } catch {
    return '(corps illisible)';
  }
}

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
        this.logger.error(
          `OneSignal send failed with status ${response.status}: ` +
            `${await safeBody(response)}`,
        );
        return false;
      }

      const json = (await response.json()) as {
        id?: string;
        recipients?: number;
        errors?: unknown;
      };
      if (json.errors) {
        // La charge `errors` est le SEUL endroit où OneSignal dit pourquoi il
        // refuse. Elle était désérialisée puis jetée : le 04/09/2026, la
        // campagne « Rentree Decalee » a trouvé 2 destinataires et n'en a
        // livré aucun, et le journal de production ne contenait que « provider
        // errors » — impossible de savoir si le tort venait de l'application
        // OneSignal, des identifiants, ou de l'abonné.
        //
        // Aucun secret là-dedans : ce sont les messages du fournisseur. La
        // clé REST ne transite que dans l'en-tête, jamais dans le corps de
        // réponse. Tronqué, parce qu'un journal n'est pas une décharge.
        this.logger.error(
          `OneSignal send returned provider errors: ${truncate(JSON.stringify(json.errors))}`,
        );
        return false;
      }
      // « Personne à notifier » n'est PAS un succès. Le commentaire précédent
      // annonçait vouloir distinguer ce cas, puis rendait `true` quand même —
      // et l'appelant inscrivait la livraison comme `delivered`. Un envoi qui
      // n'atteint aucun appareil doit se compter comme non livré, sinon les
      // statistiques de campagne décrivent une distribution qui n'a pas eu
      // lieu. Journalisé en `warn` et non en `debug` : c'est précisément le
      // symptôme d'une application OneSignal sans plateforme configurée, ou
      // d'un utilisateur qui a refusé les notifications.
      if (json.recipients === 0) {
        this.logger.warn(
          `OneSignal accepted the request but delivered to 0 device for user ${userId} ` +
            '(no subscribed device, or no delivery platform configured on the OneSignal app).',
        );
        return false;
      }
      return true;
    } catch (error) {
      // Le motif compte : un abandon sur délai ne se répare pas comme un DNS
      // qui ne résout pas. `AbortError` est le nom que `fetch` donne au
      // dépassement des 10 s armées plus haut.
      const reason =
        error instanceof Error ? `${error.name}: ${error.message}` : 'unknown';
      this.logger.error(`OneSignal push request failed — ${reason}`);
      return false;
    } finally {
      clearTimeout(timeout);
    }
  }
}
