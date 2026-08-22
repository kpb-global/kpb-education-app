import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { DeclareEefInterestDto } from './dto/declare-eef-interest.dto';
import { EtudesEnFranceService } from './etudes-en-france.service';

type AuthedReq = Request & {
  studentUser?: { id: string; accountType?: string };
};

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

  /**
   * Refuse l'ÉCRITURE aux comptes qui ne sont pas des comptes étudiants.
   *
   * ## Pourquoi le garde ne suffit pas
   *
   * `StudentAuthGuard` s'appelle « student » mais authentifie aussi les comptes
   * `parent` et `partner` — son propre commentaire le dit, et c'est voulu :
   * beaucoup de routes servent légitimement les deux. Ici non. La déclaration
   * d'intérêt écrit les coordonnées du profil APPELANT dans une liste que
   * l'équipe rappelle, et le back-office la présente comme une liste
   * d'étudiants. Un parent qui tape « ça m'intéresse » y ferait entrer ses
   * nom, e-mail et téléphone : le conseiller rappellerait la mauvaise personne,
   * au sujet des études de quelqu'un d'autre.
   *
   * Contrôlé ici et non dans le garde, pour ne pas fermer aux parents les
   * autres routes qui les servent à dessein. Le dépôt a le même motif ailleurs
   * (`feature-access.service.ts`, politique `studentOnly`).
   *
   * La LECTURE reste ouverte : elle rend « pas déclaré » pour un parent, ce qui
   * est vrai et sans effet. La fermer produirait un 403 que le client avale en
   * silence, donc une erreur invisible pour un non-problème.
   */
  private assertStudent(req: AuthedReq) {
    const accountType = req.studentUser?.accountType;
    if (accountType && accountType !== 'student') {
      throw new ForbiddenException(
        'Only student accounts can declare interest in this space.',
      );
    }
  }

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
    this.assertStudent(req);
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
    // Le retrait est aussi une écriture. Un parent n'a rien à retirer puisqu'il
    // n'a rien pu écrire, mais laisser la porte ouverte inviterait à croire que
    // la règle ne vaut que pour la création.
    this.assertStudent(req);
    return this.etudesEnFranceService.withdraw(req.studentUser!.id);
  }
}
