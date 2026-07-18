import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
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
  CompetitionReadinessHttpException,
  idempotencyKeyRequired,
} from '../common/competition-readiness.errors';
import {
  ApplicationArtifactsService,
  type UploadedArtifactFile,
} from './application-artifacts.service';
import {
  DEFAULT_APPLICATION_ARTIFACT_MAX_BYTES,
  effectiveArtifactMaxBytes,
} from './artifact-policy.service';
import { CreateArtifactUploadIntentDto } from './dto/create-artifact-upload-intent.dto';
import { DeleteArtifactVersionDto } from './dto/delete-artifact-version.dto';

@Controller('competition-readiness')
@UseGuards(StudentAuthGuard)
export class ApplicationArtifactsController {
  constructor(private readonly artifacts: ApplicationArtifactsService) {}

  @Get('workspaces/:id/artifacts')
  list(@Param('id') workspaceId: string, @Req() req: any) {
    return this.artifacts.list(req.studentUser.id, workspaceId);
  }

  @Post('workspaces/:id/artifacts/upload-intents')
  async initiateUpload(
    @Param('id') workspaceId: string,
    @Body() input: CreateArtifactUploadIntentDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const idempotencyKey = rawIdempotencyKey?.trim();
    if (!idempotencyKey || idempotencyKey.length > 128) {
      throw idempotencyKeyRequired();
    }
    const result = await this.artifacts.initiateUpload(
      req.studentUser.id,
      workspaceId,
      input,
      idempotencyKey,
    );
    response.status(result.statusCode);
    return result.intent;
  }

  @Post('artifact-versions/:id/complete')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: effectiveArtifactMaxBytes(
          DEFAULT_APPLICATION_ARTIFACT_MAX_BYTES,
        ),
      },
    }),
  )
  completeUpload(
    @Param('id') versionId: string,
    @UploadedFile() file: UploadedArtifactFile | undefined,
    @Req() req: any,
  ) {
    if (!file) {
      throw new CompetitionReadinessHttpException(
        'ARTIFACT_KIND_NOT_ALLOWED',
        400,
        'File is required under multipart field "file".',
      );
    }
    return this.artifacts.completeUpload(req.studentUser.id, versionId, file);
  }

  @Get('artifact-versions/:id/download')
  async download(
    @Param('id') versionId: string,
    @Req() req: any,
    @Res() response: Response,
  ): Promise<void> {
    const download = await this.artifacts.getDownload(
      req.studentUser.id,
      versionId,
    );
    response.setHeader('Content-Type', download.object.mimeType);
    response.setHeader(
      'Content-Disposition',
      `attachment; filename*=UTF-8''${encodeURIComponent(download.fileName)}`,
    );
    response.setHeader('Cache-Control', 'private, no-store, max-age=0');
    response.setHeader('Pragma', 'no-cache');
    response.setHeader('Expires', '0');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
    response.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    if (download.object.sizeBytes !== undefined) {
      response.setHeader(
        'Content-Length',
        download.object.sizeBytes.toString(),
      );
    }
    download.object.stream.on('error', () => {
      if (!response.headersSent) response.status(503).end();
      else response.destroy();
    });
    download.object.stream.pipe(response);
  }

  @Delete('artifact-versions/:id')
  @HttpCode(204)
  async deleteVersion(
    @Param('id') versionId: string,
    @Body() input: DeleteArtifactVersionDto,
    @Req() req: any,
  ): Promise<void> {
    await this.artifacts.deleteVersion(
      req.studentUser.id,
      versionId,
      input.reason,
    );
  }
}
