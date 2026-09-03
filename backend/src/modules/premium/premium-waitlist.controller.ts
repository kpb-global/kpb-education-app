import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Header,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { JoinPremiumWaitlistDto } from './dto/join-premium-waitlist.dto';
import { PremiumWaitlistService } from './premium-waitlist.service';

type AuthedReq = Request & {
  studentUser?: { id: string; accountType?: string };
};

/**
 * Liste d'attente Karatou Premium.
 *
 * Authentifié, volontairement : une inscription anonyme gonflerait le compteur
 * sans donner un seul contact à prévenir le jour de l'ouverture — or prévenir
 * est l'unique promesse faite à l'écran. C'est le même choix que pour l'espace
 * « Études en France », et pour la même raison.
 *
 * Aucune route de paiement, ici ni ailleurs : Karatou n'encaisse rien dans
 * l'application.
 */
@Controller('premium/waitlist')
@UseGuards(StudentAuthGuard)
export class PremiumWaitlistController {
  constructor(
    private readonly premiumWaitlistService: PremiumWaitlistService,
  ) {}

  /**
   * Refuse l'ÉCRITURE aux comptes qui ne sont pas des comptes étudiants.
   *
   * `StudentAuthGuard` s'appelle « student » mais authentifie aussi les comptes
   * `parent` et `partner` — c'est voulu, beaucoup de routes servent
   * légitimement les deux. Ici non : la liste est présentée au back-office
   * comme une liste d'étudiants à prévenir, et un parent qui tape « préviens-
   * moi » y ferait entrer ses propres coordonnées. Le conseiller rappellerait
   * la mauvaise personne au sujet des études de quelqu'un d'autre, et le
   * compteur qui sert à dimensionner le lancement compterait des gens qui ne
   * sont pas le public visé.
   *
   * Contrôlé ici et non dans le garde, pour ne pas fermer aux parents les
   * autres routes qui les servent à dessein — même motif que
   * `etudes-en-france.controller.ts` et que la politique `studentOnly` de
   * `feature-access.service.ts`.
   *
   * La LECTURE reste ouverte : elle rend « pas inscrit » pour un parent, ce qui
   * est vrai et sans effet. La fermer produirait un 403 que le client avale en
   * silence, donc une erreur invisible pour un non-problème.
   */
  private assertStudent(req: AuthedReq) {
    const accountType = req.studentUser?.accountType;
    if (accountType && accountType !== 'student') {
      throw new ForbiddenException(
        'Only student accounts can join the Premium waitlist.',
      );
    }
  }

  /** L'inscription du profil appelant, ou l'état « pas inscrit ». */
  @Get()
  @Header('Cache-Control', 'private, no-store')
  @Header('Vary', 'Cookie')
  getMine(@Req() req: AuthedReq) {
    return this.premiumWaitlistService.getMine(req.studentUser!.id);
  }

  /** Inscrit (ou réinscrit) le profil appelant. */
  @Post()
  @Header('Cache-Control', 'private, no-store')
  @Header('Vary', 'Cookie')
  join(@Req() req: AuthedReq, @Body() body: JoinPremiumWaitlistDto) {
    this.assertStudent(req);
    return this.premiumWaitlistService.join(req.studentUser!.id, body);
  }

  /**
   * Retire le profil appelant de la liste.
   *
   * Aucun paramètre d'identité : l'id vient du jeton vérifié, comme les deux
   * routes au-dessus. Un `userId` accepté dans le corps ou l'URL laisserait un
   * étudiant en désinscrire un autre.
   */
  @Delete()
  @Header('Cache-Control', 'private, no-store')
  @Header('Vary', 'Cookie')
  leave(@Req() req: AuthedReq) {
    // Le retrait est aussi une écriture. Un parent n'a rien à retirer puisqu'il
    // n'a rien pu écrire, mais laisser la porte ouverte inviterait à croire que
    // la règle ne vaut que pour la création.
    this.assertStudent(req);
    return this.premiumWaitlistService.leave(req.studentUser!.id);
  }
}
