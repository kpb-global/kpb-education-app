import { Body, Controller, Delete, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';

import { CreateSavedItemDto } from './dto/create-saved-item.dto';
import { SavedItemsService } from './saved-items.service';

@Controller('saved-items')
@UseGuards(StudentAuthGuard)
export class SavedItemsController {
  constructor(private readonly savedItemsService: SavedItemsService) {}

  @Get()
  findAll(@Req() req: any) {
    return this.savedItemsService.findAll(req.studentUser.id);
  }

  @Post()
  create(@Body() input: CreateSavedItemDto, @Req() req: any) {
    return this.savedItemsService.create(input, req.studentUser.id);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.savedItemsService.remove(id);
  }
}
