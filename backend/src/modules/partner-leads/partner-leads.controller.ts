import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CreatePartnerLeadDto } from './dto/create-partner-lead.dto';
import { PartnerLeadsService } from './partner-leads.service';

@Controller('partner-leads')
export class PartnerLeadsController {
  constructor(private readonly partnerLeadsService: PartnerLeadsService) {}

  // Admin-only: returns partner-lead PII (name/email/phone/notes).
  @Get()
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
  findAll() {
    return this.partnerLeadsService.findAll();
  }

  // Public lead-capture form — anyone can submit a partnership request.
  @Post()
  create(@Body() input: CreatePartnerLeadDto) {
    return this.partnerLeadsService.create(input);
  }
}
