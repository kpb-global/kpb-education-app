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
import { AdminUsersService } from './admin-users.service';

@Controller('admin/users')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin)
export class AdminUsersController {
  constructor(private readonly adminUsersService: AdminUsersService) {}

  @Get()
  listUsers() {
    return this.adminUsersService.listUsers();
  }

  @Post()
  createUser(@Body() input: Record<string, unknown>) {
    return this.adminUsersService.createUser(input);
  }

  @Patch(':id')
  updateUser(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.adminUsersService.updateUser(id, input);
  }
}
