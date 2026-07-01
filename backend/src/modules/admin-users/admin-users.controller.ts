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
import { CreateAdminUserDto } from './dto/create-admin-user.dto';
import { UpdateAdminUserDto } from './dto/update-admin-user.dto';

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
  createUser(@Body() input: CreateAdminUserDto) {
    return this.adminUsersService.createUser(input);
  }

  @Patch(':id')
  updateUser(@Param('id') id: string, @Body() input: UpdateAdminUserDto) {
    return this.adminUsersService.updateUser(id, input);
  }

  /**
   * Issue a fresh temporary password for an operator and invalidate their
   * existing sessions. The plaintext temp password is returned ONCE so the
   * admin can hand it over; only the bcrypt hash is stored.
   */
  @Post(':id/reset-password')
  resetPassword(@Param('id') id: string) {
    return this.adminUsersService.resetPassword(id);
  }
}
