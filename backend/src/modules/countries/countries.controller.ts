import { Controller, Get, Param, Query } from '@nestjs/common';

import { CountriesService } from './countries.service';

@Controller('countries')
export class CountriesController {
  constructor(private readonly countriesService: CountriesService) {}

  @Get()
  list(@Query('active') active?: string) {
    const activeOnly = active !== 'false' && active !== '0';
    return this.countriesService.listCountries(activeOnly);
  }

  @Get(':code')
  detail(@Param('code') code: string) {
    return this.countriesService.getCountryDetail(code);
  }

  // POST :code/quiz/submit removed (KPB-62): eligibility is scored client-side
  // by the single EligibilityEngine. The quiz questions/verdict copy are still
  // served via GET :code (country detail).
}
