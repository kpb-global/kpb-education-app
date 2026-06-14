import { createHmac, timingSafeEqual } from 'crypto';
import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';

import {
  PaymentInitiateInput,
  PaymentInitiateResult,
  PaymentProviderAdapter,
  WebhookParsedEvent,
  WebhookRawInput,
} from './payment-provider.interface';

/**
 * CinetPay adapter — supports Orange Money (CI/SN/ML/BF), MTN MoMo (CI/BJ/BF),
 * Moov (all), and Wave (SN). Hosted checkout flow.
 *
 * Docs: https://docs.cinetpay.com/api/1.0-en/checkout/initialisation
 *
 * SKELETON: the `fetch` call is intentionally un-exercised in tests; replace
 * with a real HTTP call once credentials are in place. The signature scheme
 * below matches CinetPay's documented HMAC-SHA256 over the concatenated
 * payload fields.
 */
@Injectable()
export class CinetpayAdapter implements PaymentProviderAdapter {
  readonly name = 'cinetpay' as const;
  private readonly logger = new Logger(CinetpayAdapter.name);

  private readonly apiKey = process.env.KPB_CINETPAY_API_KEY ?? '';
  private readonly siteId = process.env.KPB_CINETPAY_SITE_ID ?? '';
  private readonly secretKey = process.env.KPB_CINETPAY_SECRET_KEY ?? '';
  private readonly notifyUrl = process.env.KPB_CINETPAY_NOTIFY_URL ?? '';
  private readonly endpoint =
    process.env.KPB_CINETPAY_ENDPOINT ??
    'https://api-checkout.cinetpay.com/v2/payment';

  isConfigured(): boolean {
    return !!(this.apiKey && this.siteId && this.secretKey && this.notifyUrl);
  }

  async initiate(
    input: PaymentInitiateInput,
  ): Promise<PaymentInitiateResult> {
    if (!this.isConfigured()) {
      throw new Error('CinetPay adapter is not configured.');
    }

    const transactionId = `kpb-${input.intentId}`;
    const payload = {
      apikey: this.apiKey,
      site_id: this.siteId,
      transaction_id: transactionId,
      amount: input.amountMinor,
      currency: input.currency,
      description: input.description,
      notify_url: this.notifyUrl,
      return_url: input.returnUrl,
      cancel_url: input.cancelUrl,
      customer_email: input.customer.email,
      customer_phone_number: input.customer.phone,
      customer_name: input.customer.fullName,
      metadata: input.intentId,
    };

    const response = await fetch(this.endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(
        `CinetPay init failed (${response.status}): ${text.slice(0, 200)}`,
      );
    }

    const data = (await response.json()) as {
      code?: string;
      data?: { payment_url?: string; payment_token?: string };
    };
    const checkoutUrl = data?.data?.payment_url;
    if (!checkoutUrl) {
      throw new Error('CinetPay response missing payment_url.');
    }
    return { providerRef: transactionId, checkoutUrl };
  }

  async parseWebhook(raw: WebhookRawInput): Promise<WebhookParsedEvent> {
    const body = (raw.body ?? {}) as Record<string, string>;
    const receivedToken = String(
      raw.headers['x-token'] ?? raw.headers['X-Token'] ?? '',
    );
    if (!receivedToken) {
      throw new UnauthorizedException('Missing CinetPay signature.');
    }

    // HMAC is computed over a specific concatenation per CinetPay docs.
    const toSign = [
      body['cpm_site_id'] ?? '',
      body['cpm_trans_id'] ?? '',
      body['cpm_trans_date'] ?? '',
      body['cpm_amount'] ?? '',
      body['cpm_currency'] ?? '',
      body['signature'] ?? '',
      body['payment_method'] ?? '',
      body['cel_phone_num'] ?? '',
      body['cpm_phone_prefixe'] ?? '',
      body['cpm_language'] ?? '',
      body['cpm_version'] ?? '',
      body['cpm_payment_config'] ?? '',
      body['cpm_page_action'] ?? '',
      body['cpm_custom'] ?? '',
      body['cpm_designation'] ?? '',
      body['cpm_error_message'] ?? '',
    ].join('');

    const expected = createHmac('sha256', this.secretKey)
      .update(toSign)
      .digest('hex');
    if (!safeEqualHex(expected, receivedToken)) {
      this.logger.warn(
        `CinetPay webhook signature mismatch for trans ${body['cpm_trans_id']}`,
      );
      throw new UnauthorizedException('Invalid CinetPay signature.');
    }

    const amount = parseInt(body['cpm_amount'] ?? '0', 10);
    const resultCode = body['cpm_result'] ?? '';
    const status: WebhookParsedEvent['status'] =
      resultCode === '00' ? 'paid' : 'failed';

    return {
      providerRef: body['cpm_trans_id'] ?? '',
      intentId: (body['cpm_custom'] || null) as string | null,
      status,
      amountMinor: amount,
      failureReason:
        status === 'failed' ? body['cpm_error_message'] : undefined,
    };
  }
}

function safeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  return timingSafeEqual(Buffer.from(a, 'utf8'), Buffer.from(b, 'utf8'));
}
