import {
  Body,
  Controller,
  Delete,
  Get,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
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

  /**
   * Retire la déclaration du profil appelant.
   *
   * Le pendant du consentement, et il n'existait pas. Le texte de la feuille
   * promettait « tu peux te retirer à tout moment » alors que les seules issues
   * réelles étaient d'écrire à une adresse générique ou de supprimer son compte
   * entier. Un consentement qu'on ne peut pas révoquer n'en est pas un.
   *
   * Aucun paramètre d'identité : l'id vient du jeton vérifié, comme les deux
   * routes au-dessus. Un `userId` accepté dans le corps ou l'URL laisserait un
   * étudiant retirer la déclaration d'un autre.
   */
  @Delete('interest')
  withdraw(@Req() req: AuthedReq) {
    return this.etudesEnFranceService.withdraw(req.studentUser!.id);
  }
}
