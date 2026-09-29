import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../../common/decorators/roles.decorator';
import { InternalRole } from '../../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import type { AdminSessionUser } from '../../auth/auth.service';
import { EefPublicationDto } from '../dto/eef-publication.dto';
import { EefPublicationService } from './eef-publication.service';

type AdminRequest = { adminUser?: AdminSessionUser };

/**
 * Publication de l'import « Études en France » : l'acte qui rend visibles, à un
 * étudiant sans compte, des établissements et des formations que personne n'avait
 * relus.
 *
 * Réservé à `Admin` et `SuperAdmin` — PAS à `ContentManager`, qui édite le
 * catalogue mais ne signe pas sa publication. Et le relecteur inscrit est celui de
 * la SESSION : sans session, la route refuse plutôt que de fabriquer un
 * « Unknown admin » qui aurait signé la publication de 900 formations.
 */
@Controller('admin/etudes-en-france/publication')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin)
export class EefPublicationController {
  constructor(private readonly service: EefPublicationService) {}

  private verifier(req: AdminRequest): AdminSessionUser {
    if (!req.adminUser?.id) {
      throw new UnauthorizedException('Session administrateur requise.');
    }
    return req.adminUser;
  }

  @Get('institutions')
  overview() {
    return this.service.overview();
  }

  @Post('institutions/:id/publish')
  publish(
    @Req() req: AdminRequest,
    @Param('id') id: string,
    @Body() body: EefPublicationDto,
  ) {
    return this.service.publish(id, {
      apply: body.apply === true,
      programIds: body.programIds,
      expectedPrograms: body.expectedPrograms,
      verifier: this.verifier(req),
    });
  }

  @Post('institutions/:id/unpublish')
  unpublish(
    @Req() req: AdminRequest,
    @Param('id') id: string,
    @Body() body: EefPublicationDto,
  ) {
    return this.service.unpublish(id, {
      apply: body.apply === true,
      programIds: body.programIds,
      expectedPrograms: body.expectedPrograms,
      verifier: this.verifier(req),
    });
  }
}
