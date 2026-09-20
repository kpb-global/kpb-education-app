import { Controller, Get, Query } from '@nestjs/common';

import { EefSearchService } from './eef-search.service';

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

  @Get('search')
  search(
    @Query('q') q?: string,
    @Query('procedureType') procedureType?: string,
    @Query('cycle') cycle?: string,
    @Query('fieldId') fieldId?: string,
    @Query('institutionId') institutionId?: string,
    @Query('campusCity') campusCity?: string,
    @Query('selectivity') selectivity?: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
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
}
