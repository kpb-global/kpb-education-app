import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { PartnersService } from './partners.service';

@Controller('partners')
export class PartnersController {
  constructor(private readonly partnersService: PartnersService) {}

  @Get()
  list(
    @Query('category') category?: string,
    @Query('country') country?: string,
  ) {
    return this.partnersService.listPublic({ category, country });
  }

  @Get('featured')
  featured(@Query('limit') limit?: string) {
    return this.partnersService.listFeatured(limit ? Number(limit) : undefined);
  }

  @Get(':slug')
  get(@Param('slug') slug: string) {
    return this.partnersService.getPublic(slug);
  }
}

@Controller('admin/partners')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Admin,
  InternalRole.SuperAdmin,
  InternalRole.ContentManager,
)
export class AdminPartnersController {
  constructor(private readonly partnersService: PartnersService) {}

  @Get()
  list() {
    return this.partnersService.listAdmin();
  }

  @Post()
  create(@Body() body: Parameters<PartnersService['create']>[0]) {
    return this.partnersService.create(body);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() body: Parameters<PartnersService['update']>[1],
  ) {
    return this.partnersService.update(id, body);
  }
}
