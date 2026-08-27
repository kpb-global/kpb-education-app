// ─────────────────────────────────────────────────────────────────────────────
// MauticService — pushes scholarship-newsletter contacts to the self-hosted
// Mautic instance (marketing stack on the same VPS).
//
// Degrades gracefully like OneSignalSenderService: if MAUTIC_* env vars are
// unset, every call is a logged no-op. But unlike push (best-effort), a
// CONFIGURED Mautic that fails must THROW so the reconciliation cron retries —
// a consented contact silently dropped is a lost subscriber.
//
// Mautic REST API (Basic Auth, enabled in Mautic → Configuration → API):
//   POST /api/contacts/new                          — upsert (dedupes by email)
//   POST /api/segments/{segment}/contact/{id}/add   — subscribe
//   POST /api/segments/{segment}/contact/{id}/remove — unsubscribe
//   POST /api/contacts/{id}/dnc/email/add|remove    — do-not-contact flag
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';

export interface MauticContactInput {
  email: string;
  fullName?: string | null;
  phone?: string | null;
  whatsApp?: string | null;
  countryOfResidence?: string | null;
  preferredLanguage?: string | null;
}

@Injectable()
export class MauticService {
  private readonly logger = new Logger(MauticService.name);

  private get baseUrl(): string | undefined {
    const raw = process.env.MAUTIC_BASE_URL?.trim();
    return raw ? raw.replace(/\/+$/, '') : undefined;
  }

  private get username(): string | undefined {
    return process.env.MAUTIC_USERNAME?.trim() || undefined;
  }

  private get password(): string | undefined {
    return process.env.MAUTIC_PASSWORD?.trim() || undefined;
  }

  private get segmentId(): string | undefined {
    return process.env.MAUTIC_SEGMENT_ID?.trim() || undefined;
  }

  get isConfigured(): boolean {
    return Boolean(
      this.baseUrl && this.username && this.password && this.segmentId,
    );
  }

  /**
   * Applies the desired newsletter state for one contact. Opt-in upserts the
   * contact, clears any email do-not-contact flag (a previous opt-out set it)
   * and adds it to the scholarship segment; opt-out removes it from the
   * segment and flags email DNC. Throws on any provider failure so the caller
   * (immediate push or reconciliation cron) can retry later. No-op when
   * unconfigured.
   */
  async syncContact(input: MauticContactInput, optIn: boolean): Promise<void> {
    if (!this.isConfigured) {
      this.logger.warn(
        'Mautic not configured (MAUTIC_BASE_URL / MAUTIC_USERNAME / MAUTIC_PASSWORD / MAUTIC_SEGMENT_ID) — newsletter sync skipped.',
      );
      return;
    }
    if (!input.email?.trim()) {
      // Permanent condition — retrying will not grow an email. Log and stop.
      this.logger.warn('Newsletter sync skipped: profile has no email.');
      return;
    }

    // Unsubscribing needs the contact's identity only — Mautic answers the
    // upsert with the id the segment/DNC calls address. The enrichment fields
    // (name, phone, WhatsApp, country, locale) exist to make a SUBSCRIBED
    // contact mailable and have no business leaving the server for someone
    // being taken off the list. Second line of defence behind
    // resolveNewsletterAction: should a caller ever mistake "never consented"
    // for "consent withdrawn" again, only the e-mail can escape.
    const contactId = await this.upsertContact(input, optIn);
    if (optIn) {
      await this.request(
        `/api/contacts/${contactId}/dnc/email/remove`,
        'remove email DNC',
      );
      await this.request(
        `/api/segments/${this.segmentId}/contact/${contactId}/add`,
        'add contact to segment',
      );
    } else {
      await this.request(
        `/api/segments/${this.segmentId}/contact/${contactId}/remove`,
        'remove contact from segment',
      );
      await this.request(
        `/api/contacts/${contactId}/dnc/email/add`,
        'add email DNC',
      );
    }
  }

