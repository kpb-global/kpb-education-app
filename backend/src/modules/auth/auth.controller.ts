import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { AuthService } from './auth.service';
import { AdminLoginDto } from './dto/admin-login.dto';

@Controller('auth/admin')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @Throttle({ auth: { limit: 10, ttl: 60000 } })
  login(@Body() input: AdminLoginDto) {
    return this.authService.login(input.email, input.password);
  }

  @Post('refresh')
  refresh(@Body() input: { refreshToken: string }) {
    return this.authService.refresh(input.refreshToken);
  }

  @Post('set-password')
  @Throttle({ auth: { limit: 5, ttl: 60000 } })
  setPassword(@Body() input: { email: string; password: string }) {
    return this.authService.setInitialPassword(input.email, input.password);
  }

  @Get('session')
  @UseGuards(AdminAuthGuard)
  session(@Req() request: { adminUser: unknown }) {
    return { user: request.adminUser };
  }
}
