import { Controller, Get, Query } from '@nestjs/common';

import { CatalogService } from './catalog.service';

@Controller('catalog')
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get('fields')
  fields() {
    return this.catalogService.getFields();
  }

  @Get('countries')
  countries() {
    return this.catalogService.getCountries();
  }

  @Get('institutions')
  institutions(
    @Query('countryId') countryId?: string,
    @Query('partnerOnly') partnerOnly?: string,
  ) {
    return this.catalogService.getInstitutions({
      countryId: countryId?.trim() || undefined,
      partnerOnly: partnerOnly === 'true' || partnerOnly === '1',
    });
  }

  @Get('programs')
  programs(
    @Query('q') q?: string,
    @Query('fieldId') fieldId?: string,
    @Query('countryId') countryId?: string,
    @Query('institutionId') institutionId?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.catalogService.getPrograms({
      q: q?.trim() || undefined,
      fieldId: fieldId?.trim() || undefined,
      countryId: countryId?.trim() || undefined,
      institutionId: institutionId?.trim() || undefined,
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
  }

  @Get('scholarships')
  scholarships() {
    return this.catalogService.getScholarships();
  }
}
