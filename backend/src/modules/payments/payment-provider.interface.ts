/**
 * Payment gateway abstraction. "Stripe doesn't work here" — West African
 * students pay by Orange Money, Wave, MTN MoMo, or Moov, so we route through
 * CinetPay or Paydunya instead. Each provider has its own init/webhook
 * signature shape, so we hide those behind this interface.
 *
 * The adapter is stateless and takes raw config via constructor — the service
 * is responsible for persisting PaymentIntent records.
 */
export interface PaymentProviderAdapter {
  /** Stable identifier, matches PaymentProvider enum value. */
  readonly name: 'cinetpay' | 'paydunya' | 'stripe' | 'manual';

  /** Whether this adapter has enough config to be used. */
  isConfigured(): boolean;

  /**
   * Kick off a checkout session. Returns the provider's transaction reference
   * and the hosted checkout URL the user should be redirected to.
   */
  initiate(input: PaymentInitiateInput): Promise<PaymentInitiateResult>;

  /**
   * Verify and parse a webhook payload. Implementations MUST validate the
   * signature/HMAC and reject forged requests. Throw on invalid signature.
   */
  parseWebhook(raw: WebhookRawInput): Promise<WebhookParsedEvent>;
}

export type PaymentInitiateInput = {
  intentId: string; // our PaymentIntent.id — echoed in webhook metadata
  amountMinor: number; // integer; XOF has no subunit
  currency: string; // "XOF", "EUR", etc.
  description: string;
  customer: { email: string; phone: string; fullName: string };
  // Where the hosted checkout redirects on success / cancel.
  returnUrl: string;
  cancelUrl: string;
};

export type PaymentInitiateResult = {
  providerRef: string;
  checkoutUrl: string;
};

export type WebhookRawInput = {
  body: unknown;
  headers: Record<string, string | string[] | undefined>;
  rawBody?: string | Buffer;
};

export type WebhookParsedEvent = {
  providerRef: string;
  intentId: string | null;
  status: 'paid' | 'failed' | 'pending' | 'cancelled';
  amountMinor: number;
  failureReason?: string;
};
