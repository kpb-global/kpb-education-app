import { createHash } from 'crypto';
import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';

import {
  PaymentInitiateInput,
  PaymentInitiateResult,
  PaymentProviderAdapter,
  WebhookParsedEvent,
  WebhookRawInput,
} from './payment-provider.interface';

/**
 * Paydunya adapter — Senegal-first gateway with strong Wave + Orange Money
 * coverage. Used as a fallback to CinetPay, primarily for SN/ML/BF students.
 *
 * Docs: https://paydunya.com/developers
 *
 * SKELETON: `initiate` hits Paydunya's invoice-create endpoint; `parseWebhook`
 * validates the IPN using the documented SHA-512(master_key) check.
 */
@Injectable()
export class PaydunyaAdapter implements PaymentProviderAdapter {
  readonly name = 'paydunya' as const;
  private readonly logger = new Logger(PaydunyaAdapter.name);

  private readonly masterKey = process.env.KPB_PAYDUNYA_MASTER_KEY ?? '';
  private readonly publicKey = process.env.KPB_PAYDUNYA_PUBLIC_KEY ?? '';
  private readonly privateKey = process.env.KPB_PAYDUNYA_PRIVATE_KEY ?? '';
  private readonly token = process.env.KPB_PAYDUNYA_TOKEN ?? '';
  private readonly mode = process.env.KPB_PAYDUNYA_MODE ?? 'live'; // live | test
  private readonly endpoint =
    this.mode === 'test'
      ? 'https://app.paydunya.com/sandbox-api/v1/checkout-invoice/create'
      : 'https://app.paydunya.com/api/v1/checkout-invoice/create';

  isConfigured(): boolean {
    return !!(
      this.masterKey &&
      this.publicKey &&
      this.privateKey &&
      this.token
    );
  }

  async initiate(
    input: PaymentInitiateInput,
  ): Promise<PaymentInitiateResult> {
    if (!this.isConfigured()) {
      throw new Error('Paydunya adapter is not configured.');
    }

    const response = await fetch(this.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'PAYDUNYA-MASTER-KEY': this.masterKey,
        'PAYDUNYA-PUBLIC-KEY': this.publicKey,
        'PAYDUNYA-PRIVATE-KEY': this.privateKey,
        'PAYDUNYA-TOKEN': this.token,
      },
      body: JSON.stringify({
        invoice: {
          items: {
            item_0: {
              name: input.description,
              quantity: 1,
              unit_price: input.amountMinor,
              total_price: input.amountMinor,
              description: input.description,
            },
          },
          total_amount: input.amountMinor,
          description: input.description,
        },
        store: { name: 'KPB Education' },
        custom_data: { intent_id: input.intentId },
        actions: {
          cancel_url: input.cancelUrl,
          return_url: input.returnUrl,
          callback_url: process.env.KPB_PAYDUNYA_CALLBACK_URL ?? '',
        },
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(
        `Paydunya init failed (${response.status}): ${text.slice(0, 200)}`,
      );
    }

    const data = (await response.json()) as {
      response_code?: string;
      token?: string;
      response_text?: string;
    };
    if (data.response_code !== '00' || !data.token) {
      throw new Error(
        `Paydunya refused: ${data.response_text ?? 'unknown error'}`,
      );
    }
    const base =
      this.mode === 'test'
        ? 'https://paydunya.com/sandbox-checkout/invoice'
        : 'https://paydunya.com/checkout/invoice';
    return {
      providerRef: data.token,
      checkoutUrl: `${base}/${data.token}`,
    };
  }

  async parseWebhook(raw: WebhookRawInput): Promise<WebhookParsedEvent> {
    const body = (raw.body ?? {}) as {
      data?: {
        hash?: string;
        status?: string;
        response_code?: string;
        invoice?: { token?: string; total_amount?: number };
        custom_data?: { intent_id?: string };
        fail_reason?: string;
      };
    };

    const hash = body?.data?.hash;
    if (!hash) {
      throw new UnauthorizedException('Missing Paydunya hash.');
    }
    const expected = createHash('sha512').update(this.masterKey).digest('hex');
    if (hash !== expected) {
      this.logger.warn('Paydunya webhook hash mismatch');
      throw new UnauthorizedException('Invalid Paydunya hash.');
    }

    const paid = body.data?.status === 'completed';
    const status: WebhookParsedEvent['status'] = paid ? 'paid' : 'failed';

    return {
      providerRef: body.data?.invoice?.token ?? '',
      intentId: body.data?.custom_data?.intent_id ?? null,
      status,
      amountMinor: body.data?.invoice?.total_amount ?? 0,
      failureReason: paid ? undefined : body.data?.fail_reason,
    };
  }
}
