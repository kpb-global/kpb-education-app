import {
  Body,
  Controller,
  Delete,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminCatalogService } from './admin-catalog.service';

/// Catalogue write API for the back-office. Read access stays on the public
/// `/catalog/*` controller; these mutations are admin-only.
@Controller('admin/catalog')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager)
export class AdminCatalogController {
  constructor(private readonly service: AdminCatalogService) {}

  // ── Verification (data-trust signal) ──────────────────────────────────────
  @Post('verify')
  setVerification(
    @Body()
    body: { entity: string; id: string; verified?: boolean; sourceUrl?: string },
  ) {
    return this.service.setVerification(
      body.entity,
      body.id,
      body.verified ?? true,
      body.sourceUrl,
    );
  }

  // ── Programs (formations) ─────────────────────────────────────────────────
  @Post('programs')
  createProgram(@Body() input: Record<string, unknown>) {
    return this.service.createProgram(input);
  }

  @Patch('programs/:id')
  updateProgram(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.service.updateProgram(id, input);
  }

  @Delete('programs/:id')
  deleteProgram(@Param('id') id: string) {
    return this.service.deleteProgram(id);
  }

  // ── Institutions (universités) ────────────────────────────────────────────
  @Post('institutions')
  createInstitution(@Body() input: Record<string, unknown>) {
    return this.service.createInstitution(input);
  }

  @Patch('institutions/:id')
  updateInstitution(
    @Param('id') id: string,
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.updateInstitution(id, input);
  }

  @Delete('institutions/:id')
  deleteInstitution(@Param('id') id: string) {
    return this.service.deleteInstitution(id);
  }

  // ── Scholarships (bourses) ────────────────────────────────────────────────
  @Post('scholarships')
  createScholarship(@Body() input: Record<string, unknown>) {
    return this.service.createScholarship(input);
  }

  @Patch('scholarships/:id')
  updateScholarship(
    @Param('id') id: string,
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.updateScholarship(id, input);
  }

  @Delete('scholarships/:id')
  deleteScholarship(@Param('id') id: string) {
    return this.service.deleteScholarship(id);
  }

  // ── Countries (pays) ──────────────────────────────────────────────────────
  @Post('countries')
  createCountry(@Body() input: Record<string, unknown>) {
    return this.service.createCountry(input);
  }

  @Patch('countries/:id')
  updateCountry(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.service.updateCountry(id, input);
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
