import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';

import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { idempotencyKeyRequired } from '../common/competition-readiness.errors';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';
import { ListWorkspacesQueryDto } from './dto/list-workspaces-query.dto';
import { UpdateWorkspaceDto } from './dto/update-workspace.dto';
import { UpdateWorkspaceStepDto } from './dto/update-workspace-step.dto';
import { WorkspacesService } from './workspaces.service';

@Controller('competition-readiness')
@UseGuards(StudentAuthGuard)
export class WorkspacesController {
  constructor(private readonly workspacesService: WorkspacesService) {}

  @Get('access')
  getAccess(@Req() req: any) {
    return this.workspacesService.getAccess(req.studentUser.id);
  }

  @Get('workspaces')
  list(@Query() query: ListWorkspacesQueryDto, @Req() req: any) {
    return this.workspacesService.list(req.studentUser.id, query);
  }

  @Post('workspaces')
  async create(
    @Body() input: CreateWorkspaceDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const idempotencyKey = rawIdempotencyKey?.trim();
    if (!idempotencyKey || idempotencyKey.length > 128) {
      throw idempotencyKeyRequired();
    }
    const result = await this.workspacesService.create(
      req.studentUser.id,
      input,
      idempotencyKey,
    );
    response.status(result.statusCode);
    response.setHeader('ETag', this.etag(result.workspace.version));
    return result.workspace;
  }

  @Get('workspaces/:id')
  async getOne(
    @Param('id') id: string,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const workspace = await this.workspacesService.getOne(
      req.studentUser.id,
      id,
    );
    response.setHeader('ETag', this.etag(workspace.version));
    return workspace;
  }

  @Patch('workspaces/:id')
  async updateLifecycle(
    @Param('id') id: string,
    @Body() input: UpdateWorkspaceDto,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const workspace = await this.workspacesService.updateLifecycle(
      req.studentUser.id,
      id,
      input,
    );
    response.setHeader('ETag', this.etag(workspace.version));
    return workspace;
  }

  @Put('workspaces/:id/steps/:stepId')
  async updateStep(
    @Param('id') id: string,
    @Param('stepId') stepId: string,
    @Body() input: UpdateWorkspaceStepDto,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const workspace = await this.workspacesService.updateStep(
      req.studentUser.id,
      id,
      stepId,
      input,
    );
    response.setHeader('ETag', this.etag(workspace.version));
    return workspace;
  }

  private etag(version: number) {
    return `W/"${version}"`;
  }
}
