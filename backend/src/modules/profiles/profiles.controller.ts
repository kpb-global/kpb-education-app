import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ProfilesService } from './profiles.service';

@Controller('profiles')
@UseGuards(StudentAuthGuard)
export class ProfilesController {
  constructor(private readonly profilesService: ProfilesService) {}

  @Get('me')
  getMe(@Req() req: any) {
    return this.profilesService.getMe(req.studentUser?.id);
  }

  @Patch('me')
  updateMe(@Body() payload: UpdateProfileDto, @Req() req: any) {
    return this.profilesService.updateMe(payload, req.studentUser?.id);
  }
}
