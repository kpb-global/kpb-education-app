import { Body, Controller, Get, Post, Req, Res, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';

import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import {
  ADMIN_REFRESH_COOKIE,
  clearAdminAuthCookies,
  readCookie,
  setAdminAuthCookies,
} from './admin-cookies';
import { AuthService } from './auth.service';
import { AdminLoginDto } from './dto/admin-login.dto';

@Controller('auth/admin')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @Throttle({ auth: { limit: 10, ttl: 60000 } })
  async login(
    @Body() input: AdminLoginDto,
    @Res({ passthrough: true }) res: Response,
  ) {
    const { token, refreshToken, user } = await this.authService.login(
      input.email,
      input.password,
    );
    // Tokens go into httpOnly cookies; the JSON body carries only the (non-
    // sensitive) user so the JWTs are never exposed to client-side JavaScript.
    setAdminAuthCookies(res, { token, refreshToken });
    return { user };
  }

  @Post('refresh')
  async refresh(
    @Req() req: Request,
    @Body() input: { refreshToken?: string },
    @Res({ passthrough: true }) res: Response,
  ) {
    const refreshToken =
      readCookie(req.headers.cookie, ADMIN_REFRESH_COOKIE) ??
      input?.refreshToken ??
      '';
    const { token, refreshToken: rotated, user } =
      await this.authService.refresh(refreshToken);
    setAdminAuthCookies(res, { token, refreshToken: rotated });
    return { user };
  }

  @Post('logout')
  logout(@Res({ passthrough: true }) res: Response) {
    clearAdminAuthCookies(res);
    return { ok: true };
  }

  @Get('session')
  @UseGuards(AdminAuthGuard)
  session(@Req() request: Request & { adminUser: unknown }) {
    return { user: request.adminUser };
  }
}
