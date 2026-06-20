import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';

import { CountriesService } from './countries.service';
import { SubmitCountryQuizDto } from './dto/submit-country-quiz.dto';

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

  @Post(':code/quiz/submit')
  submitQuiz(
    @Param('code') code: string,
    @Body() body: SubmitCountryQuizDto,
  ) {
    return this.countriesService.submitQuiz(code, body.answers);
  }
}
