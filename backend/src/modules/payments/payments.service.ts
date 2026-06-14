import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CinetpayAdapter } from './cinetpay.adapter';
import { PaydunyaAdapter } from './paydunya.adapter';
import {
  PaymentProviderAdapter,
  WebhookRawInput,
} from './payment-provider.interface';

type ProviderName = 'cinetpay' | 'paydunya' | 'stripe' | 'manual';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  private readonly adapters: Record<ProviderName, PaymentProviderAdapter>;

  constructor(
    private readonly prismaService: PrismaService,
    private readonly cinetpayAdapter: CinetpayAdapter,
    private readonly paydunyaAdapter: PaydunyaAdapter,
  ) {
    this.adapters = {
      cinetpay: cinetpayAdapter,
      paydunya: paydunyaAdapter,
      // Stripe intentionally stubbed — "Stripe doesn't work here" for most
      // West African rails, but we leave the provider enum value for the
      // occasional EU-based parent paying via card.
      stripe: {
        name: 'stripe',
        isConfigured: () => false,
        initiate: async () => {
          throw new Error('Stripe adapter not implemented.');
        },
        parseWebhook: async () => {
          throw new Error('Stripe adapter not implemented.');
        },
      },
      // Manual = advisor records an offline payment (wire transfer, cash).
      // No checkout URL; status is moved to `paid` by admin directly.
      manual: {
        name: 'manual',
        isConfigured: () => true,
        initiate: async (input) => ({
          providerRef: `manual-${input.intentId}`,
          checkoutUrl: '',
        }),
        parseWebhook: async () => {
          throw new Error('Manual provider has no webhook.');
        },
      },
    };
  }

  /** Returns the list of providers actually usable right now (env-configured). */
  listAvailableProviders(): ProviderName[] {
    return (Object.keys(this.adapters) as ProviderName[]).filter((name) =>
      this.adapters[name].isConfigured(),
    );
  }

  async createIntent(input: {
    userId: string;
    provider: ProviderName;
    amountMinor: number;
    currency?: string;
    caseId?: string;
    counsellorId?: string;
    description?: string;
    customer: { email: string; phone: string; fullName: string };
    returnUrl: string;
    cancelUrl: string;
  }) {
    if (input.amountMinor <= 0) {
      throw new BadRequestException('amountMinor must be positive.');
    }

    const adapter = this.adapters[input.provider];
    if (!adapter) {
      throw new BadRequestException(`Unknown provider: ${input.provider}`);
    }
    if (!adapter.isConfigured()) {
      throw new BadRequestException(
        `Provider ${input.provider} is not configured on this environment.`,
      );
    }

    const intent = await this.prismaService.execute((prisma) =>
      prisma.paymentIntent.create({
        data: {
          userId: input.userId,
          caseId: input.caseId,
          counsellorId: input.counsellorId,
          amountMinor: input.amountMinor,
          currency: input.currency ?? 'XOF',
          provider: input.provider,
          description: input.description,
        },
      }),
    );
    if (!intent) {
      throw new Error('Failed to persist payment intent.');
    }

    const result = await adapter.initiate({
      intentId: intent.id,
      amountMinor: intent.amountMinor,
      currency: intent.currency,
      description: intent.description ?? 'KPB Education',
      customer: input.customer,
      returnUrl: input.returnUrl,
      cancelUrl: input.cancelUrl,
    });

    const updated = await this.prismaService.execute((prisma) =>
      prisma.paymentIntent.update({
        where: { id: intent.id },
        data: {
          providerRef: result.providerRef,
          checkoutUrl: result.checkoutUrl,
          status: 'pending',
        },
      }),
    );
    return updated;
  }

  async getIntent(id: string) {
    const intent = await this.prismaService.execute((prisma) =>
      prisma.paymentIntent.findUnique({ where: { id } }),
    );
    if (!intent) {
      throw new NotFoundException(`Payment intent ${id} not found.`);
    }
    return intent;
  }

  /**
   * Process an incoming webhook. Dispatches to the adapter for signature
   * verification, then updates the matching PaymentIntent. Always returns a
   * 200 response to the provider once persisted — they will retry on 5xx.
   */
  async handleWebhook(provider: ProviderName, raw: WebhookRawInput) {
    const adapter = this.adapters[provider];
    if (!adapter) {
      throw new BadRequestException(`Unknown provider: ${provider}`);
    }

    const event = await adapter.parseWebhook(raw);

    // Prefer intentId (our id in custom metadata) over providerRef when
    // available — providerRef could theoretically collide across providers.
    const where = event.intentId
      ? { id: event.intentId }
      : event.providerRef
        ? { providerRef: event.providerRef }
        : null;
    if (!where) {
      this.logger.warn(
        `Webhook with neither intentId nor providerRef from ${provider}`,
      );
      return { ok: false };
    }

    const updated = await this.prismaService.execute((prisma) =>
      prisma.paymentIntent.update({
        where,
        data: {
          status: event.status === 'paid' ? 'paid' : event.status,
          paidAt: event.status === 'paid' ? new Date() : null,
          failureReason: event.failureReason,
          lastWebhookAt: new Date(),
        },
      }),
    );

    this.logger.log(
      `Webhook ${provider} → intent ${updated?.id} = ${updated?.status}`,
    );
    return { ok: true, intentId: updated?.id };
  }

  /** Admin-only: mark an intent as paid manually (offline payments). */
  async markPaidManually(id: string, note?: string) {
    return this.prismaService.execute((prisma) =>
      prisma.paymentIntent.update({
        where: { id },
        data: {
          status: 'paid',
          paidAt: new Date(),
          description: note,
          provider: 'manual',
        },
      }),
    );
  }
}
