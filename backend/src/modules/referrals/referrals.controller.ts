import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { RedeemReferralDto } from './dto/redeem-referral.dto';
import { ReferralsService } from './referrals.service';

type AuthedReq = Request & { studentUser?: { id: string } };

@Controller('referrals')
@UseGuards(StudentAuthGuard)
export class ReferralsController {
  constructor(private readonly referralsService: ReferralsService) {}

  /** Caller's stable referral code + attribution stats. */
  @Get('me')
  getMine(@Req() req: AuthedReq) {
    return this.referralsService.getMine(req.studentUser!.id);
  }

  /** Attribute the caller to the owner of an 8-char referral code. */
  @Post('redeem')
  redeem(@Req() req: AuthedReq, @Body() body: RedeemReferralDto) {
    return this.referralsService.redeem(req.studentUser!.id, body.code);
  }
}
