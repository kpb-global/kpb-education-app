import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { MatchesService } from './matches.service';

// Phase 0 / P0-D (kit US-003/US-004): deterministic admission-probability
// matches. Kit route names kept verbatim so the public contract matches
// API_CONTRACTS.md — "school" maps internally to Institution (decision D3).
@Controller('matches')
@UseGuards(StudentAuthGuard)
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  // The static route must be declared before the parameterized one so Nest
  // doesn't swallow "aha-moment" as an :institutionId.
  @Get('aha-moment')
  ahaMoment(
    @Req() req: any,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.matchesService.ahaMoment(req.studentUser?.id, limit);
  }

  @Get('school/:institutionId')
  schoolMatch(@Req() req: any, @Param('institutionId') institutionId: string) {
    return this.matchesService.schoolMatch(req.studentUser?.id, institutionId);
  }
}
