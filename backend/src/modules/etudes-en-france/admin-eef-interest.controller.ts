import {
  Controller,
  Delete,
  Get,
  Header,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminEefInterestService } from './admin-eef-interest.service';

/** Bornes de pagination : un `take` non borné est une invitation au timeout. */
const DEFAULT_TAKE = 50;
const MAX_TAKE = 200;

function boundedInt(raw: unknown, fallback: number, min: number, max: number) {
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(parsed)));
}

/**
 * Back-office de la liste d'intérêt « Études en France ».
 *
 * Réservé aux rôles qui ont une raison de rappeler un prospect : direction et
 * commercial. Volontairement PAS ouvert à `Moderator` ni `ContentManager` — ce
 * sont des noms, des e-mails et des numéros de téléphone, et la modération de
 * forum n'a rien à en faire.
 */
@Controller('admin/etudes-en-france/interest')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Admin,
  InternalRole.SuperAdmin,
  InternalRole.Commercial,
  InternalRole.Counselor,
)
export class AdminEefInterestController {
  constructor(
    private readonly adminEefInterestService: AdminEefInterestService,
  ) {}

  @Get('summary')
  getSummary() {
    return this.adminEefInterestService.getSummary();
  }

  @Get()
  list(@Query('take') take?: string, @Query('skip') skip?: string) {
    return this.adminEefInterestService.list({
      take: boundedInt(take, DEFAULT_TAKE, 1, MAX_TAKE),
      skip: boundedInt(skip, 0, 0, Number.MAX_SAFE_INTEGER),
    });
  }

  /**
   * L'export CSV.
   *
   * `Content-Disposition: attachment` n'est pas cosmétique : sans lui, un
   * navigateur affiche le CSV en ligne, et un contenu que des utilisateurs ont
   * écrit rendu inline dans l'origine du back-office est une surface dont on
   * n'a aucun besoin. `text/csv` avec `charset=utf-8` va de pair avec le BOM
   * écrit par le sérialiseur.
   */
  /**
   * ADMIN SEULEMENT — plus restreint que la liste, délibérément.
   *
   * Lire cinquante lignes dans une session de back-office et faire sortir la
   * table entière dans un fichier qui quitte le périmètre ne sont pas le même
   * acte. Le dépôt modélise déjà cette distinction :
   * `AdminCapability.ExportPersonalData` n'est accordée qu'à `Admin` et
   * `SuperAdmin` (`admin/lib/admin-capabilities.ts`), et
   * `admin-capabilities.test.ts` fige cette liste à l'identique.
   *
   * Le `@Roles` de classe couvrait la liste ET l'export : un `counselor`
   * pouvait donc télécharger nom, e-mail, téléphone et WhatsApp de vingt mille
   * étudiants, dont des mineurs, alors que la même capacité lui est refusée
   * partout ailleurs dans le produit. Un `@Roles` de méthode l'emporte sur
   * celui de la classe (`RolesGuard` passe par `getAllAndOverride` avec le
   * handler en tête) — même motif que `commercial.controller.ts`, route
   * `performance`.
   */
  /**
   * Retire une déclaration, à la demande de l'étudiant.
   *
   * Ouvert aux MÊMES rôles que la lecture, et non restreint à l'administration —
   * à l'inverse de l'export. Ce n'est pas une incohérence : l'export fait SORTIR
   * des données du périmètre, ce retrait les fait DISPARAÎTRE. C'est l'acte qui
   * protège l'étudiant, et le réserver à deux comptes signifierait qu'une demande
   * reçue par le conseiller qui suit la personne attend qu'un administrateur soit
   * disponible. Un droit qu'on exerce lentement s'exerce mal.
   */
  @Delete(':id')
  withdraw(@Param('id') id: string) {
    return this.adminEefInterestService.withdraw(id);
  }

  @Get('export.csv')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header(
    'Content-Disposition',
    'attachment; filename="eef-interest.csv"',
  )
  exportCsv() {
    return this.adminEefInterestService.exportCsv();
  }
}
