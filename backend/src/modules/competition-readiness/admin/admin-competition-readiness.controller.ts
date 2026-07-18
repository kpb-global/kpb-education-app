import { randomUUID } from 'node:crypto';

import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Request, Response } from 'express';

import { Roles } from '../../../common/decorators/roles.decorator';
import { InternalRole } from '../../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import type { AdminSessionUser } from '../../auth/auth.service';
import { idempotencyKeyRequired } from '../common/competition-readiness.errors';
import { StudyReviewSchedulingService } from '../reviews/study-review-scheduling.service';
import { AdminAiUsageService } from './admin-ai-usage.service';
import { AdminAvailabilityService } from './admin-availability.service';
import { AdminEvidenceService } from './admin-evidence.service';
import { AdminOutcomeEvidenceService } from './admin-outcome-evidence.service';
import { AdminOutcomesService } from './admin-outcomes.service';
import { AdminPartnershipsService } from './admin-partnerships.service';
import { AdminReviewOperationsService } from './admin-review-operations.service';
import { AiUsageQueryDto } from './dto/ai-usage-query.dto';
import {
  CancelAvailabilitySlotDto,
  CreateAvailabilitySlotDto,
  ListAvailabilitySlotsDto,
} from './dto/availability-slot.dto';
import { ConvertReviewToCaseDto } from './dto/convert-review-to-case.dto';
import {
  EvidenceAccessQueryDto,
  EvidenceDownloadQueryDto,
  OutcomeEvidenceAccessQueryDto,
} from './dto/evidence-access-query.dto';
import { ListAdminOutcomesDto } from './dto/list-admin-outcomes.dto';
import { ListAdminReviewRequestsDto } from './dto/list-admin-review-requests.dto';
import { OfferReviewSlotsDto } from './dto/offer-review-slots.dto';
import { TriageReviewRequestDto } from './dto/triage-review-request.dto';
import { UpdateOutcomeVerificationDto } from './dto/update-outcome-verification.dto';
import {
  CreatePartnerAgreementDto,
  CreatePartnerAgreementEvidenceDto,
  ListPartnerAgreementsDto,
  UpdatePartnerAgreementDto,
} from './dto/partner-agreement.dto';
import {
  CreateExperimentAssignmentDto,
  CreateImpactCohortDto,
  CreateImpactDataRoomExportDto,
  CreateImpactPilotDto,
  CreatePilotAssessmentDto,
  EnrolImpactCohortMemberDto,
  FreezeImpactSnapshotDto,
  ImpactReportQueryDto,
  ListImpactPilotsDto,
  ListImpactDataRoomExportsDto,
  UpdateImpactPilotDto,
  WithdrawImpactCohortMemberDto,
} from './dto/impact-pilot.dto';
import {
  OUTCOME_TYPES,
  type OutcomeType,
} from '../outcomes/outcomes.service';
import { ImpactPilotsService } from '../pilots/impact-pilots.service';
import { ImpactSnapshotService } from '../pilots/impact-snapshot.service';

type AdminRequest = Request & { adminUser: AdminSessionUser };

@Controller('admin/competition-readiness')
@UseGuards(AdminAuthGuard, RolesGuard)
export class AdminCompetitionReadinessController {
  constructor(
    private readonly reviews: AdminReviewOperationsService,
    private readonly evidence: AdminEvidenceService,
    private readonly aiUsage: AdminAiUsageService,
    private readonly availability: AdminAvailabilityService,
    private readonly scheduling: StudyReviewSchedulingService,
    private readonly outcomes: AdminOutcomesService,
    private readonly outcomeEvidence: AdminOutcomeEvidenceService,
    private readonly partnerships: AdminPartnershipsService,
    private readonly pilots: ImpactPilotsService,
    private readonly impactSnapshots: ImpactSnapshotService,
  ) {}

