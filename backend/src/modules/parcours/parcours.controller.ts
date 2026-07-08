import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ParcoursService } from './parcours.service';

// Public endpoint — students fetch the curated "Parcours & Témoignages"
// stories (videos + written interviews). No auth: published free content.
// Admin CRUD is gated to content managers, like the rest of the content
// module.
@Controller()
export class ParcoursController {
  constructor(private readonly parcoursService: ParcoursService) {}

  @Get('content/parcours')
  listPublic() {
    return this.parcoursService.listPublic();
  }

  @Get('admin/parcours')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  adminList() {
    return this.parcoursService.listAdmin();
  }

  @Post('admin/parcours')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  create(@Body() input: Record<string, unknown>) {
    return this.parcoursService.create(input);
  }

  @Patch('admin/parcours/:id')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  update(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.parcoursService.update(id, input);
  }

  @Delete('admin/parcours/:id')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  remove(@Param('id') id: string) {
    return this.parcoursService.remove(id);
  }
}
