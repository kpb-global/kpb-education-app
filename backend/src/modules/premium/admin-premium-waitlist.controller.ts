import { Controller, Get, Header, Query, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminPremiumWaitlistService } from './admin-premium-waitlist.service';

/** Bornes de pagination : un `take` non borné est une invitation au timeout. */
const DEFAULT_TAKE = 50;
const MAX_TAKE = 200;

function boundedInt(raw: unknown, fallback: number, min: number, max: number) {
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(parsed)));
}

/**
 * Back-office de la liste d'attente Premium.
 *
 * Mêmes rôles que la liste « Études en France », et pour la même raison : ce
 * sont des noms, des e-mails et des numéros de téléphone, dont ceux de mineurs.
 * Volontairement PAS ouvert à `Moderator` ni `ContentManager` — la modération de
 * contenu n'a rien à faire d'un fichier de prospects.
 */
@Controller('admin/premium/waitlist')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Admin,
  InternalRole.SuperAdmin,
  InternalRole.Commercial,
  InternalRole.Counselor,
)
export class AdminPremiumWaitlistController {
  constructor(
    private readonly adminPremiumWaitlistService: AdminPremiumWaitlistService,
  ) {}

  /**
   * `Cache-Control: private, no-store` et `Vary: Cookie` sur les deux routes.
   *
   * Elles portent des données personnelles d'étudiants. Sans directive, la
   * fraîcheur est heuristique : sur un poste de back-office partagé, le JSON
   * reste dans le cache disque du navigateur après déconnexion, et un cache
   * PARTAGÉ placé devant l'API pourrait resservir la réponse à une requête sans
   * cookie. C'est le patron de toutes les routes de données personnelles du
   * dépôt ; rien ne le pose globalement.
   */
  @Get('summary')
  @Header('Cache-Control', 'private, no-store')
  @Header('Vary', 'Cookie')
  getSummary() {
    return this.adminPremiumWaitlistService.getSummary();
  }

  @Get()
  @Header('Cache-Control', 'private, no-store')
  @Header('Vary', 'Cookie')
  list(@Query('take') take?: string, @Query('skip') skip?: string) {
    return this.adminPremiumWaitlistService.list({
      take: boundedInt(take, DEFAULT_TAKE, 1, MAX_TAKE),
      skip: boundedInt(skip, 0, 0, Number.MAX_SAFE_INTEGER),
    });
  }
}
