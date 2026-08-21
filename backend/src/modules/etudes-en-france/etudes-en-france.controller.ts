import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { DeclareEefInterestDto } from './dto/declare-eef-interest.dto';
import { EtudesEnFranceService } from './etudes-en-france.service';

type AuthedReq = Request & { studentUser?: { id: string } };

/**
 * Espace « Études en France » — Phase 0 (la vitrine).
 *
 * Authentifié, volontairement : une déclaration d'intérêt sans identité ne
 * serait pas rappelable, et c'est précisément ce qu'on cherche à collecter. La
 * vitrine invite donc à se connecter avant de proposer le bouton, plutôt que
 * d'accepter des lignes anonymes qui gonfleraient le compteur sans donner un
 * seul contact.
 */
@Controller('etudes-en-france')
@UseGuards(StudentAuthGuard)
export class EtudesEnFranceController {
  constructor(
    private readonly etudesEnFranceService: EtudesEnFranceService,
  ) {}

  /** La déclaration du profil appelant, ou l'état « pas déclaré ». */
  @Get('interest')
  getMyInterest(@Req() req: AuthedReq) {
    return this.etudesEnFranceService.getMyInterest(req.studentUser!.id);
  }

  /** Déclare (ou met à jour) l'intérêt du profil appelant. */
  @Post('interest')
  declareInterest(
    @Req() req: AuthedReq,
    @Body() body: DeclareEefInterestDto,
  ) {
    return this.etudesEnFranceService.declareInterest(
      req.studentUser!.id,
      body,
    );
  }
}
