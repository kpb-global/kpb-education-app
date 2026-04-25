import {
  Body,
  Controller,
  Delete,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { IsIn, IsString } from 'class-validator';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { PrismaService } from '../prisma/prisma.service';

class RegisterDeviceTokenDto {
  @IsString()
  token!: string;

  @IsString()
  @IsIn(['android', 'ios'])
  platform!: string;
}

@Controller('device-tokens')
@UseGuards(StudentAuthGuard)
export class DeviceTokensController {
  constructor(private readonly prismaService: PrismaService) {}

  @Post()
  async register(@Body() input: RegisterDeviceTokenDto, @Req() req: any) {
    const userId = req.studentUser.id as string;
    await this.prismaService.execute((prisma) =>
      prisma.deviceToken.upsert({
        where: { token: input.token },
        create: {
          userProfileId: userId,
          token: input.token,
          platform: input.platform,
        },
        update: {
          userProfileId: userId,
          platform: input.platform,
        },
      }),
    );
    return { ok: true };
  }

  @Delete(':token')
  async unregister(@Param('token') token: string) {
    await this.prismaService.execute((prisma) =>
      prisma.deviceToken.delete({ where: { token } }),
    );
    return { ok: true };
  }
}
