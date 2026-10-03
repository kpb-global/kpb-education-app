import { Controller, Get, Query } from '@nestjs/common';

import { EefSearchService } from './eef-search.service';
import type { QueryValue } from './eef-search.query';

/**
 * Recherche du catalogue « Études en France ».
 *
 * PUBLIQUE, et ce n'est pas un oubli : la décision produit n° 2 du plan est
 * « catalogue gratuit, accompagnement payant ». Un étudiant doit pouvoir
 * chercher sa formation avant de créer un compte — c'est ce qui lui donne une
 * raison d'en créer un.
 *
 * Elle vit donc à côté de `EtudesEnFranceController`, et non dedans : ce
 * dernier porte `@UseGuards(StudentAuthGuard)` au niveau de la classe, parce
 * que la déclaration d'intérêt écrit les coordonnées de l'appelant. Ajouter
 * une route de lecture publique sous ce garde aurait obligé à l'exempter, et
 * une exception dans un garde finit toujours par s'étendre.
 */
@Controller('etudes-en-france')
export class EefSearchController {
  constructor(private readonly eefSearchService: EefSearchService) {}

  /**
   * Les paramètres sont typés `QueryValue` — `string | string[]` — parce que
   * c'est ce qu'Express livre réellement : un paramètre répété
   * (`?cycle=master&cycle=licence1`) arrive en tableau, et `@Query()` ne
   * valide rien à l'exécution. Les annoter `string` ne rendait pas la requête
   * impossible, seulement la panne surprenante : un 500 sur une requête
   * publique licite.
   */
  @Get('search')
  search(
    @Query('q') q?: QueryValue,
    @Query('procedureType') procedureType?: QueryValue,
    @Query('cycle') cycle?: QueryValue,
    @Query('fieldId') fieldId?: QueryValue,
    @Query('institutionId') institutionId?: QueryValue,
    @Query('campusCity') campusCity?: QueryValue,
    @Query('selectivity') selectivity?: QueryValue,
    @Query('cursor') cursor?: QueryValue,
    @Query('limit') limit?: QueryValue,
  ) {
    return this.eefSearchService.search({
      q,
      procedureType,
      cycle,
      fieldId,
      institutionId,
      campusCity,
      selectivity,
      cursor,
      limit,
    });
  }

  /**
   * Toutes les villes de campus, avec leur compteur (voir
   * `EefSearchService.cities`) : de quoi remplir un filtre « Ville » avec
   * recherche, là où la facette de `search` s'arrête à 20.
   *
   * Publique, pour la même raison que la recherche — et c'est pourquoi elle est
   * ICI et non dans un contrôleur voisin gardé.
   *
   * Les six paramètres sont ceux de `search`, sous les mêmes formes. Il n'y a PAS
   * de `campusCity`, de `cursor` ni de `limit` : le premier est exclu de la
   * clause (le compteur d'une ville dit ce que donnerait CE choix, pas ce qui
   * reste après lui), les deux autres n'ont pas de sens sans pagination. Les
   * envoyer n'est pas une erreur, ils ne sont simplement pas lus — un client qui
   * rejoue l'URL de sa recherche telle quelle doit obtenir la liste.
   *
   * La route est LITTÉRALE : aucune route de ce préfixe n'est paramétrée
   * (`:id`), donc rien ne peut répondre à « cities » avant elle.
   * `eef-search.controller.spec.ts` le prouve par HTTP.
   */
  @Get('cities')
  cities(
    @Query('q') q?: QueryValue,
    @Query('procedureType') procedureType?: QueryValue,
    @Query('cycle') cycle?: QueryValue,
    @Query('fieldId') fieldId?: QueryValue,
    @Query('institutionId') institutionId?: QueryValue,
    @Query('selectivity') selectivity?: QueryValue,
  ) {
    return this.eefSearchService.cities({
      q,
      procedureType,
      cycle,
      fieldId,
      institutionId,
      selectivity,
    });
  }
}
