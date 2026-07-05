import {
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { randomUUID } from 'node:crypto';

import { CaseStatus } from '../../common/enums/case-status.enum';
import { OneSignalSenderService } from '../notifications/onesignal-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { ReferralCreditsService } from '../referrals/referral-credits.service';
import { CaseMessagingGateway } from './case-messaging.gateway';
import { AssignCaseDto } from './dto/assign-case.dto';
import { CreateCaseDto } from './dto/create-case.dto';
import { CreateCaseInternalNoteDto } from './dto/create-case-internal-note.dto';
import { CreateCaseTaskDto } from './dto/create-case-task.dto';
import { CreateCaseTimelineEventDto } from './dto/create-case-timeline-event.dto';
import { UpdateCaseDto } from './dto/update-case.dto';
import { UploadCaseDocumentDto } from './dto/upload-case-document.dto';

const CASE_INCLUDE = {
  user: true,
  messages: { orderBy: { createdAt: 'desc' as const } },
  timelineEvents: { orderBy: { createdAt: 'desc' as const } },
  tasks: { orderBy: { createdAt: 'desc' as const } },
  documents: { orderBy: { createdAt: 'desc' as const } },
  internalNotes: { orderBy: { createdAt: 'desc' as const } },
};

@Injectable()
export class CasesService {
  private readonly logger = new Logger(CasesService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly moduleRef: ModuleRef,
    private readonly pushService: OneSignalSenderService,
  ) {}

  private broadcastCaseUpdate(caseId: string, payload: Record<string, unknown>) {
    try {
      const gateway = this.moduleRef.get(CaseMessagingGateway, { strict: false });
      gateway.emitCaseUpdated(caseId, payload);
    } catch {
      // Gateway may be unavailable in isolated tests.
    }
  }

  private broadcastCaseMessage(caseId: string, message: Record<string, unknown>) {
    try {
      const gateway = this.moduleRef.get(CaseMessagingGateway, { strict: false });
      gateway.emitCaseMessage(caseId, message);
    } catch {
      // Gateway may be unavailable in isolated tests.
    }
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  private async requireDbCase(id: string, ownerUserId?: string) {
    const dbCase = await this.prismaService.execute((prisma) =>
      prisma.case.findUnique({ where: { id }, include: CASE_INCLUDE }),
    );
    // When ownerUserId is provided (student-facing path) a case owned by
    // another user must be indistinguishable from a missing case to avoid
    // leaking its existence (IDOR protection).
    if (!dbCase || (ownerUserId && dbCase.userId !== ownerUserId)) {
      throw new NotFoundException(`Case ${id} not found.`);
    }
    return dbCase;
  }

  async findAll(userId?: string) {
    this.assertDb();
    const items = await this.prismaService.execute((prisma) =>
      prisma.case.findMany({
        where: userId ? { userId } : undefined,
        include: CASE_INCLUDE,
        orderBy: { createdAt: 'desc' },
      }),
    );
    return (items ?? []).map((c) => this.mapDbCase(c));
  }

  async findAllForAdmin() {
    return this.findAll();
  }

  async findOne(id: string, ownerUserId?: string) {
    this.assertDb();
    const dbCase = await this.requireDbCase(id, ownerUserId);
    // Student-facing reads (ownerUserId set) must not expose counselor notes.
    return this.mapDbCase(dbCase, { includeInternal: !ownerUserId });
  }

  async create(input: CreateCaseDto, userId?: string) {
    this.assertDb();

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const activeCounsellors = await tx.counsellor.findMany({
          where: { isActive: true },
          orderBy: { createdAt: 'asc' },
        });

        // Insert with a temporary unique placeholder, then derive the real
        // referenceCode from the DB-assigned `seq`. This is collision-free by
        // construction (no count()+1 race). The same monotonic `seq` is used to
        // round-robin across active counsellors.
        const c = await tx.case.create({
          data: {
            referenceCode: `PENDING-${randomUUID()}`,
            userId: userId ?? 'demo-user',
            type: input.type,
            status: CaseStatus.Submitted,
            title: input.title,
            description: input.description,
            contextLabel: input.contextLabel,
            preferredContactMethod: input.preferredContactMethod ?? 'in_app',
            source: 'mobile_app',
            nextStepTitle: 'Your case is under review',
            nextStepDescription:
              'The KPB team will review your request and assign a counselor.',
          },
        });

        const nextCounsellor =
          activeCounsellors.length > 0
            ? activeCounsellors[(c.seq - 1) % activeCounsellors.length]
            : null;

        const refCode = `KPB-${c.createdAt.getFullYear()}-${String(c.seq).padStart(3, '0')}`;
        await tx.case.update({
          where: { id: c.id },
          data: {
            referenceCode: refCode,
            ...(nextCounsellor
              ? {
                  status: CaseStatus.CounselorAssigned,
                  counsellorId: nextCounsellor.id,
                  assignedAdvisorName: nextCounsellor.fullName,
                  // Personal counsellor numbers are deliberately NOT copied
                  // onto the case: every student/parent contact goes through
                  // the official KPB WhatsApp line (anti-fraud, Item 12).
                  leadTag: 'to_follow_up',
                  lastCommercialInteractionAt: new Date(),
                  nextStepTitle: 'A counselor has been assigned',
                  nextStepDescription: `${nextCounsellor.fullName} has been assigned to your case and will contact you shortly.`,
                }
              : {}),
          },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: c.id,
            status: CaseStatus.Submitted,
            title: 'Case submitted',
            description: 'The student created a new case from the mobile app.',
          },
        });

        if (nextCounsellor) {
          await tx.caseTimelineEvent.create({
            data: {
              caseId: c.id,
              status: CaseStatus.CounselorAssigned,
              title: 'Counselor assigned',
              description: `${nextCounsellor.fullName} was assigned automatically (round-robin).`,
            },
          });
        }

        await tx.caseMessage.create({
          data: {
            caseId: c.id,
            senderRole: 'system',
            senderName: 'KPB Operations',
            body: nextCounsellor
              ? `Thank you. ${nextCounsellor.fullName} has been assigned to your request.`
              : 'Thank you. Your request has been received by the KPB team.',
          },
        });

        await tx.caseDocument.create({
          data: {
            caseId: c.id,
            title: 'Academic profile',
            isProvided: false,
          },
        });

        return tx.case.findUnique({
          where: { id: c.id },
          include: CASE_INCLUDE,
        });
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException('Failed to create case.');
    }
    const mapped = this.mapDbCase(created);
    if (userId) {
      // No-cash referral reward (KPB-77): if this student was referred, credit
      // their referrer on the FIRST case. Fire-and-forget and OUTSIDE the
      // case-creation transaction — a crediting failure must never roll back or
      // block the student's case. Idempotency is enforced in the service.
      void this.moduleRef
        .get(ReferralCreditsService, { strict: false })
        .creditReferrerForFirstCase(userId)
        .catch((e) =>
          this.logger.warn(
            `Referral credit failed for ${userId}: ${e?.message ?? e}`,
          ),
        );

      const advisorName = mapped.assignedAdvisorName ?? 'KPB';
      await this.pushService.sendToUser(
        userId,
        'Demande reçue ✅',
        mapped.assignedAdvisorName
          ? `Ta demande est reçue, ${advisorName} va te contacter sous peu.`
          : 'Ta demande est reçue. L\'équipe KPB revient vers toi rapidement.',
        {
          type: 'case_created',
          caseId: created.id,
          route: `/cases/${created.id}`,
        },
      );
    }
    return mapped;
  }

  async update(id: string, input: UpdateCaseDto, ownerUserId?: string) {
    this.assertDb();
    await this.requireDbCase(id, ownerUserId);

    const updated = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const c = await tx.case.update({
          where: { id },
          data: {
            ...(input.status ? { status: input.status } : {}),
            ...(input.nextStepTitle ? { nextStepTitle: input.nextStepTitle } : {}),
            ...(input.nextStepDescription
              ? { nextStepDescription: input.nextStepDescription }
              : {}),
            ...(input.assignedAdvisorName
              ? { assignedAdvisorName: input.assignedAdvisorName }
              : {}),
            ...(input.assignedAdvisorPhone
              ? { assignedAdvisorPhone: input.assignedAdvisorPhone }
              : {}),
            ...(input.assignedAdvisorWhatsapp
              ? { assignedAdvisorWhatsapp: input.assignedAdvisorWhatsapp }
              : {}),
            ...(input.scheduledAt
              ? { scheduledAt: new Date(input.scheduledAt) }
              : {}),
          },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status: input.status ?? c.status,
            title: 'Case updated',
            description:
              input.nextStepDescription ??
              'The case was updated by an admin or counselor.',
          },
        });

        return tx.case.findUnique({
          where: { id },
          include: CASE_INCLUDE,
        });
      }),
    );

    if (!updated) {
      throw new ServiceUnavailableException('Failed to update case.');
    }
    const mapped = this.mapDbCase(updated, { includeInternal: !ownerUserId });
    this.broadcastCaseUpdate(id, mapped as Record<string, unknown>);
    return mapped;
  }

  async findMessages(id: string, ownerUserId?: string) {
    this.assertDb();
    if (ownerUserId) {
      await this.requireDbCase(id, ownerUserId);
    }
    const messages = await this.prismaService.execute((prisma) =>
      prisma.caseMessage.findMany({
        where: { caseId: id },
        orderBy: { createdAt: 'desc' },
      }),
    );
    return (messages ?? []).map((m) => ({
      id: m.id,
      senderName: m.senderName,
      senderRole: m.senderRole,
      body: m.body,
      createdAt: m.createdAt.toISOString(),
    }));
  }

  async createMessage(
    id: string,
    input: { body: string; senderName?: string; senderRole?: string },
    ownerUserId?: string,
  ) {
    this.assertDb();
    await this.requireDbCase(id, ownerUserId);

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        // When ownerUserId is set this is the student REST path — force role
        // to 'student' regardless of the input to prevent impersonation.
        const effectiveRole = ownerUserId ? 'student' : (input.senderRole ?? 'student');
        const effectiveName = ownerUserId ? (input.senderName ?? 'Étudiant') : (input.senderName ?? 'KPB Operations');
        const msg = await tx.caseMessage.create({
          data: {
            caseId: id,
            senderName: effectiveName,
            senderRole: effectiveRole,
            body: input.body,
          },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status:
              (await tx.case.findUnique({ where: { id } }))?.status ??
              CaseStatus.Submitted,
            title: 'New message',
            description: 'A new service message was added to the case.',
          },
        });

        await tx.case.update({ where: { id }, data: { updatedAt: new Date() } });

        return msg;
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException('Failed to persist message.');
    }
    const payload = {
      id: created.id,
      senderName: created.senderName,
      senderRole: created.senderRole,
      body: created.body,
      createdAt: created.createdAt.toISOString(),
    };
    if ((input.senderRole ?? 'student') !== 'student') {
      this.broadcastCaseMessage(id, payload);
    }
    return payload;
  }

  async uploadDocument(
    id: string,
    input: UploadCaseDocumentDto,
    ownerUserId?: string,
  ) {
    this.assertDb();
    await this.requireDbCase(id, ownerUserId);

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const doc = await tx.caseDocument.create({
          data: {
            caseId: id,
            title: input.title,
            isProvided: true,
            fileUrl: input.fileUrl ?? null,
            uploadedAt: new Date(),
          },
        });

        await tx.case.update({
          where: { id },
          data: { status: CaseStatus.UnderReview },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status: CaseStatus.UnderReview,
            title: 'Document uploaded',
            description: `${input.title} was uploaded to the case.`,
          },
        });

        return doc;
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException('Failed to persist document.');
    }
    return {
      id: created.id,
      title: created.title,
      isProvided: created.isProvided,
      fileUrl: created.fileUrl,
      uploadedAt: created.uploadedAt?.toISOString(),
    };
  }

  async assignCase(id: string, input: AssignCaseDto) {
    this.assertDb();
    await this.requireDbCase(id);

    const newStatus = input.scheduledAt
      ? CaseStatus.Scheduled
      : CaseStatus.CounselorAssigned;

    const assigned = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await tx.case.update({
          where: { id },
          data: {
            status: newStatus,
            assignedAdvisorName: input.assignedAdvisorName,
            ...(input.assignedAdvisorPhone
              ? { assignedAdvisorPhone: input.assignedAdvisorPhone }
              : {}),
            ...(input.assignedAdvisorWhatsapp
              ? { assignedAdvisorWhatsapp: input.assignedAdvisorWhatsapp }
              : {}),
            leadTag: 'to_follow_up',
            lastCommercialInteractionAt: new Date(),
            nextStepTitle:
              input.nextStepTitle ??
              (input.scheduledAt
                ? 'Prepare for your scheduled session'
                : 'A counselor has been assigned'),
            nextStepDescription:
              input.nextStepDescription ??
              (input.scheduledAt
                ? 'Confirm your availability and prepare your supporting documents.'
                : 'Your counselor will qualify your profile and contact you shortly.'),
            ...(input.scheduledAt
              ? { scheduledAt: new Date(input.scheduledAt) }
              : {}),
          },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status: newStatus,
            title: input.scheduledAt ? 'Case scheduled' : 'Counselor assigned',
            description: input.scheduledAt
              ? `${input.assignedAdvisorName} scheduled a follow-up on this case.`
              : `${input.assignedAdvisorName} is now the owner of this case.`,
          },
        });

        return tx.case.findUnique({
          where: { id },
          include: CASE_INCLUDE,
        });
      }),
    );

    if (!assigned) {
      throw new ServiceUnavailableException('Failed to assign case.');
    }
    const mapped = this.mapDbCase(assigned);
    this.broadcastCaseUpdate(id, mapped as Record<string, unknown>);
    return mapped;
  }

  async createTask(id: string, input: CreateCaseTaskDto) {
    this.assertDb();
    await this.requireDbCase(id);

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const task = await tx.caseTask.create({
          data: {
            caseId: id,
            title: input.title,
            assigneeName: input.assigneeName ?? null,
            status: input.status ?? 'open',
            ...(input.dueAt ? { dueAt: new Date(input.dueAt) } : {}),
          },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status:
              (await tx.case.findUnique({ where: { id } }))?.status ??
              CaseStatus.Submitted,
            title: 'Task created',
            description: `${input.title} was added to the case workflow.`,
          },
        });

        await tx.case.update({ where: { id }, data: { updatedAt: new Date() } });

        return task;
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException('Failed to create task.');
    }
    return {
      id: created.id,
      title: created.title,
      assigneeName: created.assigneeName,
      assigneeRole: created.assigneeRole,
      dueAt: created.dueAt?.toISOString() ?? null,
      status: created.status,
      createdAt: created.createdAt.toISOString(),
    };
  }

  async createInternalNote(id: string, input: CreateCaseInternalNoteDto) {
    this.assertDb();
    await this.requireDbCase(id);

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const note = await tx.caseInternalNote.create({
          data: {
            caseId: id,
            authorName: input.authorName,
            authorRole: input.authorRole as any,
            body: input.body,
          },
        });

        await tx.case.update({ where: { id }, data: { updatedAt: new Date() } });

        return note;
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException('Failed to create note.');
    }
    return {
      id: created.id,
      authorName: created.authorName,
      authorRole: created.authorRole,
      body: created.body,
      createdAt: created.createdAt.toISOString(),
    };
  }

  async createTimelineEvent(id: string, input: CreateCaseTimelineEventDto) {
    this.assertDb();
    const currentCase = await this.requireDbCase(id);

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const event = await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status: input.status ?? currentCase.status ?? CaseStatus.Submitted,
            title: input.title,
            description: input.description,
          },
        });

        await tx.case.update({ where: { id }, data: { updatedAt: new Date() } });

        return event;
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException('Failed to create timeline event.');
    }
    const refreshed = await this.prismaService.execute((prisma) =>
      prisma.case.findUnique({ where: { id }, include: CASE_INCLUDE }),
    );
    if (refreshed) {
      this.broadcastCaseUpdate(id, this.mapDbCase(refreshed) as Record<string, unknown>);
    }
    return {
      id: created.id,
      title: created.title,
      description: created.description,
      status: created.status as CaseStatus,
      createdAt: created.createdAt.toISOString(),
    };
  }

  createNotificationTimelineEvent(
    id: string,
    title: string,
    description: string,
  ) {
    return this.createTimelineEvent(id, { title, description });
  }

  private mapDbCase(c: any, opts: { includeInternal?: boolean } = {}) {
    const includeInternal = opts.includeInternal ?? true;
    return {
      id: c.id,
      userId: c.userId,
      referenceCode: c.referenceCode,
      studentName: c.user?.fullName ?? 'Unknown',
      studentEmail: c.user?.email ?? '',
      preferredLanguage: c.user?.preferredLanguage ?? 'fr',
      source: c.source ?? 'mobile_app',
      requestedCountryId: c.requestedCountryId ?? null,
      type: c.type,
      title: c.title,
      status: c.status as CaseStatus,
      nextStepTitle: c.nextStepTitle,
      nextStepDescription: c.nextStepDescription,
      assignedAdvisorName: c.assignedAdvisorName,
      // Counsellor contact details are internal-only: students and parents
      // must reach KPB through the official WhatsApp line, so legacy rows that
      // still carry personal numbers are not exposed on student-facing reads.
      assignedAdvisorPhone: includeInternal ? c.assignedAdvisorPhone : null,
      assignedAdvisorWhatsapp: includeInternal
        ? c.assignedAdvisorWhatsapp
        : null,
      // Marketplace counsellor id (Track B) — used by the app to attribute an
      // admission-milestone review to the right counsellor (KPB-75).
      counsellorId: c.counsellorId ?? null,
      createdAt: c.createdAt.toISOString(),
      updatedAt: c.updatedAt.toISOString(),
      description: c.description,
      contextLabel: c.contextLabel,
      preferredContactMethod: c.preferredContactMethod ?? 'in_app',
      scheduledAt: c.scheduledAt?.toISOString() ?? null,
      // Whether the student has opted into sharing this case with a linked
      // parent. Surfaced so the app can render (and toggle) the share switch.
      parentCanView: c.parentCanView ?? false,
      leadTag: c.leadTag ?? null,
      discussionMotive: c.discussionMotive ?? null,
      lastCommercialInteractionAt:
        c.lastCommercialInteractionAt?.toISOString() ?? null,
      documentRequests: (c.documents ?? []).map((d: any) => ({
        id: d.id,
        title: d.title,
        isProvided: d.isProvided,
        fileUrl: d.fileUrl,
        uploadedAt: d.uploadedAt?.toISOString(),
      })),
      tasks: (c.tasks ?? []).map((t: any) => ({
        id: t.id,
        title: t.title,
        assigneeName: t.assigneeName,
        assigneeRole: t.assigneeRole,
        dueAt: t.dueAt?.toISOString() ?? null,
        status: t.status,
        createdAt: t.createdAt.toISOString(),
      })),
      internalNotes: includeInternal
        ? (c.internalNotes ?? []).map((n: any) => ({
            id: n.id,
            authorName: n.authorName,
            authorRole: n.authorRole,
            body: n.body,
            createdAt: n.createdAt.toISOString(),
          }))
        : [],
      timeline: (c.timelineEvents ?? []).map((e: any) => ({
        id: e.id,
        title: e.title,
        description: e.description,
        status: e.status as CaseStatus,
        createdAt: e.createdAt.toISOString(),
      })),
      messages: (c.messages ?? []).map((m: any) => ({
        id: m.id,
        senderName: m.senderName,
        senderRole: m.senderRole,
        body: m.body,
        createdAt: m.createdAt.toISOString(),
      })),
    };
  }
}
