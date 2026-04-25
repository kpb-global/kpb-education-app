import { Body, Controller, Get, Post } from '@nestjs/common';

import { CreatePartnerLeadDto } from './dto/create-partner-lead.dto';
import { PartnerLeadsService } from './partner-leads.service';

@Controller('partner-leads')
export class PartnerLeadsController {
  constructor(private readonly partnerLeadsService: PartnerLeadsService) {}

  @Get()
  findAll() {
    return this.partnerLeadsService.findAll();
  }

  @Post()
  create(@Body() input: CreatePartnerLeadDto) {
    return this.partnerLeadsService.create(input);
  }
}
