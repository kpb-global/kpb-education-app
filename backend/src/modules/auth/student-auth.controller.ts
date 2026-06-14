import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { StudentAuthService } from './student-auth.service';
import { StudentRegisterDto } from './dto/student-register.dto';
import { StudentLoginDto } from './dto/student-login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';

@Controller('auth/student')
export class StudentAuthController {
  constructor(private readonly studentAuthService: StudentAuthService) {}

  @Post('register')
  @Throttle({ auth: { limit: 5, ttl: 60000 } })
  register(@Body() input: StudentRegisterDto) {
    return this.studentAuthService.register(input);
  }

  @Post('login')
  @Throttle({ auth: { limit: 10, ttl: 60000 } })
  login(@Body() input: StudentLoginDto) {
    return this.studentAuthService.login(input.email, input.password);
  }

  @Post('refresh')
  @Throttle({ auth: { limit: 20, ttl: 60000 } })
  refresh(@Body() input: RefreshTokenDto) {
    return this.studentAuthService.refresh(input.refreshToken);
  }

  @Post('logout')
  @UseGuards(StudentAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@Req() req: { studentUser: { id: string } }) {
    await this.studentAuthService.logout(req.studentUser.id);
  }
}
