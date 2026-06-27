import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { RedeemReferralDto } from './dto/redeem-referral.dto';
import { RedeemVoucherDto } from './dto/redeem-voucher.dto';
import { ReferralCreditsService } from './referral-credits.service';
import { ReferralsService } from './referrals.service';

type AuthedReq = Request & { studentUser?: { id: string } };

@Controller('referrals')
@UseGuards(StudentAuthGuard)
export class ReferralsController {
  constructor(
    private readonly referralsService: ReferralsService,
    private readonly referralCreditsService: ReferralCreditsService,
  ) {}

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

  /** Caller's no-cash reward balance + recent ledger entries (KPB-77). */
  @Get('credits')
  getCredits(@Req() req: AuthedReq) {
    return this.referralCreditsService.getCredits(req.studentUser!.id);
  }

  /** Spend credits to mint a WhatsApp advisor review voucher (no cash). */
  @Post('credits/redeem-voucher')
  redeemVoucher(@Req() req: AuthedReq, @Body() body: RedeemVoucherDto) {
    return this.referralCreditsService.redeemReviewVoucher(
      req.studentUser!.id,
      body.clientRef,
    );
  }
}
