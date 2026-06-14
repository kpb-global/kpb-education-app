import {
  Body,
  Controller,
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
import { CommunityService } from './community.service';
import { UpsertForumTaxonomyDto } from './dto/upsert-forum-taxonomy.dto';

@Controller()
export class CommunityController {
  constructor(private readonly communityService: CommunityService) {}

  @Get('community/forum-categories')
  listForumCategories() {
    return this.communityService.listForumCategories();
  }

  @Get('community/forum-tags')
  listForumTags() {
    return this.communityService.listForumTags();
  }

  @Get('admin/forum-categories')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.Moderator,
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  adminListForumCategories() {
    return this.communityService.listForumCategories();
  }

  @Post('admin/forum-categories')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.Moderator,
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  createForumCategory(@Body() input: UpsertForumTaxonomyDto) {
    return this.communityService.createForumCategory(input);
  }

  @Patch('admin/forum-categories/:id')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.Moderator,
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  updateForumCategory(
    @Param('id') id: string,
    @Body() input: UpsertForumTaxonomyDto,
  ) {
    return this.communityService.updateForumCategory(id, input);
  }

  @Get('admin/forum-tags')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.Moderator,
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  adminListForumTags() {
    return this.communityService.listForumTags();
  }

  @Post('admin/forum-tags')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.Moderator,
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  createForumTag(@Body() input: UpsertForumTaxonomyDto) {
    return this.communityService.createForumTag(input);
  }

  @Patch('admin/forum-tags/:id')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.Moderator,
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  updateForumTag(
    @Param('id') id: string,
    @Body() input: UpsertForumTaxonomyDto,
  ) {
    return this.communityService.updateForumTag(id, input);
  }

  @Get('admin/forum-moderation')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.Moderator,
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  listModerationQueue() {
    return this.communityService.listModerationQueue();
  }
}
