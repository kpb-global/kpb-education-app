import { Controller, Get, Query } from '@nestjs/common';

import { VisaAvailabilityService } from './visa-availability.service';

/**
 * Public visa-availability endpoint consumed by the mobile app.
 *
 * Returns one row per consulate with the latest known status. No auth —
 * the data is intentionally coarse-grained (status enum + optional next
 * available date) so it can be served unauthenticated.
 */
@Controller('visa-availability')
export class VisaAvailabilityController {
  constructor(
    private readonly visaAvailabilityService: VisaAvailabilityService,
  ) {}

  @Get()
  list(@Query('country') country?: string) {
    return this.visaAvailabilityService.listPublic({ countryCode: country });
  }
}