  @Get('counsellors')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  listCounsellors(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query('activeOnly') rawActiveOnly?: string,
    @Query('reviewRequestId') reviewRequestId?: string,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    if (
      rawActiveOnly !== undefined &&
      rawActiveOnly !== 'true' &&
      rawActiveOnly !== 'false'
    ) {
      throw new BadRequestException('activeOnly must be true or false.');
    }
    if (
      reviewRequestId !== undefined &&
      (!reviewRequestId.trim() || reviewRequestId.length > 120)
    ) {
      throw new BadRequestException('reviewRequestId is invalid.');
    }
    return this.availability.listCounsellors(
      request.adminUser,
      rawActiveOnly !== 'false',
      reviewRequestId,
    );
  }

  @Get('availability-slots')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  listAvailabilitySlots(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query() query: ListAvailabilitySlotsDto,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.availability.list(request.adminUser, query);
  }

  @Post('availability-slots')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  async createAvailabilitySlot(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Body() input: CreateAvailabilitySlotDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const idempotencyKey = this.requireIdempotencyKey(request);
    const result = await this.availability.create(
      request.adminUser,
      input,
      idempotencyKey,
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Patch('availability-slots/:id/cancel')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  cancelAvailabilitySlot(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Body() input: CancelAvailabilitySlotDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.availability.cancel(
      request.adminUser,
      id,
      input,
      requestId,
    );
  }

  @Get('review-requests')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Commercial,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  listReviewRequests(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query() query: ListAdminReviewRequestsDto,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.reviews.list(request.adminUser, query);
  }

  @Get('review-requests/:id')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Commercial,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  getReviewRequest(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.reviews.getDetail(request.adminUser, id);
  }

  @Patch('review-requests/:id/triage')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  triageReviewRequest(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Body() input: TriageReviewRequestDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.reviews.triage(request.adminUser, id, input, requestId);
  }

  @Post('review-requests/:id/slot-offers')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  async offerReviewSlots(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Body() input: OfferReviewSlotsDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.scheduling.offerSlots(
      request.adminUser,
      id,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Post('review-requests/:id/convert-to-case')
  @Roles(
    InternalRole.Commercial,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  async convertReviewToCase(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Body() input: ConvertReviewToCaseDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const header = request.headers['idempotency-key'];
    const idempotencyKey = Array.isArray(header) ? header[0] : header;
    if (!idempotencyKey?.trim() || idempotencyKey.length > 200) {
      throw idempotencyKeyRequired();
    }
    const result = await this.reviews.convertToCase(
      request.adminUser,
      id,
      input,
      idempotencyKey,
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Get('evidence/:versionId/file')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  issueEvidenceAccess(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('versionId') versionId: string,
    @Query() query: EvidenceAccessQueryDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    response.setHeader('Pragma', 'no-cache');
    return this.evidence.issueAccess(
      request.adminUser,
      versionId,
      query.purposeCode,
      requestId,
    );
  }

  @Get('evidence/:versionId/download')
  @Roles(
    InternalRole.Counselor,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  async downloadEvidence(
    @Req() request: AdminRequest,
    @Res() response: Response,
    @Param('versionId') versionId: string,
    @Query() query: EvidenceDownloadQueryDto,
  ): Promise<void> {
    const requestId = this.attachRequestId(request, response);
    const result = await this.evidence.download(
      request.adminUser,
      versionId,
      query.accessToken,
      requestId,
    );
    response.setHeader('Content-Type', result.object.mimeType);
    response.setHeader(
      'Content-Disposition',
      `attachment; filename*=UTF-8''${encodeURIComponent(this.safeFileName(result.fileName))}`,
    );
    response.setHeader('Cache-Control', 'private, no-store, max-age=0');
    response.setHeader('Pragma', 'no-cache');
    response.setHeader('Expires', '0');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
    response.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    if (result.object.sizeBytes !== undefined) {
      response.setHeader('Content-Length', result.object.sizeBytes.toString());
    }
    result.object.stream.on('error', () => {
      if (!response.headersSent) response.status(503).end();
      else response.destroy();
    });
    result.object.stream.pipe(response);
  }

  @Get('outcomes')
  @Roles(InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin)
  listOutcomes(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query() query: ListAdminOutcomesDto,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.outcomes.list(request.adminUser, query);
  }

  @Get('outcomes/:type/:id')
  @Roles(InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin)
  getOutcome(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('type') rawType: string,
    @Param('id') id: string,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.outcomes.detail(
      request.adminUser,
      this.outcomeType(rawType),
      id,
    );
  }

  @Patch('outcomes/:type/:id/verification')
  @Roles(InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin)
  verifyOutcome(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('type') rawType: string,
    @Param('id') id: string,
    @Body() input: UpdateOutcomeVerificationDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.outcomes.verify(
      request.adminUser,
      this.outcomeType(rawType),
      id,
      input,
      requestId,
    );
  }

  @Get('outcome-evidence/:evidenceId/file')
  @Roles(InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin)
  issueOutcomeEvidenceAccess(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('evidenceId') evidenceId: string,
    @Query() _query: OutcomeEvidenceAccessQueryDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    response.setHeader('Pragma', 'no-cache');
    return this.outcomeEvidence.issueAccess(
      request.adminUser,
      evidenceId,
      requestId,
    );
  }

  @Get('outcome-evidence/:evidenceId/download')
  @Roles(InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin)
  async downloadOutcomeEvidence(
    @Req() request: AdminRequest,
    @Res() response: Response,
    @Param('evidenceId') evidenceId: string,
    @Query() query: EvidenceDownloadQueryDto,
  ): Promise<void> {
    const requestId = this.attachRequestId(request, response);
    const result = await this.outcomeEvidence.download(
      request.adminUser,
      evidenceId,
      query.accessToken,
      requestId,
    );
    response.setHeader('Content-Type', result.object.mimeType);
    response.setHeader(
      'Content-Disposition',
      `attachment; filename*=UTF-8''${encodeURIComponent(this.safeFileName(result.fileName))}`,
    );
    response.setHeader('Cache-Control', 'private, no-store, max-age=0');
    response.setHeader('Pragma', 'no-cache');
    response.setHeader('Expires', '0');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
    response.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    if (result.object.sizeBytes !== undefined) {
      response.setHeader('Content-Length', result.object.sizeBytes.toString());
    }
    result.object.stream.on('error', () => {
      if (!response.headersSent) response.status(503).end();
      else response.destroy();
    });
    result.object.stream.pipe(response);
  }

  @Get('ai/usage')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  getAiUsage(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query() query: AiUsageQueryDto,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.aiUsage.getUsage(request.adminUser, query);
  }

  @Get('partner-agreements')
  @Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
  listPartnerAgreements(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query() query: ListPartnerAgreementsDto,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.partnerships.list(request.adminUser, query);
  }

  @Post('partner-agreements')
  @Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
  async createPartnerAgreement(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Body() input: CreatePartnerAgreementDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.partnerships.create(
      request.adminUser,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Patch('partner-agreements/:id')
  @Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
  async revisePartnerAgreement(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Body() input: UpdatePartnerAgreementDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.partnerships.revise(
      request.adminUser,
      id,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Post('partner-agreements/:id/evidence')
  @Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
  async addPartnerAgreementEvidence(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Body() input: CreatePartnerAgreementEvidenceDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.partnerships.addEvidence(
      request.adminUser,
      id,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Get('pilots')
  @Roles(
    InternalRole.Commercial,
    InternalRole.Moderator,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  listImpactPilots(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query() query: ListImpactPilotsDto,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.pilots.list(request.adminUser, query);
  }

  @Post('pilots')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  async createImpactPilot(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Body() input: CreateImpactPilotDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.pilots.create(
      request.adminUser,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Patch('pilots/:id')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  async updateImpactPilot(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Body() input: UpdateImpactPilotDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.pilots.update(
      request.adminUser,
      id,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Get('pilots/:id/cohorts')
  @Roles(
    InternalRole.Commercial,
    InternalRole.Moderator,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  listImpactCohorts(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.pilots.listCohorts(request.adminUser, id);
  }

  @Post('pilots/:id/cohorts')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  async createImpactCohort(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Body() input: CreateImpactCohortDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.pilots.createCohort(
      request.adminUser,
      id,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Post('pilots/:id/cohorts/:cohortId/memberships')
  @Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
  async enrolImpactCohortMember(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Param('cohortId') cohortId: string,
    @Body() input: EnrolImpactCohortMemberDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.pilots.enrol(
      request.adminUser,
      id,
      cohortId,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Patch('pilots/:id/cohorts/:cohortId/memberships/:membershipId/withdraw')
  @Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
  async withdrawImpactCohortMember(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Param('cohortId') cohortId: string,
    @Param('membershipId') membershipId: string,
    @Body() input: WithdrawImpactCohortMemberDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.pilots.withdraw(
      request.adminUser,
      id,
      cohortId,
      membershipId,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Post('pilots/:id/cohorts/:cohortId/memberships/:membershipId/assignment')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  async assignImpactExperiment(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Param('cohortId') cohortId: string,
    @Param('membershipId') membershipId: string,
    @Body() input: CreateExperimentAssignmentDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.pilots.assignExperiment(
      request.adminUser,
      id,
      cohortId,
      membershipId,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Post('pilots/:id/cohorts/:cohortId/memberships/:membershipId/assessments')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  async recordPilotAssessment(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Param('cohortId') cohortId: string,
    @Param('membershipId') membershipId: string,
    @Body() input: CreatePilotAssessmentDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.pilots.assess(
      request.adminUser,
      id,
      cohortId,
      membershipId,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Get('pilots/:id/snapshots')
  @Roles(InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin)
  listImpactSnapshots(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.impactSnapshots.listSnapshots(request.adminUser, id);
  }

  @Post('pilots/:id/snapshots')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  async freezeImpactSnapshot(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Param('id') id: string,
    @Body() input: FreezeImpactSnapshotDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.impactSnapshots.freeze(
      request.adminUser,
      id,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Get('reports')
  @Roles(InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin)
  getCompetitionReadinessReport(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query() query: ImpactReportQueryDto,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.impactSnapshots.report(request.adminUser, query);
  }

  @Get('data-room-exports')
  @Roles(InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin)
  listImpactDataRoomExports(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query() query: ListImpactDataRoomExportsDto,
  ) {
    this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.impactSnapshots.listDataRoomExports(request.adminUser, query);
  }

  @Post('data-room-exports')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  async createImpactDataRoomExport(
    @Req() request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Body() input: CreateImpactDataRoomExportDto,
  ) {
    const requestId = this.attachRequestId(request, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.impactSnapshots.createDataRoomExport(
      request.adminUser,
      input,
      this.requireIdempotencyKey(request),
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  private attachRequestId(request: AdminRequest, response: Response): string {
    const header = request.headers['x-request-id'];
    const candidate = Array.isArray(header) ? header[0] : header;
    const requestId =
      candidate && /^[A-Za-z0-9._:-]{1,120}$/.test(candidate)
        ? candidate
        : randomUUID();
    response.setHeader('X-Request-Id', requestId);
    return requestId;
  }

  private requireIdempotencyKey(request: AdminRequest): string {
    const header = request.headers['idempotency-key'];
    const key = Array.isArray(header) ? header[0] : header;
    if (!key?.trim() || key.length > 200) throw idempotencyKeyRequired();
    return key;
  }

  private safeFileName(value: string): string {
    const cleaned = value.replace(/[\r\n/\\]/g, '_').trim();
    return cleaned || 'evidence';
  }

  private outcomeType(raw: string): OutcomeType {
    if (!OUTCOME_TYPES.includes(raw as OutcomeType)) {
      throw new BadRequestException('Unsupported outcome type.');
    }
    return raw as OutcomeType;
  }
}
