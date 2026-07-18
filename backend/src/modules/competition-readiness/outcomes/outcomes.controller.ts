import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Req,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';

import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import {
  DEFAULT_APPLICATION_ARTIFACT_MAX_BYTES,
  effectiveArtifactMaxBytes,
} from '../artifacts/artifact-policy.service';
import {
  CompetitionReadinessHttpException,
  idempotencyKeyRequired,
} from '../common/competition-readiness.errors';
import { CreateAdmissionDecisionDto } from './dto/create-admission-decision.dto';
import { CreateFundingDecisionDto } from './dto/create-funding-decision.dto';
import { CreateOutcomeUploadIntentDto } from './dto/create-outcome-upload-intent.dto';
import { CreateSubmissionDto } from './dto/create-submission.dto';
import { LinkOutcomeEvidenceDto } from './dto/link-outcome-evidence.dto';
import {
  OutcomeEvidenceService,
  type UploadedOutcomeEvidenceFile,
} from './outcome-evidence.service';
import {
  OUTCOME_TYPES,
  type OutcomeType,
  OutcomesService,
} from './outcomes.service';

@Controller('competition-readiness')
@UseGuards(StudentAuthGuard)
export class OutcomesController {
  constructor(
    private readonly outcomes: OutcomesService,
    private readonly evidence: OutcomeEvidenceService,
  ) {}

  @Post('workspaces/:id/outcome-evidence/upload-intents')
  async initiateEvidenceUpload(
    @Param('id') workspaceId: string,
    @Body() input: CreateOutcomeUploadIntentDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.evidence.initiateUpload(
      req.studentUser.id,
      workspaceId,
      input,
      this.idempotencyKey(rawIdempotencyKey),
    );
    response.status(result.statusCode);
    return result.intent;
  }

  @Post('outcome-evidence/:id/complete')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: effectiveArtifactMaxBytes(
          DEFAULT_APPLICATION_ARTIFACT_MAX_BYTES,
        ),
      },
    }),
  )
  completeEvidenceUpload(
    @Param('id') evidenceId: string,
    @UploadedFile() file: UploadedOutcomeEvidenceFile | undefined,
    @Req() req: any,
  ) {
    if (!file) {
      throw new CompetitionReadinessHttpException(
        'EVIDENCE_REJECTED',
        400,
        'File is required under multipart field "file".',
      );
    }
    return this.evidence.completeUpload(req.studentUser.id, evidenceId, file);
  }

  @Post('workspaces/:id/submissions')
  async createSubmission(
    @Param('id') workspaceId: string,
    @Body() input: CreateSubmissionDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.outcomes.createSubmission(
      req.studentUser.id,
      workspaceId,
      input,
      this.idempotencyKey(rawIdempotencyKey),
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Get('workspaces/:id/submissions')
  listSubmissions(@Param('id') workspaceId: string, @Req() req: any) {
    return this.outcomes.listSubmissions(req.studentUser.id, workspaceId);
  }

  @Post('workspaces/:id/admission-decisions')
  async createAdmissionDecision(
    @Param('id') workspaceId: string,
    @Body() input: CreateAdmissionDecisionDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.outcomes.createAdmissionDecision(
      req.studentUser.id,
      workspaceId,
      input,
      this.idempotencyKey(rawIdempotencyKey),
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Post('workspaces/:id/funding-decisions')
  async createFundingDecision(
    @Param('id') workspaceId: string,
    @Body() input: CreateFundingDecisionDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.outcomes.createFundingDecision(
      req.studentUser.id,
      workspaceId,
      input,
      this.idempotencyKey(rawIdempotencyKey),
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Get('workspaces/:id/decisions')
  getDecisions(@Param('id') workspaceId: string, @Req() req: any) {
    return this.outcomes.getDecisions(req.studentUser.id, workspaceId);
  }

  @Post('outcomes/:type/:id/evidence')
  async linkEvidence(
    @Param('type') rawType: string,
    @Param('id') outcomeId: string,
    @Body() input: LinkOutcomeEvidenceDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const type = this.outcomeType(rawType);
    const result = await this.outcomes.linkEvidence(
      req.studentUser.id,
      type,
      outcomeId,
      input,
      this.idempotencyKey(rawIdempotencyKey),
    );
    response.status(result.statusCode);
    return result.body;
  }

  private idempotencyKey(raw: string | undefined) {
    const value = raw?.trim();
    if (!value || value.length > 128) throw idempotencyKeyRequired();
    return value;
  }

  private outcomeType(raw: string): OutcomeType {
    if (!OUTCOME_TYPES.includes(raw as OutcomeType)) {
      throw new BadRequestException('Unsupported outcome type.');
    }
    return raw as OutcomeType;
  }
}
