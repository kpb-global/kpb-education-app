import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Req,
  Res,
  UseGuards,
} from "@nestjs/common";
import type { Response } from "express";

import { StudentAuthGuard } from "../../../common/guards/student-auth.guard";
import { idempotencyKeyRequired } from "../common/competition-readiness.errors";
import { AiDiagnosticsService } from "./ai-diagnostics.service";
import { CreateAiDiagnosticDto } from "./dto/create-ai-diagnostic.dto";

@Controller("competition-readiness")
@UseGuards(StudentAuthGuard)
export class AiDiagnosticsController {
  constructor(private readonly diagnostics: AiDiagnosticsService) {}

  @Get("workspaces/:id/diagnostic")
  getExisting(@Param("id") workspaceId: string, @Req() req: any) {
    return this.diagnostics.getExisting(req.studentUser.id, workspaceId);
  }

  @Post("workspaces/:id/diagnostic")
  async create(
    @Param("id") workspaceId: string,
    @Body() input: CreateAiDiagnosticDto,
    @Headers("idempotency-key") rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const idempotencyKey = rawIdempotencyKey?.trim();
    if (!idempotencyKey || idempotencyKey.length > 128) {
      throw idempotencyKeyRequired();
    }
    const result = await this.diagnostics.create(
      req.studentUser.id,
      workspaceId,
      input,
      idempotencyKey,
    );
    response.status(result.statusCode);
    return result.body;
  }
}
