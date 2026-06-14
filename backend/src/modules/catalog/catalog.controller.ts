import { Controller, Get } from '@nestjs/common';

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
  institutions() {
    return this.catalogService.getInstitutions();
  }

  @Get('programs')
  programs() {
    return this.catalogService.getPrograms();
  }

  @Get('scholarships')
  scholarships() {
    return this.catalogService.getScholarships();
  }
}
