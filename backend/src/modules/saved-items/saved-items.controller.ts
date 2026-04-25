import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';

import { CreateSavedItemDto } from './dto/create-saved-item.dto';
import { SavedItemsService } from './saved-items.service';

@Controller('saved-items')
export class SavedItemsController {
  constructor(private readonly savedItemsService: SavedItemsService) {}

  @Get()
  findAll() {
    return this.savedItemsService.findAll();
  }

  @Post()
  create(@Body() input: CreateSavedItemDto) {
    return this.savedItemsService.create(input);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.savedItemsService.remove(id);
  }
}
