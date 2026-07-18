import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { InternalRole } from '../../../common/enums/internal-role.enum';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  outboxEventConflict,
  versionConflict,
} from '../common/competition-readiness.errors';
import {
  DomainEventConflictError,
  DomainEventOutboxService,
  DomainEventOutboxUnavailableError,
} from '../common/domain-event-outbox.service';
import {
  IdempotencyPayloadMismatchError,
  IdempotencyService,
  IdempotencyStorageUnavailableError,
} from '../common/idempotency.service';
import {
  AdminReviewAccessService,
  type AdminReviewActor,
} from './admin-review-access.service';
import type {
  CancelAvailabilitySlotDto,
  CreateAvailabilitySlotDto,
  ListAvailabilitySlotsDto,
} from './dto/availability-slot.dto';

const MAX_SLOT_DURATION_MS = 8 * 60 * 60 * 1000;
const MAX_LIST_WINDOW_MS = 366 * 24 * 60 * 60 * 1000;

@Injectable()
export class AdminAvailabilityService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly access: AdminReviewAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async listCounsellors(
    actor: AdminReviewActor,
    activeOnly = true,
    reviewRequestId?: string,
  ) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    const scope = await this.access.selectableCounsellorScope(
      actor,
      reviewRequestId,
    );
    const result = await this.prismaService.execute(async (prisma) => {
      const counsellors = await prisma.counsellor.findMany({
        where: { AND: [scope, ...(activeOnly ? [{ isActive: true }] : [])] },
        orderBy: [{ fullName: 'asc' }, { id: 'asc' }],
        select: {
          id: true,
          fullName: true,
          countryOfResidence: true,
          isActive: true,
        },
      });
      const values = Array.from(
        new Set(
          counsellors.flatMap((counsellor) => [
            counsellor.countryOfResidence,
            counsellor.countryOfResidence.toLowerCase(),
            counsellor.countryOfResidence.toUpperCase(),
          ]),
        ),
      );
      const countries = values.length
        ? await prisma.country.findMany({
            where: { OR: [{ id: { in: values } }, { code: { in: values } }] },
            select: { id: true, code: true },
          })
        : [];
      const codes = new Map<string, string>();
      for (const country of countries) {
        codes.set(country.id, country.code);
        codes.set(country.code, country.code);
        codes.set(country.code.toLowerCase(), country.code);
      }
      return counsellors.map((counsellor) => ({
        id: counsellor.id,
        fullName: counsellor.fullName,
        countryCode:
          codes.get(counsellor.countryOfResidence) ??
          codes.get(counsellor.countryOfResidence.toLowerCase()) ??
          null,
        isActive: counsellor.isActive,
      }));
    });
    if (!result) throw databaseUnavailable();
    return { items: result };
  }

  async list(actor: AdminReviewActor, query: ListAvailabilitySlotsDto) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    const counsellorId = await this.targetCounsellorId(actor, query.counsellorId);
    await this.access.assertCanManageCounsellor(actor, counsellorId);
    const from = query.from ? new Date(query.from) : new Date();
    const to = query.to
      ? new Date(query.to)
      : new Date(from.getTime() + 90 * 24 * 60 * 60 * 1000);
    if (from >= to || to.getTime() - from.getTime() > MAX_LIST_WINDOW_MS) {
      throw new BadRequestException(
        'Availability range must be positive and at most 366 days.',
      );
    }
    const slots = await this.prismaService.execute((prisma) =>
      prisma.counsellorAvailabilitySlot.findMany({
        where: {
          counsellorId,
          startsAt: { lt: to },
          endsAt: { gt: from },
          ...(query.status ? { status: query.status } : {}),
        },
        orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
        take: query.limit,
        include: { counsellor: { select: { fullName: true } } },
      }),
    );
    if (!slots) throw databaseUnavailable();
    return { items: slots.map((slot) => this.serialize(slot)) };
  }

  async create(
    actor: AdminReviewActor,
    input: CreateAvailabilitySlotDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    const counsellorId = await this.targetCounsellorId(actor, input.counsellorId);
    await this.access.assertCanManageCounsellor(actor, counsellorId);
    const { startsAt, endsAt } = this.validateWindow(
      input.startsAt,
      input.endsAt,
      input.timezone,
    );
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'admin',
              actorId: actor.id,
              operation: 'availability-slot.create',
              idempotencyKey,
              payload: { ...input, counsellorId },
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.deserializeReplay(
              reservation.responseSnapshot,
              reservation.responseCode,
            );
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();
          const counsellor = await tx.counsellor.findFirst({
            where: { id: counsellorId, isActive: true },
            select: { id: true, fullName: true },
          });
          if (!counsellor) {
            throw new BadRequestException('Counsellor is not active.');
          }
          const slot = await tx.counsellorAvailabilitySlot.create({
            data: {
              counsellorId,
              startsAt,
              endsAt,
              timezone: input.timezone,
              capacity: input.capacity,
            },
            include: { counsellor: { select: { fullName: true } } },
          });
          const serialized = this.serialize(slot);
          await tx.adminAuditEvent.create({
            data: {
              actorAdminId: actor.id,
              action: 'counsellor_availability.created',
              purposeCode: 'review_scheduling',
              entityType: 'CounsellorAvailabilitySlot',
              entityId: slot.id,
              requestId,
              reasonCode: input.reasonCode,
              result: 'success',
              changes: {
                counsellorId,
                startsAt: startsAt.toISOString(),
                endsAt: endsAt.toISOString(),
                timezone: input.timezone,
                capacity: input.capacity,
                version: slot.version,
              },
            },
          });
          await this.outbox.enqueue(
            {
              eventId: `counsellor_availability.created:${slot.id}`,
              eventName: 'counsellor_availability.created',
              aggregateType: 'CounsellorAvailabilitySlot',
              aggregateId: slot.id,
              payload: {
                slotId: slot.id,
                counsellorId,
                startsAt: startsAt.toISOString(),
                endsAt: endsAt.toISOString(),
                capacity: input.capacity,
              },
            },
            tx,
          );
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: serialized,
              resourceType: 'CounsellorAvailabilitySlot',
              resourceId: slot.id,
              resultingVersion: slot.version,
            },
            tx,
          );
          return { statusCode: 201, body: serialized };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      if (this.isOverlapConflict(error)) {
        throw new CompetitionReadinessHttpException(
          'SLOT_TAKEN',
          409,
          'Availability overlaps another active slot.',
        );
      }
      this.translateInfrastructureError(error);
    }
  }

  async cancel(
    actor: AdminReviewActor,
    slotId: string,
    input: CancelAvailabilitySlotDto,
    requestId: string,
  ) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    const existing = await this.prismaService.execute((prisma) =>
      prisma.counsellorAvailabilitySlot.findUnique({
        where: { id: slotId },
        select: { counsellorId: true },
      }),
    );
    if (!existing) throw new NotFoundException('Availability slot not found.');
    try {
      await this.access.assertCanManageCounsellor(actor, existing.counsellorId);
    } catch (error) {
      if (
        error instanceof CompetitionReadinessHttpException &&
        error.getStatus() === 403
      ) {
        // Keep nonexistent and out-of-scope slot identifiers indistinguishable.
        throw new NotFoundException('Availability slot not found.');
      }
      throw error;
    }

    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await tx.$queryRaw(
          Prisma.sql`SELECT "id" FROM "CounsellorAvailabilitySlot" WHERE "id" = ${slotId} FOR UPDATE`,
        );
        const current = await tx.counsellorAvailabilitySlot.findUnique({
          where: { id: slotId },
          include: { counsellor: { select: { fullName: true } } },
        });
        if (!current) throw new NotFoundException('Availability slot not found.');
        if (current.status === 'cancelled') {
          return this.serialize(current);
        }
        if (current.version !== input.expectedVersion) {
          throw versionConflict(current.version);
        }
        if (current.bookedCount > 0) {
          throw new CompetitionReadinessHttpException(
            'SLOT_TAKEN',
            409,
            'A booked slot cannot be cancelled.',
          );
        }
        const updated = await tx.counsellorAvailabilitySlot.update({
          where: { id: slotId },
          data: { status: 'cancelled', version: { increment: 1 } },
          include: { counsellor: { select: { fullName: true } } },
        });
        await tx.studyReviewSlotOffer.updateMany({
          where: { slotId, status: 'offered' },
          data: { status: 'withdrawn' },
        });
        await tx.adminAuditEvent.create({
          data: {
            actorAdminId: actor.id,
            action: 'counsellor_availability.cancelled',
            purposeCode: 'review_scheduling',
            entityType: 'CounsellorAvailabilitySlot',
            entityId: slotId,
            requestId,
            reasonCode: input.reasonCode,
            result: 'success',
            changes: {
              counsellorId: current.counsellorId,
              previousVersion: current.version,
              nextVersion: updated.version,
              withdrawnOffers: true,
            },
          },
        });
        await this.outbox.enqueue(
          {
            eventId: `counsellor_availability.cancelled:${slotId}:${updated.version}`,
            eventName: 'counsellor_availability.cancelled',
            aggregateType: 'CounsellorAvailabilitySlot',
            aggregateId: slotId,
            payload: {
              slotId,
              counsellorId: current.counsellorId,
              version: updated.version,
            },
          },
          tx,
        );
        return this.serialize(updated);
      }),
    );
    if (!result) throw databaseUnavailable();
    return result;
  }

  private async targetCounsellorId(
    actor: AdminReviewActor,
    requested: string | undefined,
  ): Promise<string> {
    if (actor.role === InternalRole.Counselor) {
      const own = await this.access.resolveCounsellor(actor);
      if (requested && requested !== own.id) {
        throw new CompetitionReadinessHttpException(
          'FORBIDDEN_SCOPE',
          403,
          'Counsellors may manage only their own availability.',
        );
      }
      return own.id;
    }
    if (!this.access.isPlatformAdmin(actor) || !requested) {
      throw new BadRequestException('counsellorId is required.');
    }
    return requested;
  }

  private validateWindow(starts: string, ends: string, timezone: string) {
    if (!/(?:Z|[+-]\d{2}:\d{2})$/.test(starts) || !/(?:Z|[+-]\d{2}:\d{2})$/.test(ends)) {
      throw new BadRequestException('Slot dates require an explicit UTC offset.');
    }
    this.assertTimezone(timezone);
    const startsAt = new Date(starts);
    const endsAt = new Date(ends);
    if (
      startsAt <= new Date() ||
      endsAt <= startsAt ||
      endsAt.getTime() - startsAt.getTime() > MAX_SLOT_DURATION_MS
    ) {
      throw new BadRequestException(
        'Slot must be future, positive and no longer than eight hours.',
      );
    }
    return { startsAt, endsAt };
  }

  private assertTimezone(timezone: string) {
    try {
      new Intl.DateTimeFormat('en-US', { timeZone: timezone }).format();
    } catch {
      throw new BadRequestException('Invalid IANA timezone.');
    }
  }

  private serialize(slot: {
    id: string;
    counsellorId: string;
    startsAt: Date;
    endsAt: Date;
    timezone: string;
    capacity: number;
    bookedCount: number;
    status: string;
    version: number;
    createdAt: Date;
    updatedAt: Date;
    counsellor: { fullName: string };
  }) {
    return {
      id: slot.id,
      counsellorId: slot.counsellorId,
      counsellorName: slot.counsellor.fullName,
      startsAt: slot.startsAt.toISOString(),
      endsAt: slot.endsAt.toISOString(),
      timezone: slot.timezone,
      capacity: slot.capacity,
      bookedCount: slot.bookedCount,
      remainingCapacity: Math.max(0, slot.capacity - slot.bookedCount),
      status: slot.status,
      version: slot.version,
      createdAt: slot.createdAt.toISOString(),
      updatedAt: slot.updatedAt.toISOString(),
    };
  }

  private deserializeReplay(snapshot: Prisma.JsonValue | null, code: number | null) {
    if (
      !snapshot ||
      Array.isArray(snapshot) ||
      typeof snapshot !== 'object' ||
      typeof snapshot.id !== 'string' ||
      ![200, 201].includes(code ?? 0)
    ) {
      throw databaseUnavailable();
    }
    return { statusCode: code as 200 | 201, body: snapshot };
  }

  private isOverlapConflict(error: unknown): boolean {
    const marker = 'CounsellorAvailabilitySlot_no_active_overlap';
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      const detail = `${error.message} ${JSON.stringify(error.meta ?? {})}`;
      if (error.code === 'P2002') {
        return (
          detail.includes(
            'CounsellorAvailabilitySlot_counsellorId_startsAt_endsAt_key',
          ) ||
          (detail.includes('counsellorId') &&
            detail.includes('startsAt') &&
            detail.includes('endsAt'))
        );
      }
      return (
        (error.code === 'P2004' || detail.includes('23P01')) &&
        (detail.includes(marker) || detail.includes('exclusion constraint'))
      );
    }
    if (error instanceof Prisma.PrismaClientUnknownRequestError) {
      return (
        (error.message.includes('23P01') ||
          error.message.includes('exclusion constraint')) &&
        error.message.includes(marker)
      );
    }
    return false;
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }

  private translateInfrastructureError(error: unknown): never {
    if (error instanceof IdempotencyPayloadMismatchError) {
      throw idempotencyPayloadMismatch();
    }
    if (error instanceof IdempotencyStorageUnavailableError) {
      throw databaseUnavailable();
    }
    if (error instanceof DomainEventConflictError) throw outboxEventConflict();
    if (error instanceof DomainEventOutboxUnavailableError) {
      throw databaseUnavailable();
    }
    throw error;
  }
}
