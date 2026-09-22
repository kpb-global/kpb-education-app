import {
  Controller,
  ForbiddenException,
  Get,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { EefShortlistService } from './eef-shortlist.service';

type AuthedReq = Request & {
  studentUser?: { id: string; accountType?: string };
};

/**
 * La shortlist « Études en France ».
 *
 * ## Pourquoi celle-ci est authentifiée alors que la recherche ne l'est pas
 *
 * La recherche est publique par décision produit — « catalogue gratuit,
 * accompagnement payant » — et c'est ce qui donne une raison de créer un
 * compte. La shortlist est l'autre moitié de cette décision : elle répond à
 * « lesquelles pour MOI », donc elle lit la déclaration d'intérêt du profil
 * appelant. Sans identité, la question n'a pas de sens ; il n'existe aucun
 * repli anonyme à servir.
 *
 * ## Pourquoi un contrôleur à part
 *
 * `EtudesEnFranceController` porte le même garde, mais il porte aussi les
 * routes d'ÉCRITURE de la déclaration. Les garder ensemble aurait fait vivre
 * sous un même décorateur une lecture dérivée et une écriture de données
 * personnelles — et c'est en ajoutant une route sous un garde existant qu'on
 * finit par lui poser une exception.
 */
@Controller('etudes-en-france')
@UseGuards(StudentAuthGuard)
export class EefShortlistController {
  constructor(private readonly eefShortlistService: EefShortlistService) {}

  /**
   * La liste du profil appelant.
   *
   * Rend 200 même quand aucune liste n'a pu être construite : le corps porte
   * alors `blocked`, qui nomme ce qui manque. Un 4xx aurait fait afficher un
   * écran de panne là où il faut poser une question — « quel niveau vises-tu ? »
   * n'est pas une erreur du client.
   *
   * Réservée aux comptes ÉTUDIANTS, pour la même raison que la déclaration :
   * la liste est construite à partir de la déclaration du profil appelant, et
   * un parent connecté y lirait une recommandation calculée sur son propre
   * profil, en croyant lire celle de son enfant. Le refus est explicite plutôt
   * que silencieux — servir une liste vide aurait été le pire des deux.
   */
  @Get('shortlist')
  getMyShortlist(@Req() req: AuthedReq, @Query('limit') limit?: string) {
    const user = req.studentUser;
    if (!user?.id) {
      throw new UnauthorizedException('Authentication required.');
    }
    if (user.accountType && user.accountType !== 'student') {
      throw new ForbiddenException(
        'Only student accounts have a shortlist in this space.',
      );
    }
    // `@Query()` ne valide rien à l'exécution : un `?limit=3&limit=9` arrive en
    // tableau. `clampShortlistLimit` ne lit donc qu'une chaîne, et retombe sur
    // la valeur par défaut pour tout le reste — une taille de page illisible
    // n'est pas une raison de refuser la liste.
    return this.eefShortlistService.getShortlist(
      user.id,
      typeof limit === 'string' ? limit : undefined,
    );
  }
}
