import { Controller, Get } from '@nestjs/common';
import { ImpactService } from './impact.service';

@Controller('impact')
export class ImpactController {
  constructor(private readonly impactService: ImpactService) {}

  // Public endpoint — no auth, so it can also feed a marketing/landing page.
  @Get('stats')
  getStats() {
    return this.impactService.getStats();
  }

  // Public endpoint — top published reviews powering the Home social-proof
  // carousel. Capped at 10; returns public-safe fields only (no PII).
  @Get('reviews')
  getPublishedReviews() {
    return this.impactService.getPublishedReviews(10);
  }
}
