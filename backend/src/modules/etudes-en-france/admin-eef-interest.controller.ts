import {
  Controller,
  Delete,
  Get,
  Header,
  Param,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';

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

  /**
   * `Cache-Control: private, no-store` sur les TROIS routes.
   *
   * Ces réponses portent nom, e-mail, téléphone et WhatsApp d'étudiants, dont
   * des mineurs. Sans directive, la fraîcheur est heuristique : sur un poste de
   * back-office partagé, le JSON et le CSV restent dans le cache disque du
   * navigateur après déconnexion. Et le jour où un CDN passe devant l'API avec
   * la règle très courante « cache les `*.csv` », un cache PARTAGÉ peut stocker
   * la réponse et la resservir à une requête sans cookie.
   *
   * C'est le patron de tout le reste du dépôt pour les routes de données
   * personnelles (`admin-cases.controller.ts`, `cases.controller.ts`, une
   * vingtaine de routes de `admin-competition-readiness.controller.ts`). Ce
   * module ne le suivait pas — rien ne le pose globalement, ni `main.ts` ni
   * `helmet`.
   *
   * `Vary: Cookie` avec : la réponse dépend de la session, et un cache qui
   * l'ignorerait pourrait servir la vue d'un compte à un autre.
   */
  @Get('summary')
  @Header('Cache-Control', 'private, no-store')
  @Header('Vary', 'Cookie')
  getSummary() {
    return this.adminEefInterestService.getSummary();
  }

  @Get()
  @Header('Cache-Control', 'private, no-store')
  @Header('Vary', 'Cookie')
  list(@Query('take') take?: string, @Query('skip') skip?: string) {
    return this.adminEefInterestService.list({
      take: boundedInt(take, DEFAULT_TAKE, 1, MAX_TAKE),
      skip: boundedInt(skip, 0, 0, Number.MAX_SAFE_INTEGER),
    });
  }

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

  /**
   * L'export CSV. **ADMIN SEULEMENT** — plus restreint que la liste, exprès.
   *
   * Lire cinquante lignes à l'écran et faire sortir la table entière dans un
   * fichier qui quitte le périmètre ne sont pas le même acte. Le dépôt modélise
   * déjà cette distinction : `AdminCapability.ExportPersonalData` n'est accordée
   * qu'à `Admin` et `SuperAdmin`, et `admin-capabilities.test.ts` fige la liste.
   * Un `@Roles` de méthode l'emporte sur celui de la classe (`RolesGuard` passe
   * par `getAllAndOverride` avec le handler en tête) — même motif que la route
   * `performance` de `commercial.controller.ts`.
   *
   * ## Pourquoi les en-têtes sont posés ICI et non par `@Header`
   *
   * Parce que Nest applique les `@Header` **après les gardes et avant
   * l'exécution du handler**. Un échec du service arrivait donc dans un
   * `Content-Type: text/csv` avec un `Content-Disposition: attachment` déjà
   * posés, et `express` ne réécrit pas un Content-Type existant : le filtre
   * d'exception global renvoyait son JSON d'erreur **dans un fichier nommé
   * `eef-interest.csv`**.
   *
   * Mesuré : `503` + `{"statusCode":503,...}` livré en pièce jointe. Un admin
   * qui ouvre l'URL directement — depuis un marque-page « export prospects » —
   * pendant une coupure Postgres enregistrait ce fichier, l'ouvrait dans Excel,
   * y voyait une cellule, et concluait que personne ne s'était déclaré.
   *
   * Les poser une fois les données EN MAIN supprime ce chemin : sur échec, la
   * réponse est un JSON d'erreur annoncé comme tel.
   *
   * `Content-Disposition: attachment` n'est pas cosmétique non plus : sans lui,
   * un navigateur rend le CSV en ligne, et du contenu écrit par des
   * utilisateurs rendu inline dans l'origine du back-office est une surface dont
   * on n'a aucun besoin.
   */
  @Get('export.csv')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  async exportCsv(@Res({ passthrough: true }) res: Response) {
    const csv = await this.adminEefInterestService.exportCsv();

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader(
      'Content-Disposition',
      'attachment; filename="eef-interest.csv"',
    );
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Vary', 'Cookie');

    return csv;
  }
}
