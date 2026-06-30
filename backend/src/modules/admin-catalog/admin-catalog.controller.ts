import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import type { AdminSessionUser } from '../auth/auth.service';
import { AdminCatalogService } from './admin-catalog.service';

type AdminReq = Request & { adminUser?: AdminSessionUser };

/// Catalogue write API for the back-office. Read access stays on the public
/// `/catalog/*` controller; these mutations are admin-only.
@Controller('admin/catalog')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager)
export class AdminCatalogController {
  constructor(private readonly service: AdminCatalogService) {}

  private verifier(req: AdminReq): AdminSessionUser {
    return (
      req.adminUser ?? {
        id: 'unknown-admin',
        fullName: 'Unknown admin',
        email: 'unknown-admin@kpb.education',
        role: InternalRole.Admin,
        languageScope: [],
      }
    );
  }

  // ── Read / list (full-fidelity for the back-office) ───────────────────────
  @Get('verification-due')
  listVerificationDue() {
    return this.service.listVerificationDue();
  }

  @Get('programs')
  listPrograms(
    @Query('q') q?: string,
    @Query('countryId') countryId?: string,
    @Query('fieldId') fieldId?: string,
    @Query('institutionId') institutionId?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.service.listPrograms({
      q: q?.trim() || undefined,
      countryId: countryId?.trim() || undefined,
      fieldId: fieldId?.trim() || undefined,
      institutionId: institutionId?.trim() || undefined,
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
  }

  @Get('institutions')
  listInstitutions(@Query('countryId') countryId?: string) {
    return this.service.listInstitutions(countryId?.trim() || undefined);
  }

  @Get('scholarships')
  listScholarships() {
    return this.service.listScholarships();
  }

  @Get('countries')
  listCountries() {
    return this.service.listCountries();
  }

  @Get('fields')
  listFields() {
    return this.service.listFields();
  }

  // ── Programs (formations) ─────────────────────────────────────────────────
  @Post('programs')
  createProgram(@Req() req: AdminReq, @Body() input: Record<string, unknown>) {
    return this.service.createProgram(input, this.verifier(req));
  }

  @Patch('programs/:id')
  updateProgram(
    @Req() req: AdminReq,
    @Param('id') id: string,
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.updateProgram(id, input, this.verifier(req));
  }

  @Delete('programs/:id')
  deleteProgram(@Param('id') id: string) {
    return this.service.deleteProgram(id);
  }

  // ── Institutions (universités) ────────────────────────────────────────────
  @Post('institutions')
  createInstitution(
    @Req() req: AdminReq,
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.createInstitution(input, this.verifier(req));
  }

  @Patch('institutions/:id')
  updateInstitution(
    @Req() req: AdminReq,
    @Param('id') id: string,
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.updateInstitution(id, input, this.verifier(req));
  }

  @Delete('institutions/:id')
  deleteInstitution(@Param('id') id: string) {
    return this.service.deleteInstitution(id);
  }

  // ── Scholarships (bourses) ────────────────────────────────────────────────
  @Post('scholarships')
  createScholarship(
    @Req() req: AdminReq,
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.createScholarship(input, this.verifier(req));
  }

  @Patch('scholarships/:id')
  updateScholarship(
    @Req() req: AdminReq,
    @Param('id') id: string,
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.updateScholarship(id, input, this.verifier(req));
  }

  @Delete('scholarships/:id')
  deleteScholarship(@Param('id') id: string) {
    return this.service.deleteScholarship(id);
  }

  // ── Countries (pays) ──────────────────────────────────────────────────────
  @Post('countries')
  createCountry(@Req() req: AdminReq, @Body() input: Record<string, unknown>) {
    return this.service.createCountry(input, this.verifier(req));
  }

  @Patch('countries/:id')
  updateCountry(
    @Req() req: AdminReq,
    @Param('id') id: string,
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.updateCountry(id, input, this.verifier(req));
  }

  @Delete('countries/:id')
  deleteCountry(@Param('id') id: string) {
    return this.service.deleteCountry(id);
  }

  // ── Fields (filières) ─────────────────────────────────────────────────────
  @Post('fields')
  createField(@Body() input: Record<string, unknown>) {
    return this.service.createField(input);
  }

  @Patch('fields/:id')
  updateField(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.service.updateField(id, input);
  }

  @Delete('fields/:id')
  deleteField(@Param('id') id: string) {
    return this.service.deleteField(id);
  }
}
