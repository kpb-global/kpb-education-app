import {
  Body,
  Controller,
  Delete,
  Get,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
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

  // GDPR data export (portability) — returns one JSON document of all the
  // caller's records.
  @Get('me/export')
  exportMe(@Req() req: any) {
    return this.profilesService.exportMe(req.studentUser?.id);
  }

  // GDPR / store-required account deletion — hard-deletes all of the caller's
  // data and (best-effort) their Supabase auth identity.
  @Delete('me')
  deleteMe(@Req() req: any) {
    return this.profilesService.deleteMe(req.studentUser?.id);
  }
}