  /**
   * Erases a contact from Mautic on account deletion (GDPR right to erasure).
   * No-op when unconfigured. Looks the contact up by exact email, then deletes
   * it (idempotent: a missing contact is a success). Throws on a configured
   * provider failure so the caller can surface it — but there is NO
   * reconciliation cron for deletes (the local profile is already gone), so
   * callers treat this best-effort. A durable deletion queue is the robust
   * follow-up; see docs/STORE_READINESS.md §6.
   */
  async deleteContact(email: string): Promise<void> {
    if (!this.isConfigured) {
      this.logger.warn('Mautic not configured — contact deletion skipped.');
      return;
    }
    if (!email?.trim()) return;
    const contactId = await this.findContactIdByEmail(email.trim());
    if (contactId === null) return; // already absent — nothing to erase.
    await this.request(`/api/contacts/${contactId}/delete`, 'delete contact', {
      method: 'DELETE',
    });
  }

  /// Resolves a Mautic contact id from an exact email, or null when none match.
  private async findContactIdByEmail(email: string): Promise<number | null> {
    const search = encodeURIComponent(`email:${email}`);
    const json = await this.request(
      `/api/contacts?search=${search}&limit=1&minimal=true`,
      'find contact by email',
      { method: 'GET' },
    );
    const contacts = (json as { contacts?: Record<string, { id?: number }> })
      ?.contacts;
    if (!contacts) return null;
    for (const entry of Object.values(contacts)) {
      if (typeof entry?.id === 'number') return entry.id;
    }
    return null;
  }

  /// Creates or updates (Mautic dedupes by email) the contact; returns its id.
  /// `includeProfileFields` is false on the opt-out path — see syncContact.
  /// Omitting them does not blank what Mautic already stores: /api/contacts/new
  /// leaves untouched every field the body does not mention.
  private async upsertContact(
    input: MauticContactInput,
    includeProfileFields: boolean,
  ): Promise<number> {
    // Mautic splits names; keep it simple and lossless enough: first token as
    // firstname, the rest as lastname.
    const fullName = input.fullName?.trim() ?? '';
    const [firstname, ...rest] = fullName.split(/\s+/);
    const profileFields: Record<string, string> = includeProfileFields
      ? {
          ...(firstname ? { firstname } : {}),
          ...(rest.length > 0 ? { lastname: rest.join(' ') } : {}),
          ...(input.phone?.trim() ? { phone: input.phone.trim() } : {}),
          ...(input.whatsApp?.trim() ? { mobile: input.whatsApp.trim() } : {}),
          ...(input.countryOfResidence?.trim()
            ? { country: input.countryOfResidence.trim() }
            : {}),
          ...(input.preferredLanguage?.trim()
            ? { preferred_locale: input.preferredLanguage.trim() }
            : {}),
        }
      : {};
    const body: Record<string, string> = {
      email: input.email.trim(),
      ...profileFields,
    };

    const json = await this.request('/api/contacts/new', 'upsert contact', {
      body,
    });
    const contactId = (json as { contact?: { id?: number } })?.contact?.id;
    if (typeof contactId !== 'number') {
      throw new Error('Mautic upsert returned no contact id.');
    }
    return contactId;
  }

  private async request(
    path: string,
    operation: string,
    options?: {
      method?: 'GET' | 'POST' | 'DELETE';
      body?: Record<string, string>;
    },
  ): Promise<unknown> {
    const credentials = Buffer.from(
      `${this.username}:${this.password}`,
    ).toString('base64');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);
    try {
      const response = await fetch(`${this.baseUrl}${path}`, {
        method: options?.method ?? 'POST',
        headers: {
          'content-type': 'application/json; charset=utf-8',
          authorization: `Basic ${credentials}`,
        },
        ...(options?.body ? { body: JSON.stringify(options.body) } : {}),
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new Error(
          `Mautic ${operation} failed with status ${response.status}.`,
        );
      }
      return (await response.json()) as unknown;
    } finally {
      clearTimeout(timeout);
    }
  }
}
